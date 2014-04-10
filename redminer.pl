#/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Getopt::Long;
use Config::IniFiles;

use RedMiner::API;

my $conf_fname   = 'redminer.conf';
my $layout_fname = 'layout.conf';
my $project_id   = '';
my $project_name = 'ClientName.domain';
my $perm_source  =  0; 

GetOptions(
	'conf=s'        => \$conf_fname,
	'layout=s'      => \$layout_fname,
	'id=s'          => \$project_id,
	'name=s'        => \$project_name,
	'perm-source=s' => \$perm_source,
);

my $conf = Config::IniFiles->new( -file => $conf_fname );
if (!$conf) {
	die 'Unable to access master config';
}

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

my $redminer = RedMiner::API->new(
	host => $conf->val('redmine', 'host') // '',
	user => $conf->val('redmine', 'user') // '',
	pass => $conf->val('redmine', 'pass') // '',
	key  => $conf->val('redmine',  'key') // '',
);

my $description = $layout? $layout->val('project', 'description') // '' : '';
my $project = $redminer->createProject({
	identifier  => $project_id  ,
	name        => $project_name,
	description => $description ,
});
$redminer->updateProject($project->{project}{id}, {
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
		my $subproject = $redminer->createProject($subproject_data);
		$redminer->updateProject($subproject->{project}{id}, {
			parent_id       => $project->{project}{id},
			inherit_members => 1,
		});
	}
}

if ($perm_source) {
	my $memberships = $redminer->projectMemberships($perm_source);
	if ($memberships) {
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
				$redminer->createProjectMembership(
					$project->{project}{id}, $new_membership
				);
			}
		}
	}
}

exit;
