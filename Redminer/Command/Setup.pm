package Redminer::Command;

use 5.010;
use strict;
use warnings;

use File::Copy qw/move/;

sub _args_spec { [ 'host=s', 'user=s', 'pass=s', 'key=s', 'work_as=s', ] }

sub _run
{
	my $self   = shift;
	my $config = Config::IniFiles->new;

	if ($self->args->{host}) {
		$config->newval('redmine', 'host', $self->args->{host});
	} else {
		$self->log('Redmine host is not set');
		return;
	}

	if ($self->args->{key}) {
		$config->newval('redmine', 'key', $self->args->{key});
	} else {
		$self->log('API key, which is recommended authentication method, is not passed via --key');
		if ($self->args->{user}) {
			$config->newval('redmine', 'user', $self->args->{user});
			$config->newval('redmine', 'pass', $self->args->{pass}) if length $self->args->{pass};
		} else {
			$self->log('User login is not passed via --user, assuming anonymous access');
		}
	}

	$config->newval('redmine', 'work_as', $self->args->{work_as}) if length $self->args->{work_as};

	my $redmine_config = $ENV{HOME} . '/.redminer/redminer.conf';

	if (-e -f $redmine_config) {
		my $redmine_config_bak = $redmine_config . '.old';
		unlink $redmine_config_bak;
		$self->log("Another config found, backing it up as '$redmine_config_bak'");
		File::Copy::move($redmine_config, $redmine_config_bak);
	}

	$self->log("Writing config to '$redmine_config'");
	$config->SetFileName($redmine_config);
	$config->WriteConfig($redmine_config);

	return 1;
}

1;
