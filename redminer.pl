#/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Encode qw/encode/;

#######################################################
# For local development only
use FindBin;
use lib "$FindBin::Bin/../perl-WebService-Redmine/lib";
#######################################################

use Config::IniFiles;
use WebService::Redmine;
use Redminer::Command;

use constant {
	GLOBAL_CONFIG_NAME => $ENV{HOME} . '/.redminer/redminer.conf',
};

my $config = Config::IniFiles->new(-file => GLOBAL_CONFIG_NAME);
if (!$config) {
	die q/Unable to access global options, please run 'redminer setup'/;
}

my $redminer = WebService::Redmine->new(
	host              => $config->val('redmine',    'host') // '',
	user              => $config->val('redmine',    'user') // '',
	pass              => $config->val('redmine',    'pass') // '',
	key               => $config->val('redmine',     'key') // '',
	work_as           => $config->val('redmine', 'work_as') // '',
	no_wrapper_object => 1,
);

my $command = Redminer::Command->new(engine => $redminer);

$command->run;

exit;

sub render_errors
{
	my $errors = shift;
	if (ref $errors ne 'HASH' && ref $errors->{errors} ne 'ARRAY') {
		return 'Unknown server errors';
	}
	return join "\n", 'Following error(s) reported:', map {
		"\t* " . Encode::encode('UTF-8', $_)
	} @{ $errors->{errors} };
}
