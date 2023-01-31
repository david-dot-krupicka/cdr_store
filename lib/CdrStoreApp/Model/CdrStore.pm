package CdrStoreApp::Model::CdrStore;
use Mojo::Base -base;

use Carp qw(croak);
use Exception::Class::Try::Catch;
use Function::Parameters;
use Moose;
use MooseX::NonMoose;
use CdrStoreApp::Model::CdrStore::CdrRecord;
use CdrStoreApp::Model::CdrStore::LookupHandler;

use feature 'say';

has mariadb => (is => 'ro', isa => 'Mojo::mysql', required => 1);

method insert_cdr_records ($columns, $records) {
	my $class = 'CdrStoreApp::Model::CdrStore::CdrRecord';
	eval {
		my $db = $self->mariadb->db;
		my $tx = $db->begin;
		foreach my $record (@$records) {
			my %cdr_record_hash;
			@cdr_record_hash{@$columns} = @$record;
			# Delete empty fields to ensure we won't insert empty strings
			_delete_empty_fields(\%cdr_record_hash);

			try {
				my $cdr_record = $class->new(
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
					say "ERROR: $class: $action_message, Attribute '$1' is required...";
					# Attribute (duration) does not pass the type constraint because: Validation failed for 'Int' with value IamString
				} elsif ($_->message =~ /Attribute \((\w+)\).*Validation failed for '([^']+)' with value (\S+)/) {
					say "ERROR: $class: $action_message, Validation of '$1' attribute failed, it is not $2, but $3...";
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
	my $cdr = $self->select_all_records("WHERE reference = '$reference'")->first;
	return $cdr if $cdr;

	# Select from invalid records
	$cdr = $self->select_from_invalid_records_like_reference($reference)->first;
	return { ierr => 'invalid_record', %{$cdr} } if $cdr;

	# Else return not found
	return { ierr => 'not_found' }
}

method count_cdr ($start, $end, $call_type=undef) {
	my ($lookup_handler, $err);
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

	my ($stmt, @binds) = $lookup_handler->construct_count_cdr_stmt();

	return $self->mariadb->db->query($stmt, @binds)->hashes->first;
}

method select_all_records ($where_clause='') {
	my @columns = (
		"c.msisdn AS caller_id",
		"r.msisdn AS recipient",
		"DATE_FORMAT(call_datetime, '%d/%m/%Y') AS call_date",
		"DATE_FORMAT(call_datetime, '%H:%i:%S') AS end_time",
		"duration",
		"cost",
		"reference",
		"currency",
		"type",
	);

	my $stmt = <<"	SQL";
SELECT %s FROM call_records cdr
JOIN customers c on cdr.caller_id = c.id
JOIN recipients r on cdr.recipient = r.id
${where_clause}
	SQL
	return $self->mariadb->db->query(sprintf($stmt, join(',', @columns)))->hashes;
}

method select_count_and_duration ($where_clause) {
	my $stmt = <<"	SQL";
SELECT COUNT(*) AS count, SUM(duration)
FROM call_records
${where_clause}
	SQL
	return $self->mariadb->db->query($stmt)->hashes->first;
}

method select_from_invalid_records_like_reference ($reference) {
	return $self->mariadb->db->query(
		"SELECT * FROM invalid_call_records WHERE record LIKE '%$reference%'"
	)->hashes;
}

fun _delete_empty_fields ($record) {
	map { delete $record->{$_} if $record->{$_} eq '' } keys %$record;
}

1;
