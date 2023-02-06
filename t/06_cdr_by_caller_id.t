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

subtest 'Get CDR for caller_id' => sub {
	# 447497000000,447909000000,18/08/2016,16:30:01,306,0.044,reference007,GBP,2
	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=19%2F08%2F2016&caller_id=447497000000')
		->status_is(200)
		->json_is('/caller_id' => 447497000000)
		->json_has('/records')
		->json_is('/records/0/reference' => 'reference007')
		->json_is('/records/0/call_date' => '18/08/2016')
		->json_is('/records/0/end_time' => '16:30:01');

	$t->get_ok('/api/cdr_by_caller?start_date=2018%2F08%2F20T11:00:00&end_date=17%2F08%2F2016&call_type=1&caller_id=447497000000')
		->status_is(400)
		->json_like('/error' => qr/^failed_to_parse_date/, 'fails to parse date');

	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2010T11:00:00&end_date=17%2F08%2F2016&call_type=1&caller_id=447497000000')
		->status_is(400)
		->json_like('/error' => qr/^time_range_exceeds_one_month/, 'has error time_range_exceeds_one_month');

	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2020T11:00:00&end_date=17%2F08%2F2016&call_type=1&caller_id=447497000000')
		->status_is(400)
		->json_like('/error' => qr/^start_date_higher_then_end_date/, 'has error start_date_higher_then_end_date');

	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(400)
		->json_is('/errors/0/path' => '/caller_id');

	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=19%2F08%2F2016&caller_id=4474971234546')
		->status_is(404)
		->json_is('/error' => 'not_found');
};

subtest 'Get top X CDR for caller_id' => sub {
	# 447497000000,447909000000,18/08/2016,16:30:01,906,0.094,reference007,GBP,1
	# 447497000000,447909000000,18/08/2016,18:30:01,1000,0.120,reference008,GBP,2
	# 447497000000,447909000000,18/08/2016,13:30:01,800,0.80,reference009,GBP,2
	# 447497000000,447909000000,18/08/2016,14:30:01,600,0.60,reference010,GBP,2
	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=19%2F08%2F2016&caller_id=447497000000&top_x_calls=3&call_type=2')
		->status_is(200)
		->json_is('/records/0/cost' => 0.8)
		->json_is('/records/1/cost' => 0.6)
		->json_is('/records/2/cost' => 0.12);

	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=17%2F13%2F2016&call_type=2&caller_id=447497000000&top_x_calls=3&call_type=2')
		->status_is(400)
		->json_like('/error' => qr/^Error parsing time/, 'fails to parse date');

	$t->get_ok('/api/cdr_by_caller?start_date=16%2F08%2F2016T11:00:00&end_date=19%2F08%2F2016&caller_id=4474971234546&top_x_calls=3')
		->status_is(404)
		->json_is('/error' => 'not_found');
};

done_testing();