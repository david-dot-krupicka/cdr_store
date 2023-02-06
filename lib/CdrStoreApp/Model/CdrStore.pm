package CdrStoreApp::Model::CdrStore;
use Mojo::Base -base;

use Carp qw(croak carp);
use Exception::Class::Try::Catch;
use Function::Parameters;
use Moose;
use MooseX::NonMoose;

use CdrStoreApp::Model::CdrStore::Cdr;
use CdrStoreApp::Model::CdrStore::CdrSelect::SelectCdr;
use CdrStoreApp::Model::CdrStore::CdrSelect::SelectCount;
use CdrStoreApp::Model::CdrStore::CdrSelect::SelectList;

has mariadb => (is => 'ro', isa => 'Mojo::mysql', required => 1);


method insert_cdr_records ($columns, $records) {
	my $db = $self->mariadb->db;
	eval {
		my $tx = $db->begin;
		foreach my $record (@$records) {
			my %cdr_hash;
			@cdr_hash{@$columns} = @$record;
			# Delete empty fields to ensure we won't insert empty strings
			_delete_empty_fields(\%cdr_hash);

			my $cdr;
			eval {
				$cdr = CdrStoreApp::Model::CdrStore::Cdr->new(
					db => $db,
					%cdr_hash
				);
			};
			if ($@) {
				if ($@ =~ qr/is required|does not pass the type constraint/) {
					my $last_insert_id = $self->insert_invalid_record($record);
					# TODO: Not a proper way to log
					warn "Inserted invalid record ID $last_insert_id";
				}
			} else {
				$cdr->insert_record;
			}
		};
		$tx->commit;
	};

	die $@ if $@;
	return 0
}

method insert_invalid_record ($record) {
	my $result;
	eval {
		$result = $self->mariadb->db->insert(
			'invalid_call_records',
			{ record => join(',', @$record) }
		);
	};
	die $@ if $@;
	return $result->last_insert_id;
}

method select_cdr_by_reference ($reference) {
	my $selector = CdrStoreApp::Model::CdrStore::CdrSelect::SelectCdr->new(
		db        => $self->mariadb->db,
		reference => $reference
	);
	my $data;
	eval {
		$data = $selector->select();
		if (! defined $data->{reference}) {
			$data = $selector->select_invalid();
			if (defined $data->{record}) {
				$data->{error} = 'invalid_record';
				return $data;
			}
	 	} else {
			return { cdr => $data };
		}
	};
	die $@ if $@;

	return { status => 200, cdr => $data } if defined $data->{reference};
	return { status => 422, error => 'invalid_record', %$data }
		if defined $data->{record};
	return { status => 404, error => 'not_found' };
}

method get_cdr_count (
	$start,
	$end,
	$call_type = undef
) {
	my $data;
	eval {
		$data = CdrStoreApp::Model::CdrStore::CdrSelect::SelectCount->new(
			call_type  => $call_type,
			db         => $self->mariadb->db,
			end_date   => $end,
			start_date => $start,
		)->select();
	};
	die $@ if $@;

	return { status => 404, error => 'not_found' }
		unless defined $data->{cdr_count} && $data->{cdr_count} > 0;
	return { status => 200, %$data };
}

method get_cdr_list (
	$start,
	$end,
	$caller_id,
	$call_type = undef,
	$top_calls = undef
) {
	my $data;
	eval {
		$data = CdrStoreApp::Model::CdrStore::CdrSelect::SelectList->new(
			caller_id  => $caller_id,
			call_type  => $call_type,
			db         => $self->mariadb->db,
			end_date   => $end,
			start_date => $start,
			top_calls  => $top_calls
		)->select();
	};
	die $@ if $@;

	return { status => 404, caller_id => $caller_id, error => 'not_found' }
		unless scalar @$data > 0;
	return { status => 200, caller_id => $caller_id, records => $data }
}

fun _delete_empty_fields ($record) {
	map { delete $record->{$_} if $record->{$_} eq '' } keys %$record;
}

1;
