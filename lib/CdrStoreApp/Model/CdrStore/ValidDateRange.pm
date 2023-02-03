package CdrStoreApp::Model::CdrStore::ValidDateRange;
use Moose;
use Exception::Class::Try::Catch;
use Function::Parameters;
use Time::Piece;
use Time::Seconds;

has maybe_start_date => (is => 'ro', isa => 'Str', required => 1);
has maybe_end_date => (is => 'ro', isa => 'Str', required => 1);
has start_date => (is => 'ro', isa => 'Time::Piece', lazy => 1, builder => '_build_start_date');
has end_date => (is => 'ro', isa => 'Time::Piece', lazy => 1, builder => '_build_end_date');

method BUILD ($args) {
	# Missing date will be catched by OpenAPI spec
	if ($args->{maybe_start_date} && $args->{maybe_end_date}) {
		die { ierr => 'start_date_higher_then_end_date' }
			if $self->start_date > $self->end_date;

		my $t = Time::Seconds->new($self->end_date - $self->start_date);
		die { ierr => 'time_range_exceeds_one_month' }
			if $t->months > 1;
	}
}

method _build_start_date () {
	return _build_date($self->maybe_start_date);
}

method _build_end_date () {
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
		} else {
			die 'Format of date does not match';
		};
	} catch {
		$err = $_->{message};
		chomp $err;
	};

	if (defined $err) {
		$err->rethrow() unless $err =~ /^Format of date|^Error parsing time/;
		die { ierr => 'failed_to_parse_date', message => $err }
	}

	return $date;
}

__PACKAGE__->meta()->make_immutable();
1;