use Mojo::Base -strict;

use Test::More;
use Test::Warn;
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
_delete_all_records($t);

subtest 'Test CSV upload' => sub {
	throws_ok { $t->app->commands->run('upload', 'xxxx') } qr/Cannot open file 'xxxx'/, 'file does not exist okay';

	my $header = 'caller_id,recipient,call_date,end_time,duration,cost,reference,currency,type';
	my $content = '441216000000,448000000000,16/08/2016,14:21:33,43,0,reference1,GBP,2';
	my $csvfile = _generate_content($header, $content);

	ok( $t->app->commands->run('upload', $csvfile) eq 0, 'upload looks ok' );
	throws_ok { $t->app->commands->run('upload', $csvfile) } qr /record_exists/, 'dies if trying to insert duplicate record';
	_delete_all_records($t);

	# wrong type
	$content = '441216000000,448000000000,16/08/2016,14:21:33,43,0,reference1,GBP,3';
	$csvfile = _generate_content($header, $content);
	warning_like { $t->app->commands->run('upload', $csvfile) } qr /Inserted invalid record ID/, 'dies if trying to insert invalid type';
};

_delete_all_records($t);
done_testing();

sub _generate_content {
	my ($header, $record) = @_;
	my ($fh, $tempfile) = tempfile(
		TEMPLATE => 'tmpXXXXX',
		DIR => $t->app->home,
		SUFFIX => '.csv',
		UNLINK => 1,
	);
	say $fh $header;
	say $fh $record;
	$fh->close();

	return $tempfile;
};

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
