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
	my $batch_size = $self->app->config->{batch_size};
	return defined $batch_size ? $batch_size : 100;
}

method run ($filename) {
	my $csv = Text::CSV_XS->new({ binary => 1, auto_diag => 1 });

	open my $fh, '<', $filename or croak "Cannot open file '$filename': $!";

	$csv->column_names( $csv->getline($fh) );

	my @records;
	while (my $row = $csv->getline_hr($fh)) {

		# munge date
		$row->{call_date} = $row->{call_date} =~ s|(\d{2})/(\d{2})/(\d{4})|$3/$2/$1|r;
		# munge recipient to recipient_id
		$row->{recipient_id} = delete $row->{recipient};
		$row->{is_valid} = is_row_valid($row);

		push @records, $row;

		if (scalar @records % $self->batch_size == 0) {
			say "Inserting ", scalar @records, " to database...";
			$self->app->cdrstore->insert_cdr_records(\@records);
			@records = ();
		}
	}

	# Insert the rest
	say "Inserting ", scalar @records, " to database...";
	$self->app->cdrstore->insert_cdr_records(\@records) if scalar @records;

	return 1;
}

fun is_row_valid ($row) {
	my $is_valid = 1;
	foreach my $key (keys %$row) {
		if ($row->{$key} eq '') {
			delete $row->{$key};
			$is_valid = 0;
		}
	}
	return $is_valid;
}

__PACKAGE__->meta()->make_immutable();
1;
