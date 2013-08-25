use strict;
use warnings;
use Test::More tests => 1;

use PomBase::Chobo::ParseOBO;

my $parser = PomBase::Chobo::ParseOBO->new();

my $res = $parser->parse(filename => 't/data/mini_test_fypo.obo');

is (@{$res->{terms}}, 15);

