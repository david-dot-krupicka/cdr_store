package CdrStoreApp::Model::CdrStore;
use Mojo::Base -base;

use Carp qw(croak);
use Exception::Class::Try::Catch;
use Function::Parameters;
use Moose;
use MooseX::NonMoose;
use CdrStoreApp::Model::CdrStore::CdrRecord;
use Date::Simple;

use feature 'say';

#has mariadb => sub { croak "mariadb is required" };
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
	my $cdr = $self->select_all_records("reference = '$reference'")->first;

	return $cdr if $cdr;

	$cdr = $self->select_from_invalid_records_like_reference($reference)->first;

	return { ierr => 'invalid_record', %{$cdr} } if $cdr;

	return { ierr => 'not_found' }
}

method count_cdr ($start_date, $end_date, $call_type=undef) {
	use Data::Dumper;
	say Dumper $start_date;
	say Dumper $end_date;
	say Dumper $call_type;

	return { ierr => 'kokot' }
}

method select_all_records ($condition=undef) {
	my @columns = (
		"c.msisdn AS caller_id",
		"r.msisdn AS recipient",
		"DATE_FORMAT(call_date, '%d/%m/%Y') AS call_date",
		"end_time",
		"duration",
		"cost",
		"reference",
		"currency",
		"type",
	);

	my $where_clause = '';
	$where_clause = "WHERE $condition " if defined $condition;

	my $stmt = <<"	SQL";
SELECT %s FROM call_records cdr
JOIN customers c on cdr.caller_id = c.id
JOIN recipients r on cdr.recipient = r.id
${where_clause}
	SQL
	return $self->mariadb->db->query(sprintf($stmt, join(',', @columns)))->hashes;
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
