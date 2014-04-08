#/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Getopt::Long;
use Config::IniFiles;

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
	die 'Invalid --id parameter';
}

my $layout = Config::IniFiles->new( -file => $layout_fname );
if (!$layout) {
	warn 'Unable to access layout config';
}

my $redminer = RedMiner::API->new(
	host => $conf->val('redmine', 'host') // '',
#	user => $conf->val('redmine', 'user') // '',
#	pass => $conf->val('redmine', 'pass') // '',
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
				$redminer->updateProjectMembership(
					$project->{project}{id}, $new_membership
				);
			}
		}
	}
}

exit;

#
# Inline wrapper package for RedMine REST API
#

package RedMiner::API;

use LWP::UserAgent;
use JSON::XS qw/encode_json decode_json/;
use Encode   qw/decode/;

sub new
{
	my $class = shift;
	my %arg   = @_;
	
	my $self  = {
		error => '',
		ua    => LWP::UserAgent->new,
	};

	foreach my $param (qw/host user pass key/) {
		$self->{$param} = $arg{$param} // '';
	}

	bless $self, $class;
}

sub error       { $_[0]->{error} }
sub _set_error  { $_[0]->{error} = $_[1] // ''; return; }

sub _set_arg_error
{
	my $self  = shift;
	my $error = shift;

	$self->{raw_response} = '';
	$self->{raw_content}  = '';

	return $self->_set_error($error);
}

sub rawResponse { $_[0]->{raw_response} // '' }
sub rawContent  { $_[0]->{raw_content}  // '' }

sub _request
{
	my $self   = shift;
	my $method = uc(shift // 'GET');
	my $path   = shift // 'issues';
	my $data   = shift // {};

	$self->_set_error;

	my $auth = '';
	if (!length $self->{key} && length $self->{user}) {
		$auth = $self->{user};
		if (length $self->{pass}) {
			$auth .= ':' . $self->{pass};
		}
		$auth .= '@';
	}

	my $uri     = "http://$auth$self->{host}/$path.json";
	my $request = HTTP::Request->new($method, $uri);
	if (length $self->{key}) {
		$request->header('X-Redmine-API-Key' => $self->{key});
	}

	if ($method ne 'GET') {
		my $json = eval { Encode::decode('UTF-8', JSON::XS::encode_json($data)) } // '{}';
		# FIXME: check $@
		$request->header('Content-Type'   => 'application/json');
		$request->header('Content-Length' => length $json);
		$request->content($json);
	}

	return $request;
}

sub _response
{
	my $self     = shift;
	my $response = $self->{ua}->request(shift);

	$self->{raw_response} = $response->as_string;
	$self->{raw_content}  = $response->content;

	if (!$response->is_success) {
		return $self->_set_error($response->status_line);
	}

	return eval {
		JSON::XS::decode_json($response->decoded_content)
	} //  $self->_set_error($@);
}

sub createProject
{
	my $self = shift;
	my $data = shift;
	$self->_response(
		$self->_request('POST', 'projects', { project => $data })
	);
}

sub updateProject
{
	my $self       = shift;
	my $project_id = shift // return $self->_set_arg_error('Incorrect project ID');
	my $data       = shift;
	$self->_response(
		$self->_request('PUT', 'projects/' . $project_id, { project => $data })
	);
}

sub projectMemberships
{
	my $self       = shift;
	my $project_id = shift // return $self->_set_arg_error('Incorrect project ID');
	$self->_response(
		$self->_request('GET', 'projects/' . $project_id . '/memberships')
	);
}

sub updateProjectMembership
{
	my $self       = shift;
	my $project_id = shift // return $self->_set_arg_error('Incorrect project ID');
	my $data       = shift;
	$self->_response(
		$self->_request('POST', 'projects/' . $project_id . '/memberships', { membership => $data })
	);
}

1;
