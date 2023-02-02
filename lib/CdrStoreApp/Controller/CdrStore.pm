package CdrStoreApp::Controller::CdrStore;
use Mojo::Base 'Mojolicious::Controller';

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

sub get_cdr_count_or_list {
	my ($c) = @_;
	$c->openapi->valid_input or return;

	my $action = $c->param('caller_id') ? 'get_cdr_list' : 'get_cdr_count';
	my $data = $c->cdrstore->get_cdr_count_or_list(
		$c->param('start_date'),
		$c->param('end_date'),
		$c->param('call_type'),
		$c->param('caller_id'),
		$c->param('top_x_calls'),
	);

	if (ref $data eq 'HASH' &&  $data->{ierr}) {
		return $c->render(openapi => {
			_render_for_all($action, 400),
			%$data
		}, status => 400)
	}

	$c->render(json => {
		_render_for_all($action, 200),
		(ref $data eq 'HASH' ? %$data : (records => $data))
	}, status => 200 );
}

sub _render_for_all {
	my ($action, $status) = @_;
	return my %v = (
		action => $action,
		status => $status,
	);
}

1;