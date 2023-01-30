package CdrStoreApp::Model::CdrStore;
use Mojo::Base -base;

use Carp qw(croak);

has mariadb => sub { croak 'mariadb is required' };

sub test {
	my ($self, $search) = @_;
	$self->mariadb->db->query(<<'	SQL', $search)->hashes;
		SELECT * FROM customers
		WHERE id=?
	SQL
}

1;
