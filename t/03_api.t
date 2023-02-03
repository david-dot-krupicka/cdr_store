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

subtest 'Test missing properties' => sub {
	$t->get_ok('/api/get_cdr')
		->status_is(400)
		->json_is('/errors/0/message' => 'Missing property.')
		->json_is('/errors/0/path' => '/reference');


	$t->get_ok('/api/count_cdr')
		->status_is(400)
		->json_is('/errors/0/message' => 'Missing property.')
		->json_is('/errors/0/path' => '/start_date')
		->json_is('/errors/1/message' => 'Missing property.')
		->json_is('/errors/1/path' => '/end_date');

	$t->get_ok('/api/cdr_by_caller')
		->status_is(400)
		->json_is('/errors/0/message' => 'Missing property.')
		->json_is('/errors/0/path' => '/start_date')
		->json_is('/errors/1/message' => 'Missing property.')
		->json_is('/errors/1/path' => '/end_date')
		->json_is('/errors/2/message' => 'Missing property.')
		->json_is('/errors/2/path' => '/caller_id');
};

subtest 'Get CDR by reference' => sub {
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
		->json_has('/cdr')
		->json_is('/cdr/caller_id' => 442036000000, 'has correct caller_id')
		->json_is('/cdr/recipient' => 44800833833, 'has correct recipient')
		->json_is('/cdr/call_date' => '16/08/2016', 'has correct call_date')
		->json_is('/cdr/end_time' => '14:00:47', 'has correct end_time')
		->json_is('/cdr/duration' => 244, 'has correct duration')
		->json_is('/cdr/cost' => 0, 'has correct cost')
		->json_is('/cdr/reference' => 'reference2', 'has correct reference')
		->json_is('/cdr/currency' => 'GBP', 'has correct currency')
		->json_is('/cdr/type' => 2, 'has correct type');
};

subtest 'Count CDR records and total duration' => sub {
	$t->get_ok('/api/count_cdr?start_date=16%2F08%2F2016T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(200)
		->json_is('/action' => 'get_cdr_count')
		->json_is('/status' => 200)
		->json_is('/cdr_count' => 1, 'has cdr_count 1')
		->json_is('/total_call_duration' => '00:06:13', 'has correct total_call_duration 00:06:13');

	$t->get_ok('/api/count_cdr?start_date=2018%2F08%2F20T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(400)
		->json_is('/action' => 'get_cdr_count', 'has action get_cdr_count')
		->json_is('/status' => 400, 'has status 400')
		->json_is('/ierr' => 'failed_to_parse_date', 'has ierr failed_to_parse_date');

	$t->get_ok('/api/count_cdr?start_date=16%2F08%2F2010T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(400)
		->json_is('/action' => 'get_cdr_count', 'has action get_cdr_count')
		->json_is('/status' => 400, 'has status 400')
		->json_is('/ierr' => 'time_range_exceeds_one_month', 'has ierr time_range_exceeds_one_month');

	$t->get_ok('/api/count_cdr?start_date=16%2F08%2F2020T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(400)
		->json_is('/action' => 'get_cdr_count', 'has action get_cdr_count')
		->json_is('/status' => 400, 'has status 400')
		->json_is('/ierr' => 'start_date_higher_then_end_date', 'has ierr start_date_higher_then_end_date');

	# Test we get the correct result also if caller_id is specified
	$t->get_ok('/api/count_cdr?start_date=16%2F08%2F2016T11:00:00&end_date=20%2F08%2F2016&call_type=1&caller_id=447497000000')
		->status_is(200)
		->json_is('/action' => 'get_cdr_count')
		->json_is('/status' => 200)
		->json_is('/cdr_count' => 2, 'has cdr_count 2')
		->json_is('/total_call_duration' => '00:21:19', 'has correct total_call_duration 00:21:19');
};

subtest 'Get CDR for caller_id' => sub {
	# 447497000000,447909000000,18/08/2016,16:30:01,306,0.044,reference7,GBP,2
	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=19%2F08%2F2016&caller_id=447497000000')
		->status_is(200)
		->json_is('/action' => 'get_cdr_list')
		->json_is('/caller_id' => 447497000000)
		->json_has('/records')
		->json_is('/records/0/reference' => 'reference10')
		->json_is('/records/0/call_date' => '18/08/2016')
		->json_is('/records/0/end_time' => '14:30:01');

	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(400)
		->json_is('/errors/0/path' => '/caller_id');
};

subtest 'Get top X CDR for caller_id' => sub {
	# 447497000000,447909000000,18/08/2016,16:30:01,906,0.094,reference7,GBP,1
	# 447497000000,447909000000,18/08/2016,18:30:01,1000,0.120,reference8,GBP,2
	# 447497000000,447909000000,18/08/2016,13:30:01,800,0.80,reference9,GBP,2
	# 447497000000,447909000000,18/08/2016,14:30:01,600,0.60,reference10,GBP,2
	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=19%2F08%2F2016&caller_id=447497000000&top_x_calls=3&call_type=2')
		->status_is(200)
		->json_is('/records/0/cost' => 0.8)
		->json_is('/records/1/cost' => 0.6)
		->json_is('/records/2/cost' => 0.12);
};

done_testing();
