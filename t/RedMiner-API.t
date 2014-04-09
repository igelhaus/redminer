use strict;
use warnings;

use Test::More tests => 1;

BEGIN { use_ok('RedMiner::API') };

my $host = '';
my $key  = '';
my $key_fname = $ENV{HOME} . '/.redminer/key';
if (-e $key_fname) {
	open my $FH_key, '<', $key_fname;
	my $key_data  = <$FH_key>;
	($host, $key) = split /\s*;\s*/, $key_data;
	chomp $key_data;
	close $FH_key;
}

my $redminer = RedMiner::API->new(
	host => $host,
	key  => $key,
);

my $response = $redminer->createProject({
	identifier => 'test-ru',
	name       => 'test.ru',
});

use JSON::XS qw/encode_json/;
if ($response) {
	say STDERR JSON::XS::encode_json($response);
} else {
	say STDERR JSON::XS::encode_json($redminer->errorDetails);
}

#SKIP: {
#	skip 'Development tests skipped', 2 if !$ENV{REDMINER_API_DEVEL};
#}

exit;
