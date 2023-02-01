package CdrStoreApp::Model::CdrStore;
use Mojo::Base -base;

use Carp qw(croak carp);
use Exception::Class::Try::Catch;
use Function::Parameters;
use Moose;
use MooseX::NonMoose;
use CdrStoreApp::Model::CdrStore::CdrRecord;
use CdrStoreApp::Model::CdrStore::LookupHandler;

use feature 'say';

has mariadb => (is => 'ro', isa => 'Mojo::mysql', required => 1);

# TODO: Although it works, refactor
method insert_cdr_records ($columns, $records) {
	eval {
		my $db = $self->mariadb->db;
		my $tx = $db->begin;
		foreach my $record (@$records) {
			# TODO: How to improve this
			my %cdr_record_hash;
			@cdr_record_hash{@$columns} = @$record;
			# Delete empty fields to ensure we won't insert empty strings
			_delete_empty_fields(\%cdr_record_hash);

			try {
				my $cdr_record = CdrStoreApp::Model::CdrStore::CdrRecord->new(
					db => $db,
					%cdr_record_hash
				);
				$cdr_record->insert_record();
			} catch {
				# If any exception occurs, store the record as invalid
				my $action_message = 'inserting into invalid_call_records';

				# TODO: Could not get the correct Moose exception, so I am matching the message
				#if ($_->isa('Moose::Exception::AttributeIsRequired')) {
				if ($_->message =~ /^Attribute \((\w+)\) is required/) {
					carp "WARN: $action_message, Attribute '$1' is required...";
					# Attribute (duration) does not pass the type constraint because: Validation failed for 'Int' with value IamString
				} elsif ($_->message =~ /Attribute \((\w+)\).*Validation failed for '([^']+)' with value (\S+)/) {
					carp "WARN: $action_message, Validation of '$1' attribute failed, it is not $2, but $3...";
				} elsif ($_->message =~ /Error parsing time/) {
					carp "WARN: $action_message, Date validation failed";
				} else {
					$_->rethrow();
				}
				$self->mariadb->db->insert(
					'invalid_call_records',
					{ record => join(',', @$record) }
				);
			};
		}
		$tx->commit;
	};
	croak($@) if $@;
	return 1;
}

method select_cdr_by_reference ($reference) {
	# Select from valid records
	my $lookup_handler = CdrStoreApp::Model::CdrStore::LookupHandler->new();

	my $cdr;
	$cdr = $self->mariadb->db->query(
		$lookup_handler->compose_cdr_statement($reference)
	)->hashes->first;
	return $cdr if $cdr;

	# Select from invalid records
	$cdr = $self->mariadb->db->query(
		$lookup_handler->compose_invalid_cdr_statement($reference)
	)->hashes->first;
	return { ierr => 'invalid_record', %{$cdr} } if $cdr;

	# Else return not found
	return { ierr => 'not_found' }
}

# TODO: Almost copy paste...
method count_cdr ($start, $end, $call_type=undef) {
	my ($lookup_handler, $err);
	# TODO: try -> catch -> err not DRY, improve
	try {
		$lookup_handler = CdrStoreApp::Model::CdrStore::LookupHandler->new(
			maybe_start_date => $start,
			maybe_end_date   => $end,
			call_type_filter => $call_type,
		);
	} catch {
		$err = $_;
	};
	if (defined $err) {
		$err->rethrow() unless $err->{message}->{ierr};
		return $err->{message};
	}

	return $self->mariadb->db->query(
		$lookup_handler->compose_count_cdr_statement
	)->hashes->first;
}

# TODO: Copy paste...
method cdr_by_caller ($start, $end, $caller_id, $call_type=undef) {
	my ($lookup_handler, $err);
	# TODO: try -> catch -> err not DRY, improve
	try {
		$lookup_handler = CdrStoreApp::Model::CdrStore::LookupHandler->new(
			maybe_start_date => $start,
			maybe_end_date   => $end,
			call_type_filter => $call_type,
		);
	} catch {
		$err = $_;
	};
	if (defined $err) {
		$err->rethrow() unless $err->{message}->{ierr};
		return $err->{message};
	}

	return $self->mariadb->db->query(
		$lookup_handler->compose_cdr_statement_by_caller_id($caller_id)
	)->hashes;
}

# TODO: Copy paste...
method cdr_by_caller_top ($start, $end, $caller_id, $top_x_queries, $call_type=undef) {
	my ($lookup_handler, $err);
	# TODO: try -> catch -> err not DRY, improve
	try {
		$lookup_handler = CdrStoreApp::Model::CdrStore::LookupHandler->new(
			maybe_start_date => $start,
			maybe_end_date   => $end,
			call_type_filter => $call_type,
		);
	} catch {
		$err = $_;
	};
	if (defined $err) {
		$err->rethrow() unless $err->{message}->{ierr};
		return $err->{message};
	}
}

fun _delete_empty_fields ($record) {
	map { delete $record->{$_} if $record->{$_} eq '' } keys %$record;
}

1;
