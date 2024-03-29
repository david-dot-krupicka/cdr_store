package CdrStoreApp::Command::deploy;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util 'getopt';
use Function::Parameters;
use Exception::Class::Try::Catch;

has 'description' => 'Deploy or update the CdrStoreApp schema';
has 'usage' => <<"EOF";
$0 deploy [-r|--reset] [-v|--version <version>]
	-r, --reset\treset to the latest version, DELETES ALL RECORDS!!!
	-v, --version\tversion to deploy, defaults to the latest
EOF

method run (@args) {
	getopt(
		\@args,
		'r|reset' => \my $reset,
		'v|version=i' => \my $version,
	);

	try {
		if (defined $version) {
			$self->app->mariadb->migrations->migrate($version);
			say "Deployed DB version $version";
		}
		elsif (defined $reset) {
			$self->app->mariadb->migrations->migrate(0)->migrate;
			say "Reset to the latest DB version";
		}
		else {
			$self->app->mariadb->migrations->migrate;
			say "Deployed the latest DB version";
		}
	} catch {
		$_->rethrow();
	};

	return 1;
}

1;