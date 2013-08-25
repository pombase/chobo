use strict;
use warnings;
use Test::More tests => 6;

use PomBase::Chobo::ParseOBO;

my $parser = PomBase::Chobo::ParseOBO->new();

my $res = $parser->parse(filename => 't/data/mini_test_fypo.obo');

is (@{$res->terms()}, 13);
is (@{$res->relations()}, 3);

my $lookup_name = 'elongated multinucleate cells';

my $fypo_0000133 = $res->term_by_name($lookup_name);

is ($fypo_0000133->name(), $lookup_name);
is ($fypo_0000133->id(), "FYPO:0000133");

is (keys %{$res->metadata()}, 7);

is ($res->metadata()->{ontology}, 'fypo');
