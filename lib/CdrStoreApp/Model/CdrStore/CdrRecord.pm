package CdrStoreApp::Model::CdrStore::CdrRecord;
use Moose;
use Moose::Util::TypeConstraints;
use Function::Parameters;

use feature 'say';

# Implements only very basic type checking
subtype 'RecordType'
	=> as 'Int'
	=> where { $_ =~ /^[12]$/ }
	=> message { "Attribute (type): Validation failed for '1-2'"};

has call_date => (is => 'ro', isa => 'Str', required => 1);
has caller_id => (is => 'ro', isa => 'Int', required => 1);
has cost => (is => 'ro', isa => 'Num', required => 1);
has currency => (is => 'ro', isa => 'Str', required => 1);
has db => (is => 'ro', isa => 'Mojo::mysql::Database', required => 1);
has duration => (is => 'ro', isa => 'Int', required => 1);
has end_time => (is => 'ro', isa => 'Str', required => 1);
has recipient => (is => 'ro', isa => 'Int', required => 1);
has reference => (is => 'ro', isa => 'Str', required => 1);
has type => (is => 'rw', isa => 'RecordType', required => 1);

method insert_record () {
	my $caller_id = $self->_insert_msisdn_into_table(
		'customers',
		$self->caller_id,
	);
	my $recipient_id = $self->_insert_msisdn_into_table(
		'recipients',
		$self->recipient,
	);

	$self->db->insert(
		'call_records',
			{
				reference => $self->reference,
				caller_id => $caller_id,
				recipient => $recipient_id,
				call_date => _format_date_string($self->call_date),
				end_time  => $self->end_time,
				duration  => $self->duration,
				cost      => $self->cost,
				currency  => $self->currency,
				type      => $self->type,
			}
	);
}

method _insert_msisdn_into_table ($table, $msisdn) {
	my $id = $self->db->query(
		"INSERT IGNORE INTO $table (MSISDN) VALUES (?)", $msisdn
	)->last_insert_id;
	$id = $self->db->select(
		$table, undef, {MSISDN => $msisdn})->hash->{id} if $id == 0;
	return $id;
}

fun _format_date_string ($date) {
	return $date =~ s|(\d{2})/(\d{2})/(\d{4})|$3/$2/$1|r;
}

1;