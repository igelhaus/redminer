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

# 2DO: fully implement project API
# 2DO: fully implement issues API
# 2DO: fully implement membership API

use 5.010;
use strict;
use warnings;

use LWP::UserAgent;
use JSON::XS qw/encode_json decode_json/;
use Encode   qw/decode/;

=pod

=encoding UTF-8

=head1 RedMiner::API

Wrapper package for RedMine REST API (http://www.redmine.org/projects/redmine/wiki/Rest_api).

=cut

sub new
{
	my $class = shift;
	my %arg   = @_;
	
	my $self  = {
		error    => '',
		protocol => $arg{protocol} // 'http',
		ua       => LWP::UserAgent->new,
	};

	foreach my $param (qw/host user pass key/) {
		$self->{$param} = $arg{$param} // '';
	}

	if (length $self->{host} && $self->{host} =~ m|^(https?)://|i) {
		$self->{protocol} = lc $1;
		$self->{host}     =~ s/^https?://i;
	} else {
		$self->{protocol} = 'http' if $self->{protocol} !~ /^https?$/i;
	}

	my $auth = '';
	if (!length $self->{key} && length $self->{user}) {
		$auth = $self->{user};
		if (length $self->{pass}) {
			$auth .= ':' . $self->{pass};
		}
		$auth .= '@';
	}
	$self->{uri} = "$self->{protocol}://$auth$self->{host}";

	$self->{ua}->default_header('Content-Type' => 'application/json');
	
	if (length $self->{key}) {
		$self->{ua}->default_header('X-Redmine-API-Key' => $self->{key});
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
	my $method = shift // return $self->_set_arg_error('Request method missing');
	my $path   = shift // return $self->_set_arg_error('Request path missing');
	my $data   = shift;

	if ($method !~ /^(?:GET|POST|PUT|DELETE)$/) {
		$method = 'GET';
	}

	$self->_set_error;

	my $request = HTTP::Request->new(
		$method, sprintf('%s/%s.json', $self->{uri}, $path)
	);

	if ($method ne 'GET' && defined $data) {
		my $json = eval { Encode::decode('UTF-8', JSON::XS::encode_json($data)) };
		if ($@) {
			return $self->_set_arg_error('Malformed input data:' . $@);
		}
		$request->header('Content-Length' => length $json);
		$request->content($json);
	}

	return $request;
}

sub _response
{
	my $self     = shift;
	my $request  = shift // return;
	my $response = $self->{ua}->request($request);

	$self->{raw_response} = $response->as_string;
	$self->{raw_content}  = $response->content;

	if (!$response->is_success) {
		# FIXME: decode into error object
		return $self->_set_error($response->status_line);
	}

	return eval {
		JSON::XS::decode_json($response->decoded_content)
	} // $self->_set_error($@);
}

sub createProject
{
	my $self = shift;
	my $data = shift;
	$self->_response(
		$self->_request('POST', 'projects', { project => $data })
	);
}

# TESTME
sub project
{
	my $self       = shift;
	my $project_id = shift // return $self->_set_arg_error('Incorrect project ID');
	$self->_response(
		$self->_request('GET', 'projects/' . $project_id)
	);
}

# FIXME: implement handling of limit+offset+total_count parameters
# TESTME
sub projects
{
	my $self = shift;
	$self->_response(
		$self->_request('GET', 'projects')
	);
}

# Undocumented: parent_id, inherit_members
sub updateProject
{
	my $self       = shift;
	my $project_id = shift // return $self->_set_arg_error('Incorrect project ID');
	my $data       = shift;
	$self->_response(
		$self->_request('PUT', 'projects/' . $project_id, { project => $data })
	);
}

# TESTME
sub deleteProject
{
	my $self       = shift;
	my $project_id = shift // return $self->_set_arg_error('Incorrect project ID');
	$self->_response(
		$self->_request('DELETE', 'projects/' . $project_id)
	);
}

# FIXME: implement handling of limit+offset+total_count parameters
sub projectMemberships
{
	my $self       = shift;
	my $project_id = shift // return $self->_set_arg_error('Incorrect project ID');
	$self->_response(
		$self->_request('GET', 'projects/' . $project_id . '/memberships')
	);
}

# FIXME: set*, not update*
# Setting membership for a group: group_id
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
