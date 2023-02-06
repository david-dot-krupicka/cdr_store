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

subtest 'Count CDR records and total duration' => sub {
	$t->get_ok('/api/count_cdr?start_date=16%2F08%2F2016T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(200)
		->json_is('/cdr_count' => 1, 'has cdr_count 1')
		->json_is('/total_call_duration' => '00:06:13', 'has correct total_call_duration 00:06:13');

	$t->get_ok('/api/count_cdr?start_date=2018%2F08%2F20T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(400)
		->json_like('/error' => qr/^failed_to_parse_date/, 'fails to parse date');

	$t->get_ok('/api/count_cdr?start_date=16%2F08%2F2010T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(400)
		->json_like('/error' => qr/^time_range_exceeds_one_month/, 'has error time_range_exceeds_one_month');

	$t->get_ok('/api/count_cdr?start_date=16%2F08%2F2020T11:00:00&end_date=17%2F08%2F2016&call_type=1')
		->status_is(400)
		->json_like('/error' => qr/^start_date_higher_then_end_date/, 'has error start_date_higher_then_end_date');

	# Test we get the correct result also if caller_id is specified
	$t->get_ok('/api/count_cdr?start_date=16%2F08%2F2016T11:00:00&end_date=20%2F08%2F2016&call_type=1&caller_id=447497000000')
		->status_is(200)
		->json_is('/cdr_count' => 2, 'has cdr_count 2')
		->json_is('/total_call_duration' => '00:21:19', 'has correct total_call_duration 00:21:19');

	# Test 0 records found
	$t->get_ok('/api/count_cdr?start_date=01%2F01%2F1970T00:00:00&end_date=30%2F01%2F1970')
		->status_is(404)	# should be not found
};

done_testing();