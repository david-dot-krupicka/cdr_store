package CdrStoreApp::Model::CdrStore::Role::SelectAllRole;
use Moose::Role;
use Function::Parameters;

requires 'select';

has columns => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_columns');
has db => (is => 'ro', isa => 'Mojo::mysql::Database', required => 1);
has select_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_select_clause');


method _build_columns () {
	return join(',',
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
}

method _build_select_clause () {
	my $sql = <<"	SQL";
SELECT %s FROM call_records cdr
	JOIN customers c on cdr.caller_id = c.id
	JOIN recipients r on cdr.recipient = r.id
	SQL
	return sprintf($sql, $self->columns);
}

1;
