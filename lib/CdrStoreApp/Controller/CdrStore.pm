package CdrStoreApp::Controller::CdrStore;
use Mojo::Base 'Mojolicious::Controller', -signatures;


sub get_cdr ($c) {
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
};

sub count_cdr ($c) {
	$c->openapi->valid_input or return;

	my $action = 'count_cdr';
	my $data = $c->cdrstore->count_cdr(
		$c->param('start_date'),
		$c->param('end_date'),
		$c->param('call_type')
	);

	$c->render(json => { status => 200 });
};

sub cdr_by_caller ($c) {
	$c->openapi->valid_input or return;

	my $action = 'cdr_by_caller';
	use Data::Dumper;
	say Dumper $c->param;

	$c->render(json => { status => 200 });
};

sub cdr_by_caller_top ($c) {
	$c->openapi->valid_input or return;

	my $action = 'cdr_by_caller_top';
	use Data::Dumper;
	say Dumper $c->param;

	$c->render(json => { status => 200 });
};

sub _render_for_all ($action, $status) {
	return my %v = (
		action => $action,
		status => $status,
	);
};

1;