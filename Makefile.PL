use 5.010;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME         => 'RedMiner::API',
	VERSION_FROM => 'lib/RedMiner/API.pm',
	PREREQ_PM    => {
		'URI'             => 0,
		'URI::QueryParam' => 0,
		'LWP::UserAgent'  => 0,
		'JSON::XS'        => 0,
	},
	($] >= 5.005 ? ( ## Add these new keywords supported since 5.005
		ABSTRACT_FROM => 'lib/RedMiner/API.pm',
		AUTHOR        => 'Anton Soldatov <igelhaus@gmail.com>')
	: ()),
);
