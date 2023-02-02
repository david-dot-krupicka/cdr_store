package CdrStoreApp::Controller::UploadFile;
use Mojo::Base 'Mojolicious::Controller';
use Exception::Class::Try::Catch;

sub upload_form {
	my ($c) = @_;
	$c->openapi->valid_input or return;

	$c->stash( error   => $c->flash('error') );
	$c->stash( message => $c->flash('message') );

	# Skip openapi spec (improve later)
	$c->render(
		template => 'upload_form'
	);
}

sub browser_redirect {
	my ($c, $msg) = @_;
	if ($c->req->headers->user_agent =~ /^Mozilla/) {
		$c->flash(%$msg);
		$c->redirect_to('/api/upload');
	}
}
sub upload {
	my ($c) = @_;
	$c->openapi->valid_input or return;

	my $do_redirect = $c->req->headers->user_agent =~ /^Mozilla/;

	if ( ! $c->param('upload_file') ) {
		my %msg = ( error => 'File is required.' );
		$c->browser_redirect(\%msg) ||
			return $c->render(openapi => {
				%msg
			});
	}

	my $current_size_limit = $c->app->max_request_size;
	if ($c->req->is_limit_exceeded) {
		my %msg = ( error => "File size exceeded the limit ($current_size_limit bytes)." );
		$c->browser_redirect(\%msg) ||
			return $c->render(openapi => {
				%msg
			});
	}

	my $file = $c->param('upload_file');
	my ($filename, $size) = ($file->filename, $file->size);
	my $move_to = $c->app->home . "/uploads/$filename";

	$c->app->log->debug("Uploading file $filename, size=$size");
	# Rather move to not accidentally delete file in homedir
	$file->move_to($move_to);

	# I will abuse the upload command here for good
	# (as a result of my affliction with the upload :-) )
	# I realize this is probably not common way, I would e.g. like to see
	# some progress in the browser, but still ... it works

	# better naming, it actually performs inserts to the db
	my $result = $c->app->commands->run('upload', $move_to);

	# first unlink the file
	unlink $move_to or do {
		my %msg = (error => "Could not unlike file: $!");
		$c->browser_redirect(\%msg) ||
			return $c->render(openapi => { %msg });
	};

	if (defined $result->{ierr}) {
		$c->browser_redirect($result) ||
			return $c->render(openapi => { %$result });
	}

	$c->browser_redirect($result) ||
		$c->render(openapi => { %$result});
}

sub _do_redirect {
	my ($c) = @_;
	# Match to detect a browser and redirect, return json in all other cases
	return $c->req->headers->user_agent =~ /^Mozilla/;
}

1;