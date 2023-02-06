package CdrStoreApp::Model::CdrStore::CdrSelect::SelectCdr;
use Moose;

with 'CdrStoreApp::Model::CdrStore::Role::SelectAllRole';

use CdrStoreApp::Model::CdrStore::ValidDateRange;
use Function::Parameters;

has reference => (is => 'ro', isa => 'Str', required => 1);
has columns => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_columns');
has db => (is => 'ro', isa => 'Mojo::mysql::Database', required => 1);
has where_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_where_clause');


method _build_where_clause () {
	return "WHERE reference = ?";
}

method select () {
	my $statement = sprintf(
		'%s %s', $self->select_clause, $self->where_clause
	);
	my $result;
	eval {
		$result = $self->db->query($statement, $self->reference)->hash;
	};
	die $@ if $@;
	return $result;
}

method select_invalid () {
	my $statement = <<"	SQL";
SELECT id, record FROM invalid_call_records
WHERE record LIKE ?
	SQL

	my $result;
	eval {
		$result = $self->db->query(
			$statement, sprintf('%%%s%%', $self->reference)
		)->hash;
	};
	die $@ if $@;
	return $result;
}

__PACKAGE__->meta()->make_immutable();
1;
