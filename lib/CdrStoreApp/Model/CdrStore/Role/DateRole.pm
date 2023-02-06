package CdrStoreApp::Model::CdrStore::Role::DateRole;
use Moose::Role;
use Function::Parameters;
use Mojo::Exception qw(check);

use feature 'say';

has date_range => (
	is      => 'ro',
	isa     => 'CdrStoreApp::Model::CdrStore::ValidDateRange',
	lazy    => 1,
	builder => '_build_date_range'
);
has end_date => (is => 'ro', isa => 'Str', required => 1);
has start_date => (is => 'ro', isa => 'Str', required => 1);

method _build_date_range () {
	my $range;
	eval {
		$range = CdrStoreApp::Model::CdrStore::ValidDateRange->new(
			maybe_start_date => $self->start_date,
			maybe_end_date   => $self->end_date,
		);
	};
	my $error;
	check $@ => [
		qr/Error parsing time/              => sub { $error = $_ },
		qr/failed_to_parse_date/            => sub { $error = $_ },
		qr/start_date_higher_then_end_date/ => sub { $error = $_ },
		qr/time_range_exceeds_one_month/    => sub { $error = $_ },
	];
	die $error if $error;
	die $@ if $@;
	return $range;
}

1;
