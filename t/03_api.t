use Mojo::Base -strict;

use Test::More;
use Test::Mojo;


# TODO: The test relies on records uploaded in 01_basic.t
# TODO: Deploy and upload new records beforehand
# TODO ...
# TODO or mock them somehow
my $t = Test::Mojo->new(
	'CdrStoreApp',
	{
		mariadb    => 'mariadb://cdr_store_test:cdr_store_test_pass@127.0.0.1:3307/test',
		batch_size => 3,
	}
);

subtest 'Get CDR by reference' => sub {
	$t->get_ok('/api/get_cdr')
		->status_is(400)
		->json_is('/errors/0/message' => 'Missing property.')
		->json_is('/errors/0/path' => '/reference');

	$t->get_ok('/api/get_cdr?reference=pansky')
		->status_is(404)
		->json_is('/action' => 'get_cdr')
		->json_is('/ierr' => 'not_found');

	#,448001000000,16/08/2016,14:21:50,31,0,reference3,GBP,1
	$t->get_ok('/api/get_cdr?reference=reference3')
		->status_is(422)
		->json_is('/action' => 'get_cdr')
		->json_is('/ierr' => 'invalid_record')
		->json_has('/id')
		->json_has('/record');

	#442036000000,44800833833,16/08/2016,14:00:47,244,0,reference2,GBP,2
	$t->get_ok('/api/get_cdr?reference=reference2')
		->status_is(200)
		->json_is('/action' => 'get_cdr')
		->json_has('/cdr');
};

# TODO MAYBE, just my thoughts after hard work day
# TODO or NOT TODO ... With these test we don't need manual checking,
# TODO or NOT TODO ... with OpenAPI the structure is validated, so don't go too deep into the structure

# TODO    ... rather check status, valid values (action, ierr)

# TODO On the other hand why not to be strict, if there is time

# Well ... let's continue, at least with a regard to spec.yaml :-)
subtest 'Count CDR records and total duration' => sub {
	$t->get_ok('/api/count_cdr')
		->status_is(400)
		->json_is('/errors/0/message' => 'Missing property.')
		->json_is('/errors/0/path' => '/start_date')
		->json_is('/errors/1/message' => 'Missing property.')
		->json_is('/errors/1/path' => '/end_date');
};

subtest 'Get CDR for caller_id' => sub {
	$t->get_ok('/api/cdr_by_caller')
		->status_is(400)
		->json_is('/errors/0/message' => 'Missing property.')
		->json_is('/errors/0/path' => '/start_date')
		->json_is('/errors/1/message' => 'Missing property.')
		->json_is('/errors/1/path' => '/end_date')
		->json_is('/errors/2/message' => 'Missing property.')
		->json_is('/errors/2/path' => '/caller_id');
};

subtest 'Get CDR for caller_id' => sub {
	$t->get_ok('/api/cdr_by_caller/top')
		->status_is(400)
		->json_is('/errors/0/message' => 'Missing property.')
		->json_is('/errors/0/path' => '/start_date')
		->json_is('/errors/1/message' => 'Missing property.')
		->json_is('/errors/1/path' => '/end_date')
		->json_is('/errors/2/message' => 'Missing property.')
		->json_is('/errors/2/path' => '/caller_id')
		->json_is('/errors/3/message' => 'Missing property.')
		->json_is('/errors/3/path' => '/top_x_queries')
};

done_testing();
