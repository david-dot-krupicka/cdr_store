package CdrStoreApp::Command::upload;
use Moose;
use MooseX::NonMoose;
use feature 'say';

extends 'Mojolicious::Command';

use Carp qw(croak);
use Function::Parameters;
use Text::CSV_XS;

has description => (is => 'ro', isa => 'Str', default => 'Upload CDR records file');
has usage => (is => 'rw', isa => 'Str', lazy => 1, builder => '_build_usage');
has batch_size => (is => 'rw', isa => 'Int', lazy => 1, builder => '_build_batch_size');

method _build_usage () {
	return <<"	EOF";
$0 upload filename
	filename	CSV file of CDR's
	EOF
}

method _build_batch_size () {
	my $batch_size = $self->app->config->batch_size;
	return defined $batch_size ? $batch_size : 500;
}

method run ($filename) {
	my $csv = Text::CSV_XS->new({ binary => 1, auto_diag => 1 });

	open my $fh, '<', $filename or croak "Cannot open file '$filename': $!";

	$csv->column_names( $csv->getline($fh) );

	while (my $row = $csv->getline_hr($fh)) {
		# TODO: Contruct a batch and insert it in transaction
	}

	return 1;
}

1;