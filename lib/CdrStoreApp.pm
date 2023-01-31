package CdrStoreApp;
use Mojo::Base Mojolicious;

use Mojo::mysql;
use CdrStoreApp::Model::CdrStore;
use Function::Parameters;

has mariadb => sub {
	my ($app) = @_;

	my $mariadb = Mojo::mysql->strict_mode($app->config->{mariadb});
	$mariadb->migrations->from_data;
	return $mariadb;
};

method startup() {
	$self->moniker('cdrstoreapp');
	$self->plugin('Config');

	push @{ $self->commands->namespaces }, 'CdrStoreApp::Command';

	$self->helper('cdrstore' => sub {
		my ($c) = @_;
		my $config = $c->app->config;
		return CdrStoreApp::Model::CdrStore->new(
			mariadb => $self->mariadb,
		);
	});

	# TODO: remove
	my $r = $self->routes;

	# API
	$self->plugin("OpenAPI" => {url => $self->home->rel_file("spec/spec.yaml")});
}

method destroy() {
	if ($self->mariadb->db) {
		print "Disconnecting from the db...\n";
		$self->mariadb->disconnect();
	}
}

1;

__DATA__

@@ migrations

-- 1 up

CREATE TABLE IF NOT EXISTS customers (
	id int(10) unsigned NOT NULL AUTO_INCREMENT,
	MSISDN decimal(15,0) NOT NULL UNIQUE,
	PRIMARY KEY(id)
);
CREATE TABLE IF NOT EXISTS recipients (
	id int(10) unsigned NOT NULL AUTO_INCREMENT,
	MSISDN decimal(15,0) NOT NULL UNIQUE,
	PRIMARY KEY(id)
);
CREATE TABLE IF NOT EXISTS call_records (
	reference char(33) NOT NULL,
	caller_id int(10) unsigned NOT NULL,
	recipient int(10) unsigned NOT NULL,
	call_date date DEFAULT NULL,
	end_time time DEFAULT NULL,
	duration mediumint(8) unsigned DEFAULT 0,
	cost decimal(6,3) DEFAULT NULL,
	currency char(3) DEFAULT NULL,
	type smallint(1) DEFAULT NULL CHECK (type in (1,2)),
	PRIMARY KEY (reference),
	KEY fk_caller_id (caller_id),
	KEY fk_recipient (recipient),
	CONSTRAINT fk_caller_id FOREIGN KEY (caller_id) REFERENCES customers (id),
	CONSTRAINT fk_recipient FOREIGN KEY (recipient) REFERENCES recipients (id)
);

-- 1 down

DROP TABLE IF EXISTS call_records;
DROP TABLE IF EXISTS recipients;
DROP TABLE IF EXISTS customers;

-- 2 up

CREATE TABLE IF NOT EXISTS invalid_call_records (
	id int(10) unsigned NOT NULL AUTO_INCREMENT,
	record TEXT,
	PRIMARY KEY (id)
);

-- 2 down

DROP TABLE IF EXISTS invalid_call_records;
