package CdrStoreApp::Model::CdrStore::CdrRecordTypes;
use Moose;
use Moose::Util::TypeConstraints;
subtype 'CdrRecord::Type::RecordType'
	=> as 'Int'
	=> where { $_ =~ /^[1|2]$/ }
	=> message { "Attribute (type): Validation failed for '1-2' with value $_"};

__PACKAGE__->meta()->make_immutable();
1;