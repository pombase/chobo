#!/usr/bin/env perl

use Mouse;
use Try::Tiny;

use DBI;

use PomBase::Chobo;

sub usage
{
  die "usage:
$0 connect_string username password filename\n";
}

if (@ARGV != 4) {
  warn "$0: needs four arguments\n";
  usage
}

my ($connect_str, $user, $pass, $filename) = @ARGV;

my $dbh = DBI->connect($connect_str, $user, $pass,
                       { AutoCommit => 0, PrintError => 0 })
  or die "Cannot connect using $: $DBI::errstr\n";

my $chobo = PomBase::Chobo->new(dbh => $dbh);

try {
  $chobo->process(filename => $filename);
  warn "commiting\n";
  $dbh->commit();
} catch {
  warn "failed - rolling back: $_\n";
  $dbh->rollback();
};
