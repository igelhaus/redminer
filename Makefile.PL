use 5.010;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME           => 'Redminer',
	VERSION_FROM   => 'lib/Redminer.pm',
	BUILD_REQUIRES => {
		'ExtUtils::MakeMaker' => 0,
		'Test::More'          => 0,
		'Test::Pod'           => '1.00',
		'Test::Pod::Coverage' => 0,
	},
	PREREQ_PM => {
		'URI'             => 0,
		'URI::QueryParam' => 0,
		'LWP::UserAgent'  => 0,
		'JSON::XS'        => 0,
	},
	($] >= 5.005 ? ( ## Add these new keywords supported since 5.005
		ABSTRACT_FROM => 'lib/Redminer.pm',
		AUTHOR        => 'Anton Soldatov <igelhaus@gmail.com>')
	: ()),
);
