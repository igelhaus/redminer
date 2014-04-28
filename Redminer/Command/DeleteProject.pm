package Redminer::Command;

use 5.010;
use strict;
use warnings;

sub _args_spec { [ 'id=s', 'dry-run', ] }

sub _run
{
	my $self = shift;
	
	if (!$self->args->{id}) {
		$self->log('Invalid --id parameter');
		return;
	}

	my $project = $self->engine->project($self->args->{id});
	if (!$project) {
		$self->log('Unable to find project by --id ' . $self->args->{id});
		return;
	}

	$self->log(sprintf
		'Deleting project \'%s\' (internal ID %d) and all its possible subprojects...',
		Encode::encode_utf8($project->{name}),
		$project->{id},
	);

	return 1 if $self->args->{'dry-run'};

	if ($self->engine->deleteProject($self->args->{id})) {
		$self->log('Project deleted');
		return 1;
	}
	
	return;
}

1;
