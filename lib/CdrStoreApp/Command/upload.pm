package CdrStoreApp::Command::upload;

use Moose;
use MooseX::NonMoose;
use Function::Parameters;
use Text::CSV_XS;

use feature 'say';

extends 'Mojolicious::Command';

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

	open my $fh, '<', $filename or die "Cannot open file '$filename': $!";

	my @columns = $csv->column_names( $csv->getline($fh) );

	my @records;
	my $user_message_template = 'Trying to insert %d records to database...';

	while (my $row = $csv->getline($fh)) {
		push @records, $row;

		if (scalar @records % $self->batch_size == 0) {
			say sprintf($user_message_template, scalar @records);
			eval {
				$self->app->cdrstore->insert_cdr_records(\@columns, \@records);
			};
			die "ERROR: ", $@ if $@;
			@records = ();
		}
	}

	# Insert the rest
	if (scalar @records) {
		say sprintf($user_message_template, scalar @records);
		eval {
			$self->app->cdrstore->insert_cdr_records(\@columns, \@records);
		};
	}

	die "ERROR: ", $@ if $@;
	return 0
}

__PACKAGE__->meta()->make_immutable();
1;
