use strict;
use warnings;
use Test::More tests => 1;

use PomBase::Chobo::ParseOBO;

my $parser = PomBase::Chobo::ParseOBO->new();

my $ontology_data = PomBase::Chobo::OntologyData->new();

$parser->parse(filename => 't/data/mini_chebi.obo',
               ontology_data => $ontology_data);

$parser->parse(filename => 't/data/mini_cl.obo',
               ontology_data => $ontology_data);

# test that CHEBI:33853 merges correctly
is ($ontology_data->get_terms(), 1);
