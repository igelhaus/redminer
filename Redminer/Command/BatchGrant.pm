package Redminer::Command;

use 5.010;
use strict;
use warnings;

sub _args_spec { [ 'project=s@', 'user=s@', 'group=s@', 'role=s@', 'dry-run', ] }

sub _run
{
	my $self = shift;

	my @role_ids;
	$self->iterate('roles', sub {
		my $role = shift;
		return if !$self->filter('role', $role, {
			regex => [qw/name/],
			plain => [qw/name id/],
		});
		push @role_ids, $role->{id};
		$self->log(sprintf 'Role \'%s\' (internal ID %d) will be granted',
			Encode::encode_utf8($role->{name}),
			$role->{id},
		);
	});
	if (@role_ids == 0) {
		$self->log('--role filter not specified');
		return;
	}

	my @projects;
	$self->iterate('projects', sub {
		my $project = shift;
		return if !$self->filter('project', $project, {
			regex => [qw/identifier name/],
			plain => [qw/identifier id/],
		});
		push @projects, $project;
	});

	my @groups;
	$self->iterate('groups', sub {
		my $group = shift;
		return if !$self->filter('group', $group, {
			regex => [qw/name/],
			plain => [qw/name id/],
		});
		push @groups, $group;
	});

	my @users;
	$self->iterate('users', sub {
		my $user = shift;
		return if !$self->filter('user', $user, {
			regex => [qw/login firstname lastname/],
			plain => [qw/login firstname lastname id/],
		});
		push @users, $user;
	});

	if (@groups == 0 && @users == 0) {
		$self->log('Neither --group nor --user filters matched');
		return;
	}

	foreach my $project (@projects) {
		$self->log(sprintf 'Processing project \'%s\' (internal ID %d)...',
			Encode::encode_utf8($project->{name}),
			$project->{id},
		);
		foreach my $group (@groups) {
			$self->log(sprintf "\tGranting to group '%s' (internal ID %d)",
				Encode::encode_utf8($group->{name}),
				$group->{id},
			);
			$self->_grant($project->{id}, {
				user_id  => $group->{id},
				role_ids => \@role_ids,
			});
		}
		foreach my $user (@users) {
			$self->log(sprintf "\tGranting to user '%s %s' (internal ID %d)",
				Encode::encode_utf8($user->{firstname}),
				Encode::encode_utf8($user->{lastname}),
				$user->{id},
			);
			$self->_grant($project->{id}, {
				user_id  => $user->{id},
				role_ids => \@role_ids,
			});
		}
		$self->log('Project processed');
	}

	return 1;
}

sub _grant
{
	my $self       = shift;
	
	return 1 if $self->args->{'dry-run'};

	my $pid        = shift;
	my $membership = shift;

	if (!$self->engine->createProjectMembership($pid, $membership)) {
		$self->log('Warning: not granted');
		$self->_log_engine_errors;
		return;
	}

	return 1;
}

1;
