package CdrStoreApp::Model::CdrStore::CdrSelect::SelectList;
use Moose;

with 'CdrStoreApp::Model::CdrStore::Role::SelectAllRole',
	 'CdrStoreApp::Model::CdrStore::Role::DateRole';

use CdrStoreApp::Model::CdrStore::ValidDateRange;
use Function::Parameters;

has binds => (is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_binds');
has caller_id => (is => 'ro', isa => 'Int');
has call_type => (is => 'ro', isa => 'Maybe[Int]', default => undef);
has columns => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_columns');
has select_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_select_clause');
has top_calls => (is => 'ro', isa => 'Maybe[Int]', default => undef);
has where_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_where_clause');

method _build_where_clause () {
	return sprintf('%s %s %s %s',
		'WHERE call_datetime BETWEEN ? AND ?',
		$self->call_type ? 'AND type = ?' : '',
		'AND c.msisdn = ?',
		$self->top_calls ? 'ORDER BY cost DESC LIMIT ?' : ''
	)
};

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
	push @binds, $self->caller_id;
	push @binds, $self->top_calls ? $self->top_calls : ();

	return \@binds
};

method select () {
	my $stmt = sprintf('%s %s', $self->select_clause, $self->where_clause);
	my $result;

	eval {
		$result = $self->db->query($stmt, @{$self->binds})->hashes;
	};
	die $@ if $@;

	return $result;
};

__PACKAGE__->meta()->make_immutable();
1;
