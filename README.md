# redminer

Automating routine [RedMine](http://www.redmine.org) tasks with Perl 5.10+.

Currently the project consists of two parts:

1. `redminer` script itself. For now it supports only creating projects with subprojects
from a given layout, but in the future it's aimed for various RedMine automation tasks
2. `RedMiner::API` module, a Perl binding to [RedMine REST API](http://www.redmine.org/projects/redmine/wiki/Rest_api).
Please refer to [built-in POD documentation](../master/lib/RedMiner/API.pm) for more details

## Non-core Dependencies

1. [LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent)
2. [URI](https://metacpan.org/pod/URI)
3. [URI::QueryParam](https://metacpan.org/pod/URI::QueryParam)
4. [JSON::XS](https://metacpan.org/pod/JSON::XS)
5. [Config::IniFiles](https://metacpan.org/pod/Config::IniFiles) (`redminer` only)
