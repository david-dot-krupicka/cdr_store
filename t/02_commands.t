use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Test::Mojo;
use File::Temp qw(tempfile);
use Mojo::File qw(curfile);
use CdrStoreApp::Model::CdrStore::Cdr;


my $t = Test::Mojo->new(
	'CdrStoreApp',
	{
		mariadb    => 'mariadb://cdr_store_test:cdr_store_test_pass@127.0.0.1:3307/test',
		batch_size => 3,
	}
);

#_delete_all_records($t);

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
	my $test_cdr1 = CdrStoreApp::Model::CdrStore::Cdr->new(
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

	my $test_cdr2 = CdrStoreApp::Model::CdrStore::Cdr->new(
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

	_delete_all_records($t);
};

subtest 'Test CSV upload' => sub {
	throws_ok { $t->app->commands->run('upload', 'xxxx') } qr/Cannot open file 'xxxx'/, 'file does not exist okay';

	my $csvfile = _generate_content();

	ok( $t->app->commands->run('upload', $csvfile) eq 0, 'upload looks ok' );

	# If this test is good or not, do not abuse other functionalities.
	# Do the pure select.
	my $statement = <<"	SQL";
SELECT c.msisdn AS caller_id,
	   r.msisdn AS recipient,
	   DATE_FORMAT(call_datetime, '%d/%m/%Y') AS call_date,
	   DATE_FORMAT(call_datetime, '%H:%i:%S') AS end_time,
	   duration,
	   cost,
	   reference,
	   currency,
	   type
FROM call_records cdr
JOIN customers c on cdr.caller_id = c.id
JOIN recipients r on cdr.recipient = r.id
ORDER BY reference
	SQL

	my $calls_result = $t->app->mariadb->db->query($statement)->hashes;

	my $class = 'Mojo::Collection';
	isa_ok($calls_result, $class);
	my $expected_records = [
		{
			'call_date' => '16/08/2016',
			'caller_id' => '441216000000',
			'cost'      => '0.000',
			'currency'  => 'GBP',
			'duration'  => 43,
			'end_time'  => '14:21:33',
			'recipient' => '448000000000',
			'reference' => 'reference001',
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
			'reference' => 'reference002',
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
			'reference' => 'reference004',
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
			'reference' => 'reference005',
			'type'      => 2,

		},
		{
			'call_date' => '18/08/2016',
			'caller_id' => '447497000000',
			'cost'      => '0.094',
			'currency'  => 'GBP',
			'duration'  => 906,
			'end_time'  => '16:30:01',
			'recipient' => '447909000000',
			'reference' => 'reference007',
			'type'      => 1,
		},
		{
			'call_date' => '18/08/2016',
			'caller_id' => '447497000000',
			'cost'      => '0.120',
			'currency'  => 'GBP',
			'duration'  => 1000,
			'end_time'  => '18:30:01',
			'recipient' => '447909000000',
			'reference' => 'reference008',
			'type'      => 2,
		},
		{
			'call_date' => '18/08/2016',
			'caller_id' => '447497000000',
			'cost'      => '0.800',
			'currency'  => 'GBP',
			'duration'  => 800,
			'end_time'  => '13:30:01',
			'recipient' => '447909000000',
			'reference' => 'reference009',
			'type'      => 2,
		},
		{
			'call_date' => '18/08/2016',
			'caller_id' => '447497000000',
			'cost'      => '0.600',
			'currency'  => 'GBP',
			'duration'  => 600,
			'end_time'  => '14:30:01',
			'recipient' => '447909000000',
			'reference' => 'reference010',
			'type'      => 2,
		},
	];
	is_deeply($calls_result, $expected_records, 'valid records uploaded');

	my $invalid_calls_result = _select_all_from_invalid_records($t);
	isa_ok($invalid_calls_result, $class);
	my $expected_invalid_records = [
			{
				id     => 1,
				record => ',448001000000,16/08/2016,14:21:50,31,0,reference003,GBP,1',
			},
			{
				id     => 2,
				record => '442036000000,448088000000,16/08/2016,14:05:29,iAmString,0,reference006,GBP,2',
			},
	];
	is_deeply($invalid_calls_result, $expected_invalid_records, 'invalid records uploaded');

	# Test same file upload again
	dies_ok { $t->app->commands->run('upload', $csvfile ) } qr/whatever/;
};

#_delete_all_records($t);
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

sub _select_all_from_invalid_records {
	my ($t, $table) = @_;
	return $t->app->mariadb->db->query(
		"SELECT * FROM invalid_call_records ORDER BY id"
	)->hashes;
}

sub _delete_all_records {
	my ($t) = @_;
	ok( _delete_all_from_table($t, 'call_records') eq 1, 'delete all from customers');
	ok( _delete_all_from_table($t, 'customers') eq 1, 'delete all from customers');
	ok( _delete_all_from_table($t, 'recipients') eq 1, 'delete all from customers');
}

sub _delete_all_from_table {
	my ($t, $table) = @_;
	$t->app->mariadb->db->delete($table);
	return 1;
}

__DATA__
caller_id,recipient,call_date,end_time,duration,cost,reference,currency,type
441216000000,448000000000,16/08/2016,14:21:33,43,0,reference001,GBP,2
442036000000,44800833833,16/08/2016,14:00:47,244,0,reference002,GBP,2
,448001000000,16/08/2016,14:21:50,31,0,reference003,GBP,1
441827000000,448002000000,16/08/2016,14:32:40,373,0,reference004,GBP,1
442036000000,448088000000,16/08/2016,14:05:29,149,0,reference005,GBP,2
442036000000,448088000000,16/08/2016,14:05:29,iAmString,0,reference006,GBP,2
447497000000,447909000000,18/08/2016,16:30:01,906,0.094,reference007,GBP,1
447497000000,447909000000,18/08/2016,18:30:01,1000,0.120,reference008,GBP,2
447497000000,447909000000,18/08/2016,13:30:01,800,0.80,reference009,GBP,2
447497000000,447909000000,18/08/2016,14:30:01,600,0.60,reference010,GBP,2
