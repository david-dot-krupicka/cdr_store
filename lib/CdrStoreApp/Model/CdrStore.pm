package CdrStoreApp::Model::CdrStore;
use Mojo::Base -base;

use Carp qw(croak carp);
use Exception::Class::Try::Catch;
use Function::Parameters;
use Moose;
use MooseX::NonMoose;
use CdrStoreApp::Model::CdrStore::CdrRecord;
use CdrStoreApp::Model::CdrStore::LookupHandler;

use CdrStoreApp::Model::CdrStore::CdrSelect::SelectCount;
use CdrStoreApp::Model::CdrStore::CdrSelect::SelectList;

has mariadb => (is => 'ro', isa => 'Mojo::mysql', required => 1);

# TODO: Although it works, should be refactored
method insert_cdr_records ($columns, $records) {
	eval {
		my $db = $self->mariadb->db;
		my $tx = $db->begin;
		foreach my $record (@$records) {
			my %cdr_record_hash;
			@cdr_record_hash{@$columns} = @$record;
			# Delete empty fields to ensure we won't insert empty strings
			_delete_empty_fields(\%cdr_record_hash);

			my ($cdr_record, $err);
			try {
				$cdr_record = CdrStoreApp::Model::CdrStore::CdrRecord->new(
					db => $db,
					%cdr_record_hash
				);
			}
			catch {
				$err = $_->message; # TODO
				use Data::Dumper;
				say Dumper $err;
				# If any exception occurs, store the record as invalid
				my $action_message = 'inserting into invalid_call_records';

				# TODO: Could not get the correct Moose exception, so I am matching the message
				#if ($_->isa('Moose::Exception::AttributeIsRequired')) {
				if ($_->message =~ /^Attribute \((\w+)\) is required/) {
					carp "WARN: $action_message, Attribute '$1' is required...";
					# Attribute (duration) does not pass the type constraint because: Validation failed for 'Int' with value IamString
				}
				elsif ($_->message =~ /Attribute \((\w+)\).*Validation failed for '([^']+)' with value (\S+)/) {
					carp "WARN: $action_message, Validation of '$1' attribute failed, it is not $2, but $3...";
				}
				elsif ($_->message =~ /Error parsing time/) {
					carp "WARN: $action_message, Date validation failed";
				} else {
					$_->rethrow();
				}

				$self->mariadb->db->insert(
					'invalid_call_records',
					{ record => join(',', @$record) }
				);
			};
			$err = undef;
			try {
				# At least some check to prevent inserting already existing entries
				$cdr_record->insert_record;
			} catch {
				$err = $_->{message};
				$err->rethrow() unless $err->{ierr};
			};
			return { error => $err->{ierr} } if $err->{ierr};
		}
		$tx->commit;
	};
	croak($@) if $@;

	return { message => 'insert_successful' }
}

method select_cdr_by_reference ($reference) {
	# Select from valid records
	my $lookup_handler = CdrStoreApp::Model::CdrStore::LookupHandler->new();

	my $cdr;
	$cdr = $self->mariadb->db->query(
		$lookup_handler->compose_cdr_statement($reference)
	)->hashes->first;
	return $cdr if $cdr;

	# If not found, select from invalid records
	$cdr = $self->mariadb->db->query(
		$lookup_handler->compose_invalid_cdr_statement($reference)
	)->hashes->first;
	return { ierr => 'invalid_record', %{$cdr} } if $cdr;

	# Else return not found
	return { ierr => 'not_found' }
}

method get_cdr_count (
	$start,
	$end,
	$call_type = undef
) {
	my $data;
	$data = try {
		CdrStoreApp::Model::CdrStore::CdrSelect::SelectCount->new(
			call_type  => $call_type,
			db         => $self->mariadb->db,
			end_date   => $end,
			start_date => $start,
		)->select;
	} catch {
		die $_->message;
	};
	die { ierr => 'not_found' } unless $data->{cdr_count};
	return $data;
}

method get_cdr_list (
	$start,
	$end,
	$caller_id,
	$call_type = undef,
	$top_calls = undef
) {
	my $data;
	try {
		$data = CdrStoreApp::Model::CdrStore::CdrSelect::SelectList->new(
			caller_id             => $caller_id,
			call_type             => $call_type,
			db                    => $self->mariadb->db,
			end_date              => $end,
			start_date            => $start,
			top_calls             => $top_calls
		)->select;
	} catch {
		die $_->message;
	};
	die { ierr => 'not_found' } unless scalar @{$data};
	return { caller_id => $caller_id, records => $data };
}

fun _delete_empty_fields ($record) {
	map { delete $record->{$_} if $record->{$_} eq '' } keys %$record;
}

1;
