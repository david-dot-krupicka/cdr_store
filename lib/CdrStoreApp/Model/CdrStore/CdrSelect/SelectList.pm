package CdrStoreApp::Model::CdrStore::CdrSelect::SelectList;
use Moose;

extends 'CdrStoreApp::Model::CdrStore::CdrSelect::SelectCount';

use CdrStoreApp::Model::CdrStore::ValidDateRange;
use Exception::Class::Try::Catch;
use Function::Parameters;

has caller_id => (is => 'ro', isa => 'Int', required => 1);
has columns => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_columns');
has select_clause => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_select_clause');
has top_calls => (is => 'ro', isa => 'Maybe[Int]', default => undef);

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

override '_build_where_clause' => sub {
	my ($self) = @_;
	return sprintf('%s %s %s',
		super(),
		'AND c.msisdn = ?',
		$self->top_calls ? 'ORDER BY cost DESC LIMIT ?' : ''
	)
};

override '_build_binds' => sub {
	my ($self) = @_;
	my @binds = @{ super() };
	push @binds, $self->caller_id;
	push @binds, $self->top_calls ? $self->top_calls : ();
	return \@binds
};

override 'select' => sub {
	my ($self) = @_;
	my $stmt = sprintf('%s %s', $self->select_clause, $self->where_clause);
	my ($result, $err);
	try {
		$result = $self->db->query( $stmt, @{$self->binds} )->hashes;
	} catch {
		$err = $_->message;
		if (defined $err->{ierr}) {
			die $err;
		} else {
			die { ierr => 'query_failed', message => $err->message };
		};
	};
	return $result;
};

__PACKAGE__->meta()->make_immutable();
1;
