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

sub _run
{
	my $self = shift;
	my $args = $self->args;
	
	my $project_id   = $args->{id};
	my $project_name = $args->{name};
	my $layout_fname = $args->{layout};

	if (!$project_id) {
		if ($project_name =~ /^[a-z.\-]+$/i) {
			$project_id = lc $project_name;
			$project_id =~ s/\./-/g;
			$self->log("Project ID '$project_id' derived from name '$project_name'");
		} else {
			$self->log('Invalid --id parameter');
			return;
		}
	}

	my $layout = Config::IniFiles->new(-file => $layout_fname);
	if (!$layout) {
		$self->log('Unable to access create-project layout config');
	}

	my $description = $layout? $layout->val('project', 'description') // '' : '';
	my $is_public   = $layout? $layout->val('project',   'is_public') //  0 : '';

	$self->log('Creating a new project ' . $project_name);

	my $project = $self->engine->createProject({
		identifier  => $project_id  ,
		name        => $project_name,
		description => $description ,
	});

	if (!$project) {
		$self->log('Project was not created');
		return;
	}

	my $pid = $project->{id};
	$self->log('Project created with ID ' . $pid);
	$self->engine->updateProject($pid, {
		inherit_members => 1,
		is_public       => $is_public,
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

			$self->log('Creating a new subproject ' . $subproject_data->{name});

			my $subproject = $self->engine->createProject($subproject_data);
			if (!$subproject) {
				$self->log('Project was not created');
				$self->_log_engine_errors;
				next;
			}

			$self->log('Subproject created with ID ' . $subproject->{id});
			$self->engine->updateProject($subproject->{id}, {
				parent_id       => $pid,
				inherit_members => 1,
				is_public       => $is_public,
			});
		}
	}
	
	my $perm_source = $layout? $layout->val('project', 'perm_source') : 0;
	return 1 if !$perm_source;

	my $membership_source = $self->engine->project($perm_source);
	return 1 if !$membership_source;

	$self->log(sprintf
		'Copying project permissions from a template project \'%s\' (internal ID %d)...',
		Encode::encode_utf8($membership_source->{name}),
		$membership_source->{id},
	);

	$self->iterate('projectMemberships', sub {
		my $membership = shift;
		my $type = '';
		if (exists $membership->{group}) {
			$type = 'group';
		} elsif (exists $membership->{user}) {
			$type = 'user';
		}
		return if !length $type;

		my $new_membership = {
			user_id  => $membership->{$type}{id},
			role_ids => [],
		};
		foreach my $role (@{$membership->{roles}}) {
			next if $role->{inherited};
			push @{ $new_membership->{role_ids} }, $role->{id};
		}

		if ($new_membership->{user_id} && @{ $new_membership->{role_ids} }) {
			$self->engine->createProjectMembership($pid, $new_membership);
		}
	}, { _id => $perm_source });

	$self->log('Permissions copied');
	return 1;
}

1;
