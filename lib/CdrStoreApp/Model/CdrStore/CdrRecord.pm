package CdrStoreApp::Model::CdrStore::CdrRecord;
use Moose;
use CdrStoreApp::Model::CdrStore::CdrRecordTypes;
use Function::Parameters;
use Time::Piece;

# TODO: remove say where it's not needed, like here
use feature 'say';

# Implements only very basic type checking
has call_date => (is => 'ro', isa => 'Str', required => 1);
has call_datetime => (
	is => 'ro', isa => 'Time::Piece',
	lazy => 1, builder => '_build_call_datetime'
);
has caller_id => (is => 'ro', isa => 'Int', required => 1);
has cost => (is => 'ro', isa => 'Num', required => 1);
has currency => (is => 'ro', isa => 'Str', required => 1);
has db => (is => 'ro', isa => 'Mojo::mysql::Database', required => 1);
has duration => (is => 'ro', isa => 'Int', required => 1);
has end_time => (is => 'ro', isa => 'Str', required => 1);
has recipient => (is => 'ro', isa => 'Int', required => 1);
has reference => (is => 'ro', isa => 'Str', required => 1);
has type => (is => 'ro', isa => 'CdrRecord::Type::RecordType', required => 1);

method _build_call_datetime () {
	my $maybe_datetime = sprintf('%s %s', $self->call_date, $self->end_time);
	return Time::Piece->strptime($maybe_datetime, '%d/%m/%Y %H:%M:%S');
}

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
				reference     => $self->reference,
				caller_id     => $caller_id,
				recipient     => $recipient_id,
				call_datetime => $self->call_datetime->strftime('%Y-%m-%d %H:%M:%S'),
				duration      => $self->duration,
				cost          => $self->cost,
				currency      => $self->currency,
				type          => $self->type,
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

1;