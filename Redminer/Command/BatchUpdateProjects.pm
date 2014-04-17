package Redminer::Command;

use 5.010;
use strict;
use warnings;

sub _args_spec { [ 'project=s@', 'opt=s%', 'dry-run' ] }

sub _run
{
	my $self = shift;

	if (!exists $self->args->{project} || @{ $self->args->{project} } == 0) {
		$self->log('--project not found');
		return;
	}

	if (!exists $self->args->{opt} || keys %{ $self->args->{opt} } == 0) {
		$self->log('--opt not found');
		$self->log('Expected: --opt key1=value1 --opt key2=value2 ...');
		return;
	}

	if ($self->args->{'dry-run'}) {
		$self->log('*** --dry-run, no action will be taken ***');
		$self->log('Update options:', $self->args->{opt});
	}

	$self->iterate('projects', sub {
		my $project = shift;
		return if !$self->filter('project', $project, {
			regex => [qw/identifier name/],
			plain => [qw/identifier id/],
		});

		$self->log(sprintf 'Trying to update project \'%s\' (internal ID %d)...',
			Encode::encode_utf8($project->{name}),
			$project->{id},
		);

		return 1 if $self->args->{'dry-run'};

		if ($self->engine->updateProject($project->{id}, $self->args->{opt})) {
			$self->log('Updated OK');
			return 1;
		}

		$self->log('Project was not updated');
		$self->_log_engine_errors;
		return 1;
	});
	
	return 1;
}

1;
