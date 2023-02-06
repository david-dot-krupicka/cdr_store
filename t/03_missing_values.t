use Mojo::Base -strict;

use Test::More;
use Test::Mojo;


# TODO: The test relies on records uploaded in 01_commands.t
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

done_testing();
