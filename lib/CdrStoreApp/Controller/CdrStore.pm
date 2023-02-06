package CdrStoreApp::Controller::CdrStore;
use Mojo::Base 'Mojolicious::Controller';


sub get_one_cdr {
	my ($c) = @_;
	$c->openapi->valid_input or return;

	my $action = 'get_cdr';
	my $data;
	eval {
		$data = $c->cdrstore->select_cdr_by_reference(
			$c->param('reference')
		);
	};
	if ($@) {
		$c->render(openapi => {
			_render_for_all($action, 400),
			error => $@
		}, status => 400);
	}

	$c->render(openapi => {
		_render_for_all($action, $data->{status}),
		%$data,
	}, status => $data->{status})
}

sub get_cdr_count {
	my ($c) = @_;
	$c->openapi->valid_input or return;
	my $action = 'get_cdr_count';

	my $data;
	eval {
		$data = $c->cdrstore->get_cdr_count(
			$c->param('start_date'),
			$c->param('end_date'),
			$c->param('call_type'),
		);
	};
	if ($@) {
		return $c->render(openapi => {
			_render_for_all($action, 400),
			error => $@->to_string
		}, status => 400);
	}

	# not_found => 404, else 400
	$c->render(openapi => {
		_render_for_all($action, $data->{status}),
		%$data,
	}, status => $data->{status})
}

sub get_cdr_list {
	my ($c) = @_;
	$c->openapi->valid_input or return;
	my $action = 'get_cdr_list';

	my $data;
	eval {
		$data = $c->cdrstore->get_cdr_list(
			$c->param('start_date'),
			$c->param('end_date'),
			$c->param('caller_id'),
			$c->param('call_type'),
			$c->param('top_x_calls'),
		)
	};
	if ($@) {
		return $c->render(openapi => {
			_render_for_all($action, 400),
			error => $@->to_string
		}, status => 400);
	}

	# not_found => 404, else 400
	$c->render(openapi => {
		_render_for_all($action, $data->{status}),
		%$data,
	}, status => $data->{status})
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

