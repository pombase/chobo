package PomBase::Chobo;

use 5.006;
use strict;
use warnings;

=head1 NAME

PomBase::Chobo - The great new PomBase::Chobo!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomBase::Chobo


You can also look for information at:

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Kim Rutherford.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

use Moose;
use Text::CSV;

use PomBase::Chobo::ParseOBO;
use PomBase::Chobo::ChadoData;

has dbh => (is => 'ro');

has new_terms => (is => 'rw', init_arg => undef);
has new_synonyms => (is => 'rw', init_arg => undef);
has remove_synonyms => (is => 'rw', init_arg => undef);

sub process
{
  my $self = shift;
  my %args = @_;

  my $filename = $args{filename};
  my $parser = PomBase::Chobo::ParseOBO->new();
  my $res = $parser->parse(filename => $filename);

  my $chado_data = PomBase::Chobo::ChadoData->new(dbh => $self->dbh());

  my $terms_table = 'chobo_terms';

  my $dbh = $self->dbh();

  $dbh->do("DROP TABLE IF EXISTS $terms_table");
  $dbh->do("CREATE TEMPORARY TABLE $terms_table (local_id integer PRIMARY KEY, cvterm_id integer, name text, db_name text, accession text, dbxref_id integer)")
    or die "can't create temporary table $terms_table";
  $dbh->do("COPY $terms_table FROM STDIN");

  my $local_id = 0;

  for my $term (@{$res->{terms}}) {
    my ($db_name, $accession) = $term->{id} =~ /(.*?):(.*)/;

    my $term_name = $term->{name};

    $dbh->pg_putcopydata("$local_id\t0\t$term_name\t$db_name\t$accession\t0\n");

    $local_id++;
  }

  $dbh->pg_putcopyend();
}

1; # End of PomBase::Chobo
