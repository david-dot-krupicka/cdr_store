package CdrStoreApp::Model::CdrStore::LookupHandler;
use Moose;
use Exception::Class::Try::Catch;
use Function::Parameters;
use Time::Piece;
use Time::Seconds;

use feature 'say';

has maybe_start_date => (is => 'ro', isa => 'Str', required => 1);
has maybe_end_date => (is => 'ro', isa => 'Str', required => 1);
has start_datetime => (is => 'rw', isa => 'Time::Piece', lazy => 1, builder => '_build_start_datetime');
has end_datetime => (is => 'rw', isa => 'Time::Piece', lazy => 1, builder => '_build_end_datetime');
has call_type_filter => (is => 'ro', isa => 'Maybe[Int]', default => undef);

method _build_start_datetime () {
	return _build_date($self->maybe_start_date);
}

method _build_end_datetime () {
	return _build_date($self->maybe_end_date);
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
		return { ierr => 'failed_to_parse_date' }
	}

	return $date;
}

method BUILD ($args) {
	die { ierr => 'start_date_higher_then_end_date' }
		if $self->start_datetime > $self->end_datetime;

	my $t = Time::Seconds->new($self->end_datetime - $self->start_datetime);
	die { ierr => 'time_range_exceeds_one_month' }
		if $t->months > 1;
}

method construct_count_cdr_stmt () {
	my $type_filter = $self->call_type_filter ? 'AND type = ?' : '';
	my $stmt = <<"	SQL";
SELECT COUNT(*) AS cdr_count, SEC_TO_TIME(SUM(duration)) as total_call_duration
FROM call_records
WHERE call_datetime BETWEEN ? AND ?
${type_filter}
	SQL

	my @binds = (
		$self->start_datetime->strftime('%Y-%m-%d %H:%M:%S'),
		$self->end_datetime->strftime('%Y-%m-%d %H:%M:%S'),
	);
	push @binds, $self->call_type_filter if $self->call_type_filter;

	return $stmt, @binds;
}

1;