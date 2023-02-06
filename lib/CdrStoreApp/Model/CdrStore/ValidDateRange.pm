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
	eval {
		if ($args->{maybe_start_date} && $args->{maybe_end_date}) {
			die 'start_date_higher_then_end_date'
				if $self->start_date > $self->end_date;

			my $t = Time::Seconds->new($self->end_date - $self->start_date);
			die 'time_range_exceeds_one_month'
				if $t->months > 1;
		}
	};
	die $@ if $@;
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
	my $date;

	eval {
		if ($maybe_date =~ m|^\d{2}/\d{2}/\d{4}$|) {
			$date = Time::Piece->strptime($maybe_date, '%d/%m/%Y');
		}
		elsif ($maybe_date =~ m|^\d{2}/\d{2}/\d{4}T\d{2}:\d{2}:\d{2}$|) {
			$date = Time::Piece->strptime($maybe_date, '%d/%m/%YT%H:%M:%S');
		}
		else {
			die 'failed_to_parse_date';
		};
	};
	die $@ if $@;

	return $date;
}

__PACKAGE__->meta()->make_immutable();
1;