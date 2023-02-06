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
	my %msg;

	if ( ! $c->param('upload_file') ) {
		%msg = ( error => 'File is required.' );
		$c->browser_redirect(\%msg) ||
			return $c->render(openapi => { %msg });
	}

	my $current_size_limit = $c->app->max_request_size;
	if ($c->req->is_limit_exceeded) {
		%msg = ( error => "File size exceeded the limit ($current_size_limit bytes)." );
		$c->browser_redirect(\%msg) ||
			return $c->render(openapi => { %msg });
	}

	my $file = $c->param('upload_file');

	$c->app->log->debug(sprintf('Uploading file %s, size=%s...',
		$file->filename, $file->size
	));

	# I will abuse the upload command here for good
	# (as a result of my affliction with the upload :-) )
	# I realize this is probably not common way, I would e.g. like to see
	# some progress in the browser, but still ... it works

	# better naming, it actually performs inserts to the db...
	#
	eval {
		$c->app->commands->run('upload', $file->filename); # in case of error it dies :-/
	};
	if ($@) {
		%msg = ( error => $@ );
		$c->browser_redirect(\%msg) ||
			return $c->render(openapi => { %msg });
	}

	$file->move_to(sprintf('%s/uploads/%s', $c->app->home, $file->filename));

	%msg = ( message => "File upload successful.");
	$c->browser_redirect(\%msg) ||
		$c->render(openapi => { %msg });
}

sub _do_redirect {
	my ($c) = @_;
	# Match to detect a browser and redirect, return json in all other cases
	return $c->req->headers->user_agent =~ /^Mozilla/;
}

1;