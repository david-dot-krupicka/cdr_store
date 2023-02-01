use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Test::Mojo;
use Time::Piece;


my $t = Test::Mojo->new(
	'CdrStoreApp',
	{
		mariadb    => 'mariadb://cdr_store_test:cdr_store_test_pass@127.0.0.1:3307/test',
		batch_size => 3,
	}
);

# TODO: This is horrible indeed

#subtest 'Test valid dates' => sub {
#	# At least some tests
#	my $expected = { ierr => 'invalid_date' };
#	ok($t->app->cdrstore->_validate_date('2022/16/08') == 0, 'invalid date pattern match 1');
#	ok($t->app->cdrstore->_validate_date('2022/16/') == 0, 'invalid date pattern match 2');
#	ok($t->app->cdrstore->_validate_date('16-08-2022') == 0, 'invalid date pattern match 3');
#	ok($t->app->cdrstore->_validate_date('16-08-2022 16:32:45') == 0, 'invalid date pattern match 4');
#	ok($t->app->cdrstore->_validate_date('16/08/2022 16:32:45') == 0, 'invalid date pattern match 5');
#	ok($t->app->cdrstore->_validate_date('16/08/2022T32:32:45') == 0, 'catched exception 1');
#	ok($t->app->cdrstore->_validate_date('03/31/2022T12:32:45') == 0, 'catched exception 2');
#
#	$expected = Time::Piece->strptime('16/08/2022', '%d/%m/%Y');
#	isa_ok($t->app->cdrstore->_validate_date('16/08/2022'), 'Time::Piece');
#	ok($t->app->cdrstore->_validate_date('16/08/2022') eq $expected, 'valid date 1');
#
#	$expected = Time::Piece->strptime('16/08/2022T16:32:45', '%d/%m/%YT%H:%M:%S');
#	isa_ok($t->app->cdrstore->_validate_date('16/08/2022T16:32:45'), 'Time::Piece');
#	ok($t->app->cdrstore->_validate_date('16/08/2022T16:32:45') eq $expected, 'valid date 2');
#};

subtest 'Test dates out of range' => sub {
	my $expected = { ierr => 'start_date_higher_then_end_date' };
	is_deeply($t->app->cdrstore->count_cdr('16/08/2002', '16/07/2002'), $expected, 'test start date higher then end date' );

	$expected = { ierr => 'time_range_exceeds_one_month' };
	is_deeply($t->app->cdrstore->count_cdr('20/06/2002', '16/08/2002'), $expected, 'test allowed time range 1' );
	is_deeply($t->app->cdrstore->count_cdr('16/07/2002T12:00:00', '16/08/2002T12:00:01'), $expected, 'test allowed time range 2' );


	#is_deeply($t->app->cdrstore->count_cdr('16/08/2016T14:20:34', '18/08/2016T18:58:00', 1), $expected, 'test allowed time range 3' );

};

done_testing();
