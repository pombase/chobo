use strict;
use warnings;
use Test::More tests => 6;
use Test::Deep;

use lib qw(t/lib);

use PomBase::Chobo::OntologyData;
use PomBase::Chobo;
use ChoboTest::FakeHandle;

my $ontology_data = PomBase::Chobo::OntologyData->new();
my $fake_handle = ChoboTest::FakeHandle->new();

my $chobo = PomBase::Chobo->new(dbh => $fake_handle, ontology_data => $ontology_data);

is($ontology_data->get_terms(), 0);

$chobo->read_obo(filename => 't/data/mini_go.obo');

$chobo->chado_store();

is($ontology_data->get_terms(), 2);

my $cyanidin_name =
  qq|cyanidin 3-O-glucoside-(2"-O-xyloside) 6''-O-acyltransferase activity|;

cmp_deeply([
  sort {
    $a->{id} cmp $b->{id};
  } map {
    { name => $_->{name}, id => $_->{id} }
  } $ontology_data->get_terms()],
           [{ name => 'molecular_function', id => 'GO:0003674' },
            { name => $cyanidin_name, id => 'GO:0102583' }]);



my $sth = $fake_handle->prepare("select cvterm_id, name, cv_id from cvterm");
$sth->execute();

my $row_1 = $sth->fetchrow_hashref();
is($row_1->{name}, 'is_a');

my $row_2 = $sth->fetchrow_hashref();
is($row_2->{name}, 'molecular_function');

my $row_3 = $sth->fetchrow_hashref();
is($row_3->{name}, $cyanidin_name);

