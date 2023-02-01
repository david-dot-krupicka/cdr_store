package CdrStoreApp::Model::CdrStore::LookupHandler;
use Moose;
use Exception::Class::Try::Catch;
use Function::Parameters;
use Time::Piece;
use Time::Seconds;

use feature 'say';

has maybe_start_date => (is => 'ro', isa => 'Str');
has maybe_end_date => (is => 'ro', isa => 'Str');

has start_datetime => (is => 'ro', isa => 'Time::Piece', lazy => 1, builder => '_build_start_datetime');
method _build_start_datetime () {
	return _build_date($self->maybe_start_date);
}

has end_datetime => (is => 'ro', isa => 'Time::Piece', lazy => 1, builder => '_build_end_datetime');
method _build_end_datetime () {
	return _build_date($self->maybe_end_date);
}

has call_type_filter => (is => 'ro', isa => 'Maybe[Int]', default => undef);

# Define (all) columns as a string, we don't need to manipulate with them
has columns => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_columns');
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

fun _build_date ($maybe_date) {
	# returns valid Time::Piece object or ierr if it fails
	# Support format %d/%m/%Y or %d/%m/%YT%H:%M:%S
	my ($date, $err);
	try {
		if ($maybe_date =~ m|^\d{2}/\d{2}/\d{4}$|) {
			$date = Time::Piece->strptime($maybe_date, '%d/%m/%Y');
		} elsif ($maybe_date =~ m|^\d{2}/\d{2}/\d{4}T\d{2}:\d{2}:\d{2}$|) {
			$date = Time::Piece->strptime($maybe_date, '%d/%m/%YT%H:%M:%S');
		};
	} catch {
		$err = $_;
	};

	if (defined $err) {
		$err->rethrow() unless $err->{message} =~ /^Error parsing time/;
		# TODO: we should die here
		return { ierr => 'failed_to_parse_date' }
	}

	return $date;
}

method BUILD ($args) {
	if ($args->{maybe_start_date}) {
		die { ierr => 'start_date_higher_then_end_date' }
			if $self->start_datetime > $self->end_datetime;

		my $t = Time::Seconds->new($self->end_datetime - $self->start_datetime);
		die { ierr => 'time_range_exceeds_one_month' }
			if $t->months > 1;
	}
}

method compose_all_columns_select () {
	my $statement = <<"	SQL";
SELECT %s FROM call_records cdr
	JOIN customers c on cdr.caller_id = c.id
	JOIN recipients r on cdr.recipient = r.id
	SQL
	return sprintf($statement, $self->columns);
}

method compose_cdr_statement ($reference) {
	my $statement = $self->compose_all_columns_select .
		' WHERE reference = ?';
	return $statement, $reference;
}

method compose_invalid_cdr_statement ($reference) {
	my $statement = <<"	SQL";
SELECT id, record FROM invalid_call_records
WHERE record LIKE ?
	SQL
	return $statement, "%$reference%";
}

method compose_count_cdr_statement () {
	my $type_filter = $self->call_type_filter ? ' AND type = ?' : '';

	my $statement = <<"	SQL";
SELECT COUNT(*) AS cdr_count, SEC_TO_TIME(SUM(duration)) as total_call_duration
FROM call_records
WHERE call_datetime BETWEEN ? AND ? ${type_filter}
	SQL

	my @binds = (
		$self->start_datetime->strftime('%Y-%m-%d %H:%M:%S'),
		$self->end_datetime->strftime('%Y-%m-%d %H:%M:%S'),
	);
	push @binds, $self->call_type_filter if $self->call_type_filter;

	return $statement, @binds;
}

1;