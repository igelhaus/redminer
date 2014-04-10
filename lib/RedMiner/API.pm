package RedMiner::API;

use 5.010;
use strict;
use warnings;

our $VERSION = '0.04';

use URI;
use URI::QueryParam;
use LWP::UserAgent;
use JSON::XS qw/encode_json decode_json/;
use Encode   qw/decode/;

=pod

=encoding UTF-8

=head1 NAME

RedMiner::API - Wrapper for RedMine REST API (http://www.redmine.org/projects/redmine/wiki/Rest_api).

=head1 SYNOPSIS

	use RedMiner::API;
	my $redminer = RedMiner::API->new(
		host => 'example.com/redmine',
		key  => 'xxx',
	);
	# password-based auth is also supported:
	#my $redminer = RedMiner::API->new(
	#	host => 'example.com/redmine',
	#	user => 'redminer',
	#	pass => 'p@s$w0rD',
	#);

	my $project = $redminer->createProject({
		identifier  => 'my-project',
		name        => 'My Project',
		description => 'My project, created with *RedMiner::API*',
	});
	if (!$project) {
		say STDERR 'Error(s) creating project: ', join("\n", map { $_ } $redminer->errorDetails->{errors});
		exit 1;
	}
	my $project_id = $project->{project}{id};

	$redminer->updateProject($project_id, {
		parent_id       => 42, # Make a project with numeric ID 42  parent for $project_id
		inherit_members => 1,  # Inherit all members and their permissions from the parent
	});
	
	my $issue = $redminer->createIssue({
		project_id  => $project_id,
		subject     => 'Test issue for RedMiner::API',
		description => 'Issue description',
	});

	$redminer->deleteProject($project_id);

=head1 DESCRIPTION

This module provides a thin client for RedMine REST API. Please note that although
RedMine API is designed to support both JSON and XML, this module is B<JSON only>.

=head1 METHODS NAMING AND OTHER CALL CONVENTIONS

All methods are dynamically converted to actual HTTP requests using following conventions.

=head2 Getting a Collection of Objects

	$redminer->projects;     # ->users,     ->issues,     ->timeEntries     ...
	$redminer->getProjects;  # ->getUsers,  ->getIssues,  ->getTimeEntries  ...
	$redminer->readProjects; # ->readUsers, ->readIssues, ->readTimeEntries ...
	
	# Second page when displaying 10 items per page:
	$redminer->projects({ offset => 9, limit => 10 });

	# Filtering issues:
	$redminer->issues({ project_id => 42, assigned_to_id => 'me' });

=head2 Getting an Object

	$redminer->project(1);     # ->user(1),      ->issue(1),     ->timeEntry(1)     ...
	$redminer->getProject(1);  # ->getUser(1),   ->getIssue(1),  ->getTimeEntry(1)  ...
	$redminer->readProject(1); # ->readUsers(1), ->readIssue(1), ->readTimeEntry(1) ...
	
	# Showing anobject with additional metadata:
	$redminer->issue(1, { include => 'relations,changesets' });

=head2 Creating an Object

	$redminer->createProject({
		# ...
	}); # ->createUser, ->createIssue, ->createTimeEntry ...

=head2 Updating an Object

	$redminer->updateProject(1, {
		# ...
	}); # ->updateUser(...), ->updateIssue(...), ->updateTimeEntry(...) ...

=head2 Deleting an Object

	$redminer->deleteProject(1); # ->deleteUser(1), ->deleteIssue(1), ->deleteTimeEntry(1) ...

=head2 Objects Belonging to Other Objects

	#
	# Example for project membership(s)
	#
	my $project_id    = 42;
	my $membership_id = 42;

	# Listing *project* memberships and creating a membership within a *project*
	# require identifying a project and thus have to be spelled like this:
	$redminer->projectMemberships($project_id, { limit => 50 });
	$redminer->createProjectMembership($project_id, { ... });

	# Viewing/Updating/Deleting a membership is performed directly by its ID, thus:
	my $membership = $redminer->membership($membership_id);
	$redminer->updateMembership($membership_id, { ... });
	$redminer->deleteMembership($membership_id);

=head2 Complex Object Names

Such complex names as C<TimeEntry> which should be dispatched to C<time_entries>
are recognized and thus can be spelled in a natural language way (see examples above).
If this is not the case, please report bugs.

=head2 Return Values

All successfull calls return hash references. For C<update*> and C<delete*> calls
hash references are empty.

If a call fails, C<undef> is returned. In this case detailed error information can
be retrieved like this:
	
	if (!$redminer->deleteIssue(42)) {
		my $details = $redminer->errorDetails;
		# Process $details here...
	}

=head1 METHODS

=head2 new

	my $redminer = RedMiner::API->new(%options);

Following options are recognized:

=over

=item *

B<host>: RedMine host. Beside host name, may include port, path and/or URL scheme (C<http> is used by default).

=item *

B<key>: API key. For details, please refer to http://www.redmine.org/projects/redmine/wiki/Rest_api#Authentication

=item *

B<user>, B<pass>: User name and password for password-based authentication

=item *

B<work_as>: User login for impersonation. For details, please refer to http://www.redmine.org/projects/redmine/wiki/Rest_api#User-Impersonation.

=item *

B<no_wrapper_object>: Automatically add/remove wrapper object for data. See below.

=back

=head3 no_wrapper_object

By default RedMine API requires you to wrap you object data like this:

	my $project = $redminer->createProject({
		project => {
			identifier => 'some-id',
			name       => 'Some Name',
		}
	});
	# $project contains something like
	# { project => { id => 42, identifier => 'some-id', name => 'Some Name' ... } }

By default this module follows this convention. However, if you specify something like

	my $redminer = RedMiner::API->new(
		host => 'example.com/redmine',
		key => 'xxx',
		no_wrapper_object => 1,
	);

you can skip "wrapping" object data like this:

	my $project = $redminer->createProject({
		identifier => 'some-id',
		name       => 'Some Name',
	});
	# $project contains something like
	# { id => 42, identifier => 'some-id', name => 'Some Name' ... }

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

	foreach my $param (qw/host user pass key work_as no_wrapper_object/) {
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
	if (length $self->{work_as}) {
		$self->{ua}->default_header('X-Redmine-Switch-User' => $self->{work_as});
	}

	bless $self, $class;
}

=head2 error

Error during the last call. This is an empty string for successfull calls, otherwise
it contains an HTTP status line.

If the call failed before sending an actual request (e.g. method name could not
be dispatched into an HTTP request), contains description of the client error.

=cut

sub error        { $_[0]->{error} }

=head2 errorDetails

Contains detailed error messages from the last call. This is an empty hash reference
for successfull calls, otherwise please see http://www.redmine.org/projects/redmine/wiki/Rest_api#Validation-errors.

If the call failed before sending an actual request (e.g. method name could not
be dispatched into an HTTP request), return value is

	{
		client_error => 1
	}

=cut

sub errorDetails { $_[0]->{error_details} }

sub _set_error   { $_[0]->{error} = $_[1] // ''; return; }

sub _set_client_error
{
	my $self  = shift;
	my $error = shift;

	$self->{error_details} = {
		client_error => 1
	};

	return $self->_set_error($error);
}

sub AUTOLOAD
{
	our $AUTOLOAD;
	my $self   = shift;
	my $method = substr($AUTOLOAD, length(__PACKAGE__) + 2);
	return if $method eq 'DESTROY';
	return $self->_response($self->_request($method, @_));
}

sub _request
{
	my $self = shift;
	my $r    = $self->_dispatch_name(@_) // return;

	$self->_set_error;

	my $uri = URI->new(sprintf('%s/%s.json', $self->{uri}, $r->{path}));
	if ($r->{method} eq 'GET' && ref $r->{query} eq 'HASH') {
		foreach my $param (keys %{ $r->{query} }) {
			# 2DO: implement passing arrays as foo=1&foo=2&foo=3 if needed
			$uri->query_param($param => $r->{query}{$param});
		}
	}

	my $request = HTTP::Request->new($r->{method}, $uri);

	if ($r->{method} ne 'GET' && defined $r->{content}) {
		my $json = eval { Encode::decode('UTF-8', JSON::XS::encode_json($r->{content})) };
		if ($@) {
			return $self->_set_client_error('Malformed input data:' . $@);
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

	if (!$response->is_success) {
		$self->{error_details} = eval {
			JSON::XS::decode_json($response->decoded_content)
		} // {};
		return $self->_set_error($response->status_line);
	}

	$self->{error_details} = {};

	if ($request->method eq 'PUT' || $request->method eq 'DELETE') {
		return {};
	}

	my $content = eval { JSON::XS::decode_json($response->decoded_content) };
	if ($@) {
		return $self->_set_error($@);
	}

	if ($self->{expect_single_object} && $self->{no_wrapper_object}) {
		$content = delete $content->{$self->{expect_single_object}};
	}

	return $content;
}

sub _dispatch_name
{
	my $self = shift;
	my $name = shift // return $self->_set_client_error('Undefined method name');
	my @args = @_;

	my ($action, $objects) = ($name =~ /^(get|read|create|update|delete)?([A-Za-z]+?)$/);
	
	if (!$action || $action eq 'read') {
		$action = 'get';
	}
	if (!$objects) {
		return $self->_set_client_error("Malformed method name '$name'");
	}

	my %METHOD = (
		get    => 'GET'   ,
		create => 'POST'  ,
		update => 'PUT'   ,
		delete => 'DELETE',
	);

	my $data = {
		method  => $METHOD{$action},
		path    =>    '',
		content => undef,
		query   => undef,
	};

	if ($action eq 'get') {
		if (ref $args[-1] eq 'HASH') {
			# If last argument is a hash reference, treat it as a filtering clause:
			$data->{query} = pop @args;
		}
	} elsif ($action eq 'create' || $action eq 'update') {
		# If last argument is an array/hash reference, treat it as a request body:
		if (ref $args[-1] ne 'ARRAY' && ref $args[-1] ne 'HASH') {
			return $self->_set_client_error(
				'No data provided for a create/update method'
			);
		}
		$data->{content} = pop @args;
	}

	$objects = $self->_normalize_objects($objects);
	delete $self->{expect_single_object};

	my $i = 0;
	my @objects;
	while ($objects =~ /([A-Z][a-z]+)/g) {
		my $object   = $self->_object($1);
		my $category = $self->_category($object);
		
		push @objects, $category;

		next if $object eq $category;

		# We need to attach an object ID to the path if an object is singular and
		# we either perform anything but creation or we create a new object inside
		# another object (createProjectMembership)
		if ($action ne 'create' || pos($objects) != length($objects)) {
			my $object_id = $args[$i++];

			return $self->_set_client_error(
				sprintf 'Incorrect object ID for %s in query %s', $object, $name
			) if !defined $object_id || ref \$object_id ne 'SCALAR';

			push @objects, $object_id;
		}

		if (pos($objects) == length($objects)) { # Last object in the chain:
			if ($action eq 'get' || $action eq 'create') {
				$self->{expect_single_object} = $object;
			}
			if (defined $data->{content} && $self->{no_wrapper_object}) {
				# Automatically wrap object data, otherwise we pass everything as is:
				$data->{content} = {
					$object => $data->{content}
				};
			}
		}
	}
	
	$data->{path} = join '/', @objects;

	return $data;
}

sub _normalize_objects
{
	my $self    = shift;
	my $objects = shift;

	$objects = ucfirst $objects;
	# These are token that for a *single* entry in the resulting request path,
	# e.g.: PUT /time_entries/1.json
	# But it is natural to spell them like this:
	# $api->updateTimeEntry(1, { ... });
	$objects =~ s/TimeEntr/Timeentr/g;
	$objects =~ s/IssueCategor/Issuecategor/g;
	$objects =~ s/IssueStatus/Issuestatus/g;
	$objects =~ s/CustomField/Customfield/g;

	return $objects;
}

sub _object
{
	my $self   = shift;
	my $object = lc(shift);
	
	# Process compound words:
	$object =~ s/timeentr/time_entr/ig;
	$object =~ s/issue(categor|status)/issue_$1/ig;
	$object =~ s/customfield/custom_field/ig;
	
	return $object;
}

# If an object is singular, pluralize to make its category name: user -> users
sub _category
{
	my $self   = shift;
	my $object = shift;

	my $category = $object;

	if ($category !~ /s$/ || $category =~ /us$/) {
		if ($object =~ /y$/) {
			$category =~ s/y$/ies/;
		} elsif ($category =~ /us$/) {
			$category .= 'es';
		} else {
			$category .= 's';
		}
	}

	return $category;
}

=head1 SEE ALSO

Redmine::API (https://metacpan.org/pod/Redmine::API). Major differences
between this module and Redmine::API are:

=over

=item *

B<Dependencies>. Redmine::API depends on Moo and REST::Client which in turn depends on
LWP::UserAgent, URI and possibly others. RedMiner::API uses pure Perl OOP and
depends directly on LWP::UserAgent and URI.

=item *

B<Call conventions>. Although both modules use dynamic dispatching for building actual HTTP
requests, they do it in a different manner. In particular, RedMiner::API tries to
dispatch a single method name without using chains of interrim objects as Redmine::API does.
	
=back

=head1 AUTHOR

Anton Soldatov, E<lt>igelhaus@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Anton Soldatov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;

__END__
