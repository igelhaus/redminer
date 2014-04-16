package Redminer::Command;

use 5.010;
use strict;
use warnings;

sub _args_spec { [ 'id=s', 'name=s', 'layout=s', ] }

sub _args_defaults
{
	{
		name   => 'ClientName.domain',
		layout => $ENV{HOME} . '/.redminer/create-project/layout.conf',
	}
}

sub run
{
	my $self = shift;
	my $args = $self->args;
	
	my $project_id   = $args->{id};
	my $project_name = $args->{name};
	my $layout_fname = $args->{layout};

	if (!$project_id) {
		if ($project_name =~ /^[a-z.\-]+$/i) {
			$project_id = $project_name;
			$project_id =~ s/\./-/g;
		} else {
			die 'Invalid --id parameter';
		}
	}

	my $layout = Config::IniFiles->new( -file => $layout_fname );
	if (!$layout) {
		warn 'Unable to access layout config';
	}

	my $description = $layout? $layout->val('project', 'description') // '' : '';

	say 'Creating a new project ' . $project_name;

	my $project = $self->engine->createProject({
		identifier  => $project_id  ,
		name        => $project_name,
		description => $description ,
	});

	if (!$project) {
		say STDERR 'Project was not created';
	#	say STDERR render_errors($self->engine->errorDetails);
		exit 255;
	}

	my $pid = $project->{id};
	say 'Project created with ID ' . $pid;

	$self->engine->updateProject($pid, {
		inherit_members => 1,
	});

	if ($layout) {
		my @sections = $layout->Sections;
		foreach my $section (@sections) {
			next if $section !~ /^subproject(-.+)$/;
			my $subproject_data = {
				identifier  => $project_id . $1,
				name        => $project_name  . ': ' . ($layout->val($section, 'name_suffix') // 'Subproject'),
				description => $layout->val($section, 'description') // '',
			};

			say 'Creating a new subproject ' . $subproject_data->{name};

			my $subproject = $self->engine->createProject($subproject_data);
			if (!$subproject) {
				say STDERR 'Subproject was not created';
	#			say STDERR render_errors($self->engine->errorDetails);
				next;
			}

			say 'Subproject created with ID ' . $subproject->{id};
			$self->engine->updateProject($subproject->{id}, {
				parent_id       => $pid,
				inherit_members => 1,
			});
		}
	}

	# FIXME: handle limit/offset issue
	my $perm_source = $layout? $layout->val('project', 'perm_source') : 0;
	if ($perm_source) {
		my $memberships = $self->engine->projectMemberships($perm_source);
		if ($memberships) {
			say 'Copying project permissions from a template project...';
			foreach my $membership (@{ $memberships->{memberships} }) {
				my $type = '';
				if (exists $membership->{group}) {
					$type = 'group';
				} elsif (exists $membership->{user}) {
					$type = 'user';
				}
				next if !length $type;

				my $new_membership = {
					user_id  => $membership->{$type}{id},
					role_ids => [],
				};
				for my $role (@{$membership->{roles}}) {
					next if $role->{inherited};
					push @{ $new_membership->{role_ids} }, $role->{id};
				}
				if ($new_membership->{user_id} && @{ $new_membership->{role_ids} }) {
					$self->engine->createProjectMembership($pid, $new_membership);
				}
			}
			say 'Permissions copied';
		}
	}
}

1;
