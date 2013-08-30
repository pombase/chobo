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

use Mouse;
use Text::CSV;

use PomBase::Chobo::ParseOBO;
use PomBase::Chobo::ChadoData;

has dbh => (is => 'ro');

has new_terms => (is => 'rw', init_arg => undef);
has new_synonyms => (is => 'rw', init_arg => undef);
has remove_synonyms => (is => 'rw', init_arg => undef);
has chado_data => (is => 'ro', init_arg => undef, lazy_build => 1);

sub _build_chado_data
{
  my $self = shift;

  return PomBase::Chobo::ChadoData->new(dbh => $self->dbh());
}

sub process
{
  my $self = shift;
  my %args = @_;

  my $filenames = $args{filenames};
  my $parser = PomBase::Chobo::ParseOBO->new();

  my $combined = PomBase::Chobo::OntologyData->new();

  for my $filename (@$filenames) {
    my $ontology_data = $parser->parse(filename => $filename);
    $chobo->process(filename => $filename);
  }

  $self->chado_store($self->chado_data(), $ontology_data);
}

1;
