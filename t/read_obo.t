use strict;
use warnings;
use Test::More tests => 13;
use Test::Deep;

use PomBase::Chobo::ParseOBO;

my $parser = PomBase::Chobo::ParseOBO->new();

my $ontology_data = PomBase::Chobo::OntologyData->new();

$parser->parse(filename => 't/data/mini_test_fypo.obo',
               ontology_data => $ontology_data);

is ($ontology_data->get_terms(), 17);

my $lookup_name = 'elongated multinucleate cells';
my $lookup_id = 'FYPO:0000133';

my $fypo_0000133 = $ontology_data->term_by_name($lookup_name);

is ($fypo_0000133->name(), $lookup_name);
is ($fypo_0000133->id(), $lookup_id);

$fypo_0000133 = $ontology_data->term_by_id($lookup_id);

is ($fypo_0000133->name(), $lookup_name);
is ($fypo_0000133->id(), $lookup_id);

is ($ontology_data->get_namespaces(), 2);

is ($ontology_data->get_metadata_by_namespace("fission_yeast_phenotype")->{ontology}, 'fypo');

my @cv_names = sort $ontology_data->get_cv_names();

cmp_deeply(\@cv_names, ['external_cv', 'fission_yeast_phenotype']);

my @db_names = sort $ontology_data->get_db_names();

cmp_deeply(\@db_names, ['EXT', 'FYPO', 'fission_yeast_phenotype']);

my @fypo_cvterms = $ontology_data->get_terms_by_cv_name('fission_yeast_phenotype');

is (@fypo_cvterms, 16);

my @fypo_relationships = grep { $_->is_relationshiptype(); } @fypo_cvterms;
is (@fypo_relationships, 3);

my @fypo_non_relationships = grep { !$_->is_relationshiptype(); } @fypo_cvterms;
is (@fypo_non_relationships, 13);


my $single_term_ontology_data = PomBase::Chobo::OntologyData->new();

$parser->parse(filename => 't/data/single_term.obo',
               ontology_data => $single_term_ontology_data);
$parser->parse(filename => 't/data/single_term.obo',
               ontology_data => $single_term_ontology_data);

is ($single_term_ontology_data->get_terms(), 1);
