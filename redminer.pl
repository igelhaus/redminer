#/usr/bin/env perl

use 5.010;
use strict;
use warnings;

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
	REDMINE_OPTIONS    => 'redmine',
};

my $config = Config::IniFiles->new(-file => GLOBAL_CONFIG_NAME);
if (!$config) {
	die q/Unable to access global options, please run 'redminer setup'/;
}

my $redminer = WebService::Redmine->new(
	host              => $config->val(REDMINE_OPTIONS,    'host') // '',
	user              => $config->val(REDMINE_OPTIONS,    'user') // '',
	pass              => $config->val(REDMINE_OPTIONS,    'pass') // '',
	key               => $config->val(REDMINE_OPTIONS,     'key') // '',
	work_as           => $config->val(REDMINE_OPTIONS, 'work_as') // '',
	no_wrapper_object => 1,
);

my $command = Redminer::Command->new(engine => $redminer);

$command->run;

exit;
