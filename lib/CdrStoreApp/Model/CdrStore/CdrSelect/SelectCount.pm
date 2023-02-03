package CdrStoreApp::Model::CdrStore::CdrSelect::SelectCount;
use Moose;

use CdrStoreApp::Model::CdrStore::ValidDateRange;
use Exception::Class::Try::Catch;
use Function::Parameters;
use Mojo::mysql::Results;

has call_type => (is => 'ro', isa => 'Maybe[Int]', default => undef);
has date_range => (
	is      => 'ro',
	isa     => 'CdrStoreApp::Model::CdrStore::ValidDateRange',
	lazy    => 1,
	builder => '_build_date_range'
);
has db => (is => 'ro', isa => 'Mojo::mysql::Database', required => 1);
has end_date => (is => 'ro', isa => 'Str', required => 1);
has start_date => (is => 'ro', isa => 'Str', required => 1);
has select_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_select_clause');
has where_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_where_clause');
has binds => (is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_binds');


method _build_date_range () {
	try {
		return CdrStoreApp::Model::CdrStore::ValidDateRange->new(
			maybe_start_date => $self->start_date,
			maybe_end_date   => $self->end_date,
		);
	} catch {
		die $_;
	}
}

method _build_select_clause () {
	return <<"	SQL";
SELECT COUNT(*) AS cdr_count, SEC_TO_TIME(SUM(duration)) as total_call_duration
FROM call_records
	SQL
}

method _build_where_clause () {
	return sprintf('%s %s',
		'WHERE call_datetime BETWEEN ? AND ?',
		$self->call_type ? 'AND type = ?' : ''
	)
}

method _build_binds () {
	my @binds = (
		$self->date_range->start_date->strftime('%Y-%m-%d %H:%M:%S'),
		$self->date_range->end_date->strftime('%Y-%m-%d %H:%M:%S'),
	);
	$self->call_type ? push @binds, $self->call_type : ();
	return \@binds;
}

method select () {
	my $stmt = sprintf('%s %s', $self->select_clause, $self->where_clause);
	my ($result, $err);
	try {
		$result = $self->db->query( $stmt, @{$self->binds} )->hashes->first;
	} catch {
		$err = $_->message;
		if (defined $err->{ierr}) {
			die $err;
		} else {
			die { ierr => 'query_failed', message => $err->message };
		};
	};
	return $result;
}

__PACKAGE__->meta()->make_immutable();
1;
