package RedMiner::API;

use 5.014004;
use strict;
use warnings;

our $VERSION = '0.01';

# 2DO: fully implement project API
# 2DO: fully implement issues API
# 2DO: fully implement membership API

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

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Anton Soldatov, E<lt>anton@localE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Anton Soldatov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.4 or,
at your option, any later version of Perl 5 you may have available.


=cut

1;

__END__

=head1 NAME

RedMiner::API - Perl extension for blah blah blah

=head1 SYNOPSIS

  use RedMiner::API;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for RedMiner::API, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Anton Soldatov, E<lt>anton@localE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Anton Soldatov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
