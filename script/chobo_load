#!/usr/bin/env perl

use Mouse;
use Try::Tiny;

use Getopt::Long qw(:config pass_through);
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
  $0 [-d] connect_string username password filename(s)
or:
  $0 -h

  -d  Dry run - rollback at the end of loading
  -h  Show this help message

USAGE
}

my $dry_run = 0;
my $do_help = 0;

if (!GetOptions("dry-run|d" => \$dry_run,
                "help|h" => \$do_help)) {
  usage();
}

if ($do_help) {
  usage();
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
    warn "reading: $filename\n";
    $chobo->read_obo(filename => $filename);
  }

  $chobo->chado_store();

  if ($dry_run) {
    warn "dry run - rolling back\n";
    $dbh->rollback();
  } else {
    warn "commiting\n";
    $dbh->commit() or die $dbh->errstr;
  }
} catch {
  warn "failed - rolling back: $_\n";
  $dbh->rollback() or die $dbh->errstr;
};
