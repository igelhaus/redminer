package RedMiner::API;

use 5.010;
use strict;
use warnings;

our $VERSION = '0.02';

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

=head1 DESCRIPTION

Stub documentation for RedMiner::API, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

=head2 EXPORT

None.

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

sub error        { $_[0]->{error} }
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

	return eval {
		JSON::XS::decode_json($response->decoded_content)
	} // $self->_set_error($@);
}

sub _dispatch_name
{
	my $self = shift;
	my $name = shift // return $self->_set_client_error('Undefined method name');
	my @args = @_;

	my ($action, $objects) = ($name =~ /^(get|read|create|update|delete)?(.+?)$/);
	
	if (!$action || $action eq 'read') {
		$action = 'get';
	}
	if (!$objects) {
		return $self->_set_client_error("Malformed method name '$name'");
	}

	$objects   = ucfirst $objects;
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
				'No data provided for create/update query'
			);
		}
		$data->{content} = pop @args;
	}

	my $i = 0;
	my @objects;
	while ($objects =~ /([A-Z][a-z]+)/g) {
		my $object   = lc $1;
		my $category = $object;
		
		# If an object is singular, pluralize to make its category name: user -> users
		if ($object !~ /s$/) {
			$category .= 's';
		}
		
		push @objects, $category;

		# We need to attach an object ID to the path if an object is singular and
		# we either perform anything but creation or we create a new object inside
		# another object (createProjectMembership)
		if ($object !~ /s$/) {
			if ($action ne 'create' || pos($objects) != length($objects)) {
				my $object_id = $args[$i++];

				return $self->_set_client_error(
					sprintf 'Incorrect object ID for %s in query %s', $object, $name
				) if !defined $object_id || ref \$object_id ne 'SCALAR';

				push @objects, $object_id;
			}
			if (defined $data->{content} && pos($objects) == length($objects)) {
				# Add wrapping object, if necessary:
				if (!exists $data->{content}{$object}) {
					$data->{content} = {
						$object => $data->{content}
					};
				}
			}
		}
	}
	
	$data->{path} = join '/', @objects;

	return $data;
}

=head1 SEE ALSO

RedMine::API: http://search.cpan.org/~celogeek/Redmine-API-0.04/

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
