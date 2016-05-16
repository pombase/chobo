#!/usr/bin/env perl

use Mouse;
use Try::Tiny;

use lib qw(lib);

use DBI;

use PomBase::Chobo;

sub usage
{
  my $message = shift;

  if (defined $message) {
    warn "$message\n";
  }

  die <<"USAGE";
usage:
$0 [-P|-p] connect_string username password filename(s)

  -c  As well as loading the ontologies into the cvterm table, run
      owltools to get the inferred relations / transitive closure
      and then load that into the cvtermpath table.
  -C  Don't load the ontologies, just populate the cvtermpath table from
      OBO files.  If there are terms in the OBO file that aren't in the
      cvterm table, this will fail.
USAGE
}

my $load_terms = 1;
my $load_closure = 0;

if (@ARGV && $ARGV[0] =~ /^-/) {
  if ($ARGV[0] eq '-c') {
    $load_closure = 1;
  } else {
    if ($ARGV[0] eq '-C') {
      $load_closure = 1;
      $load_terms = 0;
    } else {
      usage "unknown option: $ARGV[0]";
    }
  }
}

if (@ARGV < 4) {
  warn "$0: needs four or more arguments\n";
  usage;
}

my ($connect_str, $user, $pass, @filenames) = @ARGV;

my $dbh = DBI->connect($connect_str, $user, $pass,
                       { AutoCommit => 0, PrintError => 0 })
  or die "Cannot connect using $: $DBI::errstr\n";

my $ontology_data = PomBase::Chobo::OntologyData->new();

my $chobo = PomBase::Chobo->new(dbh => $dbh, ontology_data => $ontology_data);

try {
  for my $filename (@filenames) {
    $chobo->read_obo(filename => $filename);
  }
  $ontology_data->finish();
  $chobo->chado_store();
  warn "commiting\n";
  $dbh->commit() or die $dbh->errstr;
} catch {
  warn "failed - rolling back: $_\n";
  $dbh->rollback() or die $dbh->errstr;
};
