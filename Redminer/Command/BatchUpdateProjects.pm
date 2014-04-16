package Redminer::Command;

use 5.010;
use strict;
use warnings;

sub _args_spec { [ 'filter=s@', 'opt=s%' ] }

sub _run
{
	my $self = shift;

	if (!exists $self->args->{filter} || @{ $self->args->{filter} } == 0) {
		$self->log('--filter not found');
		return;
	}

	if (!exists $self->args->{opt} || keys %{ $self->args->{opt} } == 0) {
		$self->log('--opt not found');
		$self->log('Expected: --opt key1=value1 --opt key2=value2 ...');
		return;
	}

	$self->iterate('projects', sub {
		my $project = shift;
		return if !$self->_passes_filter($project);

		$self->log(sprintf 'Trying to update project \'%s\' (internal ID %d)...',
			Encode::encode_utf8($project->{name}),
			$project->{id},
		);
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

sub _passes_filter
{
	my $self    = shift;
	my $project = shift;
	my $filters = $self->args->{filter};

	foreach my $filter (@$filters) {
		if ($filter =~ m|^/(.+)/$|) {
			return 1 if
				$project->{identifier} =~ /$1/ ||
				$project->{name}       =~ /$1/i
			;
		} else {
			my @values = split /,/, $filter;
			foreach my $value (@values) {
				return 1 if 
					$project->{identifier} eq $value ||
					"$project->{id}" eq $value
				;
			}
		}
	}

	return 0;
}

1;
