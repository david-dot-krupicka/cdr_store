use Mojo::Base -strict;

use Test::More;
use Test::Mojo;


# TODO: The test relies on records uploaded in 01_commands.t
# TODO: Deploy and upload new records beforehand
my $t = Test::Mojo->new(
	'CdrStoreApp',
	{
		mariadb    => 'mariadb://cdr_store_test:cdr_store_test_pass@127.0.0.1:3307/test',
		batch_size => 3,
	}
);

subtest 'Get CDR by reference' => sub {
	#442036000000,44800833833,16/08/2016,14:00:47,244,0,reference002,GBP,2
	$t->get_ok('/api/get_cdr?reference=reference002')
		->status_is(200)
		->json_is('/action' => 'get_cdr')
		->json_has('/cdr')
		->json_is('/cdr/caller_id' => 442036000000, 'has correct caller_id')
		->json_is('/cdr/recipient' => 44800833833, 'has correct recipient')
		->json_is('/cdr/call_date' => '16/08/2016', 'has correct call_date')
		->json_is('/cdr/end_time' => '14:00:47', 'has correct end_time')
		->json_is('/cdr/duration' => 244, 'has correct duration')
		->json_is('/cdr/cost' => 0, 'has correct cost')
		->json_is('/cdr/reference' => 'reference002', 'has correct reference')
		->json_is('/cdr/currency' => 'GBP', 'has correct currency')
		->json_is('/cdr/type' => 2, 'has correct type');

	#442036000000,448088000000,16/08/2016,14:05:29,iAmString,0,reference006,GBP,2
	$t->get_ok('/api/get_cdr?reference=reference006')
		->status_is(422)
		->json_is('/error' => 'invalid_record')
		->json_has('/record');

	# not_found
	$t->get_ok('/api/get_cdr?reference=referenceXXX')
		->status_is(404)
		->json_is('/error' => 'not_found', 'test not found');
};

done_testing();