package CdrStoreApp::Model::CdrStore::CdrSelect::SelectCount;
use Moose;
use CdrStoreApp::Model::CdrStore::ValidDateRange;
use Function::Parameters;

use feature 'say';

with 'CdrStoreApp::Model::CdrStore::Role::SelectCountRole',
     'CdrStoreApp::Model::CdrStore::Role::DateRole';

has binds => (is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_binds');
has call_type => (is => 'ro', isa => 'Maybe[Int]', default => undef);
has where_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_where_clause');


method _build_where_clause () {
	return sprintf('%s %s',
		'WHERE call_datetime BETWEEN ? AND ?',
		$self->call_type ? 'AND type = ?' : ''
	)
}

method _build_binds () {
	my @binds;
	eval {
		@binds = (
			$self->date_range->start_date->strftime('%Y-%m-%d %H:%M:%S'),
			$self->date_range->end_date->strftime('%Y-%m-%d %H:%M:%S'),
		);
	};
	die $@ if $@;
	$self->call_type ? push @binds, $self->call_type : ();
	return \@binds;
}

method select () {
	my $statement = sprintf('%s %s', $self->select_clause, $self->where_clause);
	my $result;
	eval {
		$result = $self->db->query($statement, @{$self->binds})->hash;
	};
	die $@ if $@;
	return $result;
}

__PACKAGE__->meta()->make_immutable();
1;
