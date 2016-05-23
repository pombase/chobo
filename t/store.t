use strict;
use warnings;
use Test::More tests => 9;
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



my $sth = $fake_handle->prepare("select cvterm_id, name, cv_id from cvterm order by name");
$sth->execute();

my $cyanidin_term = $sth->fetchrow_hashref();
is ($cyanidin_term->{name}, $cyanidin_name);
my $is_a_term = $sth->fetchrow_hashref();
is ($is_a_term->{name}, 'is_a');
my $molecular_function_term = $sth->fetchrow_hashref();
is ($molecular_function_term->{name}, 'molecular_function');


$sth = $fake_handle->prepare("select subject_id, type_id, object_id from cvterm_relationship order by subject_id");
$sth->execute();

my $rel = $sth->fetchrow_hashref();

is ($rel->{subject_id}, $cyanidin_term->{cvterm_id});
is ($rel->{type_id}, $is_a_term->{cvterm_id});
is ($rel->{object_id}, $molecular_function_term->{cvterm_id});


