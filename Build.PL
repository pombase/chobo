use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'PomBase::Chobo',
    license             => 'perl',
    dist_author         => q{Kim Rutherford <kmr@pombase.org>},
    dist_version_from   => 'lib/PomBase/Chobo.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
        'Text::CSV_XS' => 0,
        'DBI' => 0,
        'DBD::Pg' => 0,
        'Clone' => 0,
        'String::Strip' => 0,
        'Try::Tiny' => 0,
        'Data::Compare' => 0,
        'List::Compare' => 0,
        'Mouse' => 0,
        'use Capture::Tiny' => 0,
    },
    add_to_cleanup      => [ 'PomBase-Chobo-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
