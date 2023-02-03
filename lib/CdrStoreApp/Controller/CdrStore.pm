package CdrStoreApp::Controller::CdrStore;
use Mojo::Base 'Mojolicious::Controller';
use Exception::Class::Try::Catch;

sub get_one_cdr {
	my ($c) = @_;
	$c->openapi->valid_input or return;

	my $action = 'get_cdr';
	my $data = $c->cdrstore->select_cdr_by_reference(
		$c->param('reference')
	);

	if ($data->{ierr}) {
		# 404 - not_found, 422 - invalid_record
		my $status = ($data->{ierr} eq 'not_found' ? 404 : 422);

		return $c->render(openapi => {
			_render_for_all($action, $status),
			%$data,
		}, status => $status)
	}

	$c->render(openapi => {
		_render_for_all($action, 200),
		cdr => $data,
	}, status => 200)
}

sub get_cdr_count {
	my ($c) = @_;
	$c->openapi->valid_input or return;
	my ($status, $data, $err) = (200);

	try {
		$data = $c->cdrstore->get_cdr_count(
			$c->param('start_date'),
			$c->param('end_date'),
			$c->param('call_type'),
		)
	} catch {
		$err = $_->message;
		$status = $err->{ierr} eq 'not_found' ? 404 : 400;
	};
	$c->render(openapi => $err ? $err : $data, status => $status);
}

sub get_cdr_list {
	my ($c) = @_;
	$c->openapi->valid_input or return;
	my ($status, $data, $err) = (200);

	try {
		$data = $c->cdrstore->get_cdr_list(
			$c->param('start_date'),
			$c->param('end_date'),
			$c->param('caller_id'),
			$c->param('call_type'),
			$c->param('top_x_calls'),
		)
	} catch {
		$err = $_->message;
		$status = $err->{ierr} eq 'not_found' ? 404 : 400;
	};

	$c->render(openapi => $err ? $err : $data, status => $status);
}

sub get_cdr_count_or_list {
	my ($c) = @_;
	$c->openapi->valid_input or return;

	# TODO: This is silly
	my $path = $c->req->url->path->to_string;
	my $action = ($path =~ /count_cdr/ ? 'get_cdr_count' : 'get_cdr_list');
	my $data = $c->cdrstore->get_cdr_count_or_list(
		$action,
		$c->param('start_date'),
		$c->param('end_date'),
		$c->param('call_type'),
		$c->param('caller_id'),
		$c->param('top_x_calls'),
	);

	if (ref $data eq 'HASH' && $data->{ierr}) {
		return $c->render(openapi => {
			_render_for_all($action, 400),
			%$data
		}, status => 400)
	}

	my $status = 200;
	if ($action eq 'get_cdr_list' && scalar @$data == 0) {
		$status = 404;
		return $c->render(openapi => {
			_render_for_all($action, $status),
			ierr    => 'not_found',
			records => $data
		}, status => $status);
	}
	$c->render(openapi => {
		_render_for_all($action, $status),
		($action eq 'get_cdr_list'
			? (caller_id => $c->param('caller_id'), records => $data)
			: %$data
		)
	}, status => $status );
}

sub _render_for_all {
	my ($action, $status) = @_;
	return my %v = (
		action => $action,
		status => $status,
	);
}

1;

