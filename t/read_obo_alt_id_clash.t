use strict;
use warnings;
use Test::More tests => 1;
use Test::Deep;
use Try::Tiny;

use PomBase::Chobo::ParseOBO;

my $parser = PomBase::Chobo::ParseOBO->new();

my $ontology_data = PomBase::Chobo::OntologyData->new();

$parser->parse(filename => 't/data/mini_test_fypo.obo',
               ontology_data => $ontology_data);
try {
  $parser->parse(filename => 't/data/bogus_alt_id_fypo.obo',
                 ontology_data => $ontology_data);
  fail("this should fail because of two terms with the same ID (one id and one alt_id");
} catch {
  my $error = $_;
  ok ($error =~ /is the ID of:/);
}
