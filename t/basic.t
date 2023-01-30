use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Test::Mojo;
use File::Temp qw(tempfile);
use Mojo::File qw(curfile);



my $t = Test::Mojo->new(
	'CdrStoreApp',
	{
		mariadb    => 'mariadb://cdr_store_test:cdr_store_test_pass@127.0.0.1:3307/test',
		batch_size => 3,
		columns => [ qw(caller_id recipient_id call_date end_time duration cost reference currency type) ],
	}
);

subtest 'Required Perl modules' => sub {
	my @modules = qw(
		DBD::MariaDB
		Exception::Class::Try::Catch
		Function::Parameters
		Mojo::mysql
		Mojolicious::Plugin::OpenAPI
		Moose
		MooseX::NonMoose
		Text::CSV_XS
	);

	for my $module (@modules) {
		require_ok $module or BAIL_OUT "Cannot load module $module\n";
	}
};

subtest 'Test deploy command and initialize DB' => sub {
	throws_ok { $t->app->commands->run('deploy', '-v', -1) } qr/Version -1 has no migration/, 'undefined version caught ok';
	ok( $t->app->commands->run('deploy', '-r') eq 1, 'reset db ok' );

	# Insert some row to test the version upgrade does not delete the entries
	my $msisdn = 420123456789;
	my $msisdn2 = 420987654321;

	ok( $t->app->cdrstore->insert_msisdn_into_table($msisdn, 'customers') eq 1, 'insert msisdn into customers' );
	ok( $t->app->cdrstore->insert_msisdn_into_table($msisdn2, 'customers') eq 2, 'insert 2nd msisdn into customers, returns id 2' );

	lives_ok { $t->app->cdrstore->insert_msisdn_into_table($msisdn, 'customers') } 'insert ignore on duplicate does not fail';
	ok( $t->app->cdrstore->insert_msisdn_into_table($msisdn, 'customers') eq 1, 'insert 1st msisdn into customers, returns id 1' );

	ok( $t->app->commands->run('deploy', '-v', 2) eq 1, 'upgrade to version 2 ok' );

	ok( $t->app->cdrstore->delete_all_from_table('customers') eq 1, 'delete all from customers');
};

subtest 'Test CSV upload' => sub {
	throws_ok { $t->app->commands->run('upload', 'xxxx') } qr/Cannot open file 'xxxx'/, 'file does not exist okay';

	my $csvfile = _generate_content();
	# wrong content, like invalid type not tested, but empty records will be NULL

	ok( $t->app->commands->run('upload', $csvfile) eq 1, 'upload looks ok' );

	my $class = 'Mojo::Collection';
	my $calls_result = $t->app->cdrstore->select_all_records;
	isa_ok($calls_result, $class);
	my $expected_records = $class->new(
		{
			'call_date' => '18/08/2016',
			'duration' => 306,
			'type' => 2,
			'cost' => '0.044',
			'called_id' => '447497000000',
			'currency' => 'GBP',
			'reference' => 'C2069DB0D6B16E3BCBDDE80CA9FF96E3A',
			'recipient' => '447909000000',
			'end_time' => '16:30:01'
		},
		{
			'call_date' => '16/08/2016',
			'cost' => '0.000',
			'type' => 2,
			'duration' => 244,
			'recipient' => '44800833833',
			'reference' => 'C50B5A7BDB8D68B8512BB14A9D363CAA1',
			'currency' => 'GBP',
			'end_time' => '14:00:47',
			'called_id' => '442036000000'
		},
		{
			'reference' => 'C5DA9724701EEBBA95CA2CC5617BA93E4',
			'currency' => 'GBP',
			'recipient' => '448000000000',
			'end_time' => '14:21:33',
			'called_id' => '441216000000',
			'call_date' => '16/08/2016',
			'type' => 2,
			'duration' => 43,
			'cost' => '0.000'
		},
		{
			'call_date' => '16/08/2016',
			'cost' => '0.000',
			'duration' => 373,
			'type' => 1,
			'recipient' => '448002000000',
			'currency' => 'GBP',
			'reference' => 'C639033F0752A937D951A6A2E33EB6910',
			'end_time' => '14:32:40',
			'called_id' => '441827000000'
		},
		{
			'duration' => 149,
			'type' => 2,
			'cost' => '0.000',
			'call_date' => '16/08/2016',
			'called_id' => '442036000000',
			'end_time' => '14:05:29',
			'reference' => 'C6C4EC9A8C4847E8AD1B1D6CD02491E79',
			'currency' => 'GBP',
			'recipient' => '448088000000'
		}
	);
	is_deeply($calls_result, $expected_records, 'valid records uploaded');

	my $invalid_calls_result = $t->app->cdrstore->select_all_from_table('invalid_call_records');
	isa_ok($invalid_calls_result, $class);
	my $expected_invalid_records = $class->new({
		call_date => '2016-08-16',	# TODO: transform the date in the actual output (but for test it's ok)
		caller_id => undef,
		cost => '0.000',
		currency => 'GBP',
		duration => 31,
		end_time => '14:21:50',
		id => 1,
		recipient_id => '448001000000',
		reference => 'C0FAAB1E6424B20D1625FEAAD5936053E',
		type => 1,
	});
	is_deeply($invalid_calls_result, $expected_invalid_records, 'invalid records uploaded');
};

sub _generate_content {
	my ($fh, $tempfile) = tempfile(
		TEMPLATE => 'tmpXXXXX',
		DIR => $t->app->home,
		SUFFIX => '.csv',
		UNLINK => 1,
	);
	while (<DATA>) {
		print $fh $_;
	}
	$fh->close();

	return $tempfile;
}

#subtest 'Test upload workflow' => sub {
#	# Test if the HTML update form exists
#	$t->get_ok('/upload')
#	->status_is(200)
#	->element_exists('form input[name="file"]')
#	->element_exists('form input[type="submit"]');
#
#	# Test file upload
#	my $upload = {foo => {content => 'foo,bar,baz', file => 'test.csv'}};
#	$t->post_ok('/upload_file' => form => $upload)
#	->status_is(200)
#};

done_testing();

__DATA__
caller_id,recipient,call_date,end_time,duration,cost,reference,currency,type
441216000000,448000000000,16/08/2016,14:21:33,43,0,C5DA9724701EEBBA95CA2CC5617BA93E4,GBP,2
442036000000,44800833833,16/08/2016,14:00:47,244,0,C50B5A7BDB8D68B8512BB14A9D363CAA1,GBP,2
,448001000000,16/08/2016,14:21:50,31,0,C0FAAB1E6424B20D1625FEAAD5936053E,GBP,1
441827000000,448002000000,16/08/2016,14:32:40,373,0,C639033F0752A937D951A6A2E33EB6910,GBP,1
442036000000,448088000000,16/08/2016,14:05:29,149,0,C6C4EC9A8C4847E8AD1B1D6CD02491E79,GBP,2
447497000000,447909000000,18/08/2016,16:30:01,306,0.044,C2069DB0D6B16E3BCBDDE80CA9FF96E3A,GBP,2
