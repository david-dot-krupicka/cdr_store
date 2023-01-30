package CdrStoreApp::Model::CdrStore;
use Mojo::Base -base;

use Carp qw(croak);
use Exception::Class::Try::Catch;
use Function::Parameters;
use Moose;
use MooseX::NonMoose;
use CdrStoreApp::Model::CdrStore::CdrRecord;

use feature 'say';

#has mariadb => sub { croak "mariadb is required" };
has mariadb => (is => 'ro', isa => 'Mojo::mysql', required => 1);

method test ($search) {
	$self->mariadb->db->query(<<'	SQL', $search)->hashes;
		SELECT * FROM customers
		WHERE id=?
	SQL
}

method insert_msisdn_into_table ($msisdn, $table) {
	my $id = $self->mariadb->db->query(
		"INSERT IGNORE INTO $table (MSISDN) VALUES (?)", $msisdn
	)->last_insert_id;
	$id = $self->mariadb->db->select(
		$table, undef, {MSISDN => $msisdn})->hash->{id} if $id == 0;
	return $id;
}

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
				$cdr_record->print_record();
			} catch {
				# If any exception occurs, store the record as invalid
				my $action_message = 'inserting into invalid_call_records';

				# TODO: Could not get the correct Moose exception, so I am matching the message
				#if ($_->isa('Moose::Exception::AttributeIsRequired')) {
				if ($_->message =~ /^Attribute \((\w+)\) is required/) {
					say "ERROR: $class: $action_message, Attribute '$1' is required...";
				} elsif ($_->message =~ /^Attribute \((\w+)\).*Validation failed for '(\w+)'/) {
					say "ERROR: $class: $action_message, Validation of '$1' attribute failed, it is not $2...";
				} else {
					$_->rethrow();
				}
				$self->mariadb->db->insert(
					'invalid_call_records',
					{ record => join(',', @$record) }
				);
			};

			#if (delete $record->{is_valid}) {
			#	# Returns customer id
			#	$record->{caller_id} = $self->insert_msisdn_into_table(
			#		delete $record->{caller_id}, 'customers'
			#	);
			#	# Returns recipient id
			#	$record->{recipient_id} = $self->insert_msisdn_into_table(
			#		delete $record->{recipient_id}, 'recipients'
			#	);
			#	$self->mariadb->db->insert('call_records', $record);
			#} else {
			#	$self->mariadb->db->insert('invalid_call_records', $record);
			#}
		}
		$tx->commit;
	};
	croak($@) if $@;
	return 1;
}

method select_all_records () {
	my @columns = (
		"c.msisdn AS called_id",
		"r.msisdn AS recipient",
		"DATE_FORMAT(call_date, '%d/%m/%Y') AS call_date",
		"end_time",
		"duration",
		"cost",
		"reference",
		"currency",
		"type",
	);
	my $stmt = <<"	SQL";
SELECT %s FROM call_records crd
JOIN customers c on crd.caller_id = c.id
JOIN recipients r on crd.recipient_id = r.id
	SQL
	return $self->mariadb->db->query(sprintf($stmt, join(',', @columns)))->hashes;
}

# Mainly used in testing
method select_all_from_table ($table) {
	return $self->mariadb->db->query("SELECT * FROM $table")->hashes;
}

method delete_all_from_table ($table) {
	$self->mariadb->db->delete($table);
	return 1;
}

fun _delete_empty_fields ($record) {
	map { delete $record->{$_} if $record->{$_} eq '' } keys %$record;
}

1;
