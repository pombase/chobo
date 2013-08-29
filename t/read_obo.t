use strict;
use warnings;
use Test::More tests => 10;
use Test::Deep;

use PomBase::Chobo::ParseOBO;

my $parser = PomBase::Chobo::ParseOBO->new();

my $res = $parser->parse(filename => 't/data/mini_test_fypo.obo');

is (@{$res->terms()}, 14);
is (@{$res->relations()}, 3);

my $lookup_name = 'elongated multinucleate cells';
my $lookup_id = 'FYPO:0000133';

my $fypo_0000133 = $res->term_by_name($lookup_name);

is ($fypo_0000133->name(), $lookup_name);
is ($fypo_0000133->id(), $lookup_id);

$fypo_0000133 = $res->term_by_id($lookup_id);

is ($fypo_0000133->name(), $lookup_name);
is ($fypo_0000133->id(), $lookup_id);

is (keys %{$res->metadata()}, 3);

is ($res->metadata()->{ontology}, 'fypo');

my @cv_names = sort $res->get_cv_names();

cmp_deeply(\@cv_names, ['external_cv', 'fission_yeast_phenotype']);

my @fypo_cvterms = $res->get_terms_by_cv_name('fission_yeast_phenotype');

is (@fypo_cvterms, 13);
