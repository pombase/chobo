use strict;
use warnings;
use Test::More tests => 4;
use Test::Deep;

use PomBase::Chobo::OntologyTerm;

my $term = {
  id => "GO:0006810",
  name => "transport",
  namespace => "biological_process",
  alt_id => ["GO:0015457", "GO:0015460"],
  synonym => [
    {
      synonym => "auxiliary transport protein activity",
      scope => "RELATED",
      dbxrefs => ["GOC:mah", "XDB:1234"],
    },
    {
      synonym => "small molecule transport",
      scope => "NARROW",
      dbxrefs => [],
    }
  ],
};

PomBase::Chobo::OntologyTerm::bless_object($term);

is (ref $term, "PomBase::Chobo::OntologyTerm");

is ($term->id(), "GO:0006810");
is ($term->name(), "transport");

is ($term->to_string(),
"[Term]
id: GO:0006810
name: transport
alt_id: GO:0015457
alt_id: GO:0015460
namespace: biological_process
synonym: auxiliary transport protein activity RELATED [GOC:mah, XDB:1234]
synonym: small molecule transport NARROW []");
