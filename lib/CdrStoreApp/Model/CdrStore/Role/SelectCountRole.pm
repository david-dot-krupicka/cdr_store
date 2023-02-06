package CdrStoreApp::Model::CdrStore::Role::SelectCountRole;
use Moose::Role;
use Function::Parameters;

requires 'select';

has db => (is => 'ro', isa => 'Mojo::mysql::Database', required => 1);
has select_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_select_clause');

method _build_select_clause () {
	return <<"	SQL";
SELECT COUNT(*) AS cdr_count, SEC_TO_TIME(SUM(duration)) as total_call_duration
FROM call_records
	SQL
}

1;
