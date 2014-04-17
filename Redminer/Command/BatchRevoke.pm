package Redminer::Command;

use 5.010;
use strict;
use warnings;

sub _args_spec { [ 'project=s@', 'group=s@', 'user=s@', 'dry-run', ] }

sub _run
{
	my $self = shift;

	my ($projects, $groups, $users) = $self->permissionFilter;

	if (@$groups == 0 && @$users == 0) {
		$self->log('Neither --group nor --user filters matched');
		return;
	}

	foreach my $project (@$projects) {
		$self->log(sprintf 'Processing project \'%s\' (internal ID %d)...',
			Encode::encode_utf8($project->{name}),
			$project->{id},
		);

		$self->iterate('projectMemberships', sub {
			my $membership = shift;

			if (exists $membership->{group}) {
				my ($group) = grep { $_->{id} == $membership->{group}{id} } @$groups;
				if ($group) {
					$self->log(sprintf "\tRevoking from group '%s' (internal ID %d)",
						Encode::encode_utf8($group->{name}),
						$group->{id},
					);
					$self->_revoke($membership);
				}
				return 1;
			}

			if (exists $membership->{user}) {
				my ($user) = grep { $_->{id} == $membership->{user}{id} } @$users;
				if ($user) {
					$self->log(sprintf "\tRevoking from user '%s %s' (internal ID %d)",
						Encode::encode_utf8($user->{firstname}),
						Encode::encode_utf8($user->{lastname}),
						$user->{id},
					);
					$self->_revoke($membership);
				}
				return 1;
			}
		}, { _id => $project->{id} });
		$self->log('Project processed');
	}

	return 1;
}

sub _revoke
{
	my $self       = shift;
	
	return 1 if $self->args->{'dry-run'};

	my $membership = shift;

	if (!$self->engine->deleteMembership($membership->{id})) {
		$self->log('Warning: not revoked');
		$self->_log_engine_errors;
		return;
	}

	return 1;
}

1;
