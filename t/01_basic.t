use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Test::Mojo;
use File::Temp qw(tempfile);
use Mojo::File qw(curfile);
use CdrStoreApp::Model::CdrStore::CdrRecord;
use CdrStoreApp::Model::CdrStore::LookupHandler;


my $t = Test::Mojo->new(
	'CdrStoreApp',
	{
		mariadb    => 'mariadb://cdr_store_test:cdr_store_test_pass@127.0.0.1:3307/test',
		batch_size => 3,
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
		Time::Piece
	);

	for my $module (@modules) {
		require_ok $module or BAIL_OUT "Cannot load module $module\n";
	}
};

subtest 'Test deploy command and initialize DB' => sub {
	# Testing objects to test inserts to customers and recipients tables
	my $test_cdr1 = CdrStoreApp::Model::CdrStore::CdrRecord->new(
		call_date => '01/31/2023',
		caller_id => '420123456789',
		cost      => '0.044',
		currency  => 'GBP',
		db        => $t->app->mariadb->db,
		duration  => 306,
		end_time  => '16:30:01',
		recipient => '420349822711',
		reference => 'C2069DB0D6B16E3BCBDDE80CA9FF96E3A',
		type      => 2,
	);

	my $test_cdr2 = CdrStoreApp::Model::CdrStore::CdrRecord->new(
		call_date => '01/31/2023',
		caller_id => '420987654321',
		cost      => '0.044',
		currency  => 'GBP',
		db        => $t->app->mariadb->db,
		duration  => 306,
		end_time  => '16:30:01',
		recipient => '420444677333',
		reference => 'C2069DB0D6B16E3BCBDDE80CA9FF96E3A',
		type      => 2,
	);

	throws_ok { $t->app->commands->run('deploy', '-v', -1) } qr/Version -1 has no migration/, 'undefined version caught ok';
	ok( $t->app->commands->run('deploy', '-r') eq 1, 'reset db ok' );

	# Test insert to customers table
	ok( $test_cdr1->_insert_msisdn_into_table('customers', $test_cdr1->{caller_id}) eq 1, 'insert msisdn into customers' );
	ok( $test_cdr2->_insert_msisdn_into_table('customers', $test_cdr2->{caller_id}) eq 2, 'insert 2nd msisdn into customers, returns id 2' );
	lives_ok { $test_cdr1->_insert_msisdn_into_table('customers', $test_cdr1->{caller_id}) } 'insert ignore on duplicate does not fail';
	ok( $test_cdr1->_insert_msisdn_into_table('customers', $test_cdr1->{caller_id}) eq 1, 'insert 1st msisdn into customers, returns id 1' );

	# Test the same with recipients table
	ok( $test_cdr1->_insert_msisdn_into_table('recipients', $test_cdr1->{recipient}) eq 1, 'insert msisdn into customers' );
	ok( $test_cdr2->_insert_msisdn_into_table('recipients', $test_cdr2->{recipient}) eq 2, 'insert 2nd msisdn into customers, returns id 2' );
	lives_ok { $test_cdr1->_insert_msisdn_into_table('recipients', $test_cdr1->{recipient}) } 'insert ignore on duplicate does not fail';
	ok( $test_cdr1->_insert_msisdn_into_table('recipients', $test_cdr1->{recipient}) eq 1, 'insert 1st msisdn into customers, returns id 1' );

	ok( $t->app->commands->run('deploy', '-v', 3) eq 1, 'upgrade to version 3 ok' );

	ok( _delete_all_from_table($t, 'customers') eq 1, 'delete all from customers');
};

subtest 'Test CSV upload' => sub {
	throws_ok { $t->app->commands->run('upload', 'xxxx') } qr/Cannot open file 'xxxx'/, 'file does not exist okay';

	my $csvfile = _generate_content();

	ok( $t->app->commands->run('upload', $csvfile) eq 1, 'upload looks ok' );

	my $class = 'Mojo::Collection';
	my $lookup_handler = CdrStoreApp::Model::CdrStore::LookupHandler->new();
	my $calls_result = $t->app->mariadb->db->query(
		$lookup_handler->compose_all_columns_select . ' ORDER BY reference'			# TODO: I know, this ORDER BY is silly
	)->hashes;
	isa_ok($calls_result, $class);
	my $expected_records = $class->new(
		{
			'call_date' => '16/08/2016',
			'caller_id' => '441216000000',
			'cost'      => '0.000',
			'currency'  => 'GBP',
			'duration'  => 43,
			'end_time'  => '14:21:33',
			'recipient' => '448000000000',
			'reference' => 'reference1',
			'type'      => 2,
		},
		{
			'call_date' => '16/08/2016',
			'caller_id' => '442036000000',
			'cost'      => '0.000',
			'currency'  => 'GBP',
			'duration'  => 244,
			'end_time'  => '14:00:47',
			'recipient' => '44800833833',
			'reference' => 'reference2',
			'type'      => 2,
		},
		{
			'caller_id' => '441827000000',
			'call_date' => '16/08/2016',
			'cost'      => '0.000',
			'currency'  => 'GBP',
			'duration'  => 373,
			'end_time'  => '14:32:40',
			'recipient' => '448002000000',
			'reference' => 'reference4',
			'type'      => 1,
		},
		{
			'call_date' => '16/08/2016',
			'caller_id' => '442036000000',
			'cost'      => '0.000',
			'currency'  => 'GBP',
			'duration'  => 149,
			'end_time'  => '14:05:29',
			'recipient' => '448088000000',
			'reference' => 'reference5',
			'type'      => 2,

		},
		{
			'call_date' => '18/08/2016',
			'caller_id' => '447497000000',
			'cost'      => '0.044',
			'currency'  => 'GBP',
			'duration'  => 306,
			'end_time'  => '16:30:01',
			'recipient' => '447909000000',
			'reference' => 'reference7',
			'type'      => 2,
		},
	);
	is_deeply($calls_result, $expected_records, 'valid records uploaded');

	my $invalid_calls_result = _select_all_from_table($t, 'invalid_call_records');
	isa_ok($invalid_calls_result, $class);
	my $expected_invalid_records = $class->new(
		{
			id     => 1,
			record => ',448001000000,16/08/2016,14:21:50,31,0,reference3,GBP,1',
		},
		{
			id     => 2,
			record => '442036000000,448088000000,16/08/2016,14:05:29,iAmString,0,reference6,GBP,2',
		},
	);
	is_deeply($invalid_calls_result, $expected_invalid_records, 'invalid records uploaded');
};

done_testing();

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

sub _select_all_from_table {
	my ($t, $table) = @_;
	return $t->app->mariadb->db->query("SELECT * FROM $table")->hashes;
}

sub _delete_all_from_table {
	my ($t, $table) = @_;
	$t->app->mariadb->db->delete($table);
	return 1;
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



__DATA__
caller_id,recipient,call_date,end_time,duration,cost,reference,currency,type
441216000000,448000000000,16/08/2016,14:21:33,43,0,reference1,GBP,2
442036000000,44800833833,16/08/2016,14:00:47,244,0,reference2,GBP,2
,448001000000,16/08/2016,14:21:50,31,0,reference3,GBP,1
441827000000,448002000000,16/08/2016,14:32:40,373,0,reference4,GBP,1
442036000000,448088000000,16/08/2016,14:05:29,149,0,reference5,GBP,2
442036000000,448088000000,16/08/2016,14:05:29,iAmString,0,reference6,GBP,2
447497000000,447909000000,18/08/2016,16:30:01,306,0.044,reference7,GBP,2
