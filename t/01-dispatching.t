use strict;
use warnings;

use Test::More;

BEGIN { use_ok('RedMiner::API') };

#
# Tests for internal dispatching mechanizm
#

my $redminer = RedMiner::API->new(
	host => '',
	key  => ''
);

my $r;

$r = $redminer->_dispatch_name;
ok(!defined $r, 'Must fail: undefined name');

$r = $redminer->_dispatch_name('read');
ok(!defined $r, 'Must fail: malformed name, no objects given');

$r = $redminer->_dispatch_name('readproject2');
ok(!defined $r, 'Must fail: malformed name, inappropriate object naming');

$r = $redminer->_dispatch_name('project', { id => 1 });
ok(!defined $r, 'Must fail: malformed object ID');

$r = $redminer->_dispatch_name('createProject');
ok(!defined $r, 'Must fail: malformed name, missing data argument for a create/update method');

$r = $redminer->_dispatch_name('updateProject', 1);
ok(!defined $r, 'Must fail: malformed name, missing data argument for a create/update method');

$r = $redminer->_dispatch_name('createProject', 1, 'scalar');
ok(!defined $r, 'Must fail: malformed name, inappropriate data type for a create/update method');

$r = $redminer->_dispatch_name('updateProject', 1, 'scalar');
ok(!defined $r, 'Must fail: malformed name, inappropriate data type for a create/update method');

#
# Testing basic CRUD API:
# * List existing objects (possibly with extra metadata)s
# * Read an object (possibly with extra metadata)
# * Create a new object
# * Update an existing object
# * Delete an existing object
#

$r = $redminer->_dispatch_name('projects', { limit => 10, offset => 9 });
is_deeply($r, {
	method => 'GET',
	path   => 'projects',
	content => undef,
	query   => { limit => 10, offset => 9 },
}, 'projects');

# ditto
$r = $redminer->_dispatch_name('Projects', { limit => 10, offset => 9 });
is_deeply($r, {
	method => 'GET',
	path   => 'projects',
	content => undef,
	query   => { limit => 10, offset => 9 },
}, 'projects');

# ditto
$r = $redminer->_dispatch_name('getProjects', { limit => 10, offset => 9 });
is_deeply($r, {
	method => 'GET',
	path   => 'projects',
	content => undef,
	query   => { limit => 10, offset => 9 },
}, 'projects');

# ditto
$r = $redminer->_dispatch_name('getprojects', { limit => 10, offset => 9 });
is_deeply($r, {
	method => 'GET',
	path   => 'projects',
	content => undef,
	query   => { limit => 10, offset => 9 },
}, 'projects');

# ditto
$r = $redminer->_dispatch_name('readProjects', { limit => 10, offset => 9 });
is_deeply($r, {
	method => 'GET',
	path   => 'projects',
	content => undef,
	query   => { limit => 10, offset => 9 },
}, 'projects');

# ditto
$r = $redminer->_dispatch_name('readprojects', { limit => 10, offset => 9 });
is_deeply($r, {
	method => 'GET',
	path   => 'projects',
	content => undef,
	query   => { limit => 10, offset => 9 },
}, 'projects');

$r = $redminer->_dispatch_name('project', 1);
is_deeply($r, {
	method => 'GET',
	path   => 'projects/1',
	content => undef,
	query   => undef,
}, 'project');

$r = $redminer->_dispatch_name('createProject', { name => 'My Project' });
is_deeply($r, {
	method => 'POST',
	path   => 'projects',
	content => { project => { name => 'My Project' } },
	query   => undef,
}, 'createProject');

$r = $redminer->_dispatch_name('updateProject', 1, { name => 'My Project' });
is_deeply($r, {
	method => 'PUT',
	path   => 'projects/1',
	content => { project => { name => 'My Project' } },
	query   => undef,
}, 'updateProject');

$r = $redminer->_dispatch_name('deleteProject', 1);
is_deeply($r, {
	method => 'DELETE',
	path   => 'projects/1',
	content => undef,
	query   => undef,
}, 'deleteProject');

#
# Dispatching methods with more than 1 identifying object:
#

$r = $redminer->_dispatch_name('projectMemberships', 1, { limit => 10, offset => 9 });
is_deeply($r, {
	method => 'GET',
	path   => 'projects/1/memberships',
	content => undef,
	query   => { limit => 10, offset => 9 },
}, 'projectMemberships');

$r = $redminer->_dispatch_name('createProjectMembership', 1, { user_id => 1, role_ids => [ 1 ] });
is_deeply($r, {
	method => 'POST',
	path   => 'projects/1/memberships',
	content => { membership => { user_id => 1, role_ids => [ 1 ] } },
	query   => undef,
}, 'createProjectMembership');

done_testing;

exit;
