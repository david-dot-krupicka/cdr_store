use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Test::Mojo;
use File::Temp qw(tempfile);
use Mojo::File qw(curfile);

my $t = Test::Mojo->new(
	'CdrStoreApp',
	{ mariadb => 'mariadb://cdr_store_test:cdr_store_test_pass@127.0.0.1:3307/test' }
);

subtest 'Test deploy command and initialize DB' => sub {
	throws_ok { $t->app->commands->run('deploy', '-v', -1) } qr/Version -1 has no migration/, 'undefined version caught okay';
	ok( $t->app->commands->run('deploy', '-r') eq 1, 'reset db ok' );

	# Insert some row to test the version upgrade does not delete the entries
	$t->mariadb->query('INSERT INTO customers (MSISDN) VALUES (?)', 420123456789);

	$t->mariadb->query('select * from customers')
		->hashes->map(sub { $_->{MSISDN} })->join("\n")->say;
};

subtest 'Test CSV upload' => sub {
	throws_ok { $t->app->commands->run('upload', 'xxxx') } qr/Cannot open file 'xxxx'/, 'file does not exist okay';

	my $csvfile = generate_content();
	# wrong content not tested

	ok( $t->app->commands->run('upload', $csvfile) eq 1, 'upload finished ok' );
};

sub generate_content {
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
441216000000,448000000000,16/08/2016,14:21:33,43,0,C5DA9724701EEBBA95CA2CC5617BA93E4,GBP,2,arhro
442036000000,44800833833,16/08/2016,14:00:47,244,0,C50B5A7BDB8D68B8512BB14A9D363CAA1,GBP,2
,448001000000,16/08/2016,14:21:50,31,0,C0FAAB1E6424B20D1625FEAAD5936053E,GBP,1
441827000000,448002000000,16/08/2016,14:32:40,373,0,C639033F0752A937D951A6A2E33EB6910,GBP,1
