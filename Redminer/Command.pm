package Redminer::Command;

use 5.010;
use Mouse;
use Getopt::Long;

has engine => (
	is       => 'ro',
	isa      => 'WebService::Redmine',
	required => 1,
);

has args => (
	is       => 'ro',
	isa      => 'HashRef',
	required => 1,
	builder  => '_args',
);

around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;

	my $_command = shift(@ARGV) // '';

	if (!length $_command) {
		die 'Empty command is not allowed';
	}

	my $command = ucfirst $_command;
	$command    =~ s/-([a-z])/uc $1/eg;

	eval "use Redminer::Command::$command";
	if ($@) {
		die "$_command is not implemented";
	}

	return $class->$orig(@_);
};

sub _args
{
	my $self = shift;
	my %args;

	GetOptions(\%args, @{ $self->_args_spec });

	my $defaults = $self->_args_defaults;
	foreach my $arg (keys %$defaults) {
		next if defined $args{$arg} || !defined $defaults->{$arg};
		$args{$arg} = $defaults->{$arg};
	}

	return \%args;
}

1;
