package CdrStoreApp::Model::CdrStore;
use Mojo::Base -base;

use Carp qw(croak);
use Function::Parameters;


has mariadb => sub { croak "mariadb is required" };

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

method insert_cdr_records ($records) {
	eval {
		my $tx = $self->mariadb->db->begin;
		foreach my $record (@$records) {
			if (delete $record->{is_valid}) {
				# Returns customer id
				$record->{caller_id} = $self->insert_msisdn_into_table(
					delete $record->{caller_id}, 'customers'
				);
				# Returns recipient id
				$record->{recipient_id} = $self->insert_msisdn_into_table(
					delete $record->{recipient_id}, 'recipients'
				);
				$self->mariadb->db->insert('call_records', $record);
			} else {
				$self->mariadb->db->insert('invalid_call_records', $record);
			}
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

1;
