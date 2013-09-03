package PomBase::Chobo::OntologyData;

=head1 NAME

PomBase::Chobo::OntologyData - An in memory representation of an Ontology

=head1 SYNOPSIS

Objects of this class represent the part of an ontology that can be stored in
a Chado database.

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomBase::Chobo::OntologyData

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Mouse;

use Clone qw(clone);
use Try::Tiny;

use PomBase::Chobo::OntologyTerm;


has terms_by_id => (is => 'rw', init_arg => undef, isa => 'HashRef',
                    default => sub { {} });
has terms_by_name => (is => 'rw', init_arg => undef, isa => 'HashRef',
                      default => sub { {} });
has terms_by_cv_name => (is => 'rw', init_arg => undef, isa => 'HashRef',
                         default => sub { {} });
has terms_by_db_name => (is => 'rw', init_arg => undef, isa => 'HashRef',
                         default => sub { {} });
has metadata_by_namespace => (is => 'rw', init_arg => undef, isa => 'HashRef',
                              default => sub { {} });

sub add
{
  my $self = shift;

  my %args = @_;

  my $metadata = $args{metadata};
  my $terms = $args{terms};

  my $terms_by_id = $self->terms_by_id();
  my $terms_by_name = $self->terms_by_name();
  my $terms_by_cv_name = $self->terms_by_cv_name();

  my $metadata_by_namespace = $self->metadata_by_namespace();

  my $proc = sub {
    my $new_term = shift;
    PomBase::Chobo::OntologyTerm::bless_object($new_term);

    my @new_term_ids = ($new_term->{id});

    if (defined $new_term->{alt_id}) {
      push @new_term_ids, @{$new_term->{alt_id}};
    }

    my @found_existing_terms = ();

    for my $id (@new_term_ids) {
      my $existing_term = $terms_by_id->{$id};

      if (defined $existing_term) {
        if (!grep { $_ == $existing_term } @found_existing_terms) {
          push @found_existing_terms, $existing_term;
        }
      }
    }

    my $term = $new_term;

    if (@found_existing_terms > 1) {
      die "two terms match an alt_id field from:\n" .
        $term->to_string() . "\n\nmatching term 1:\n" .
        $found_existing_terms[0]->to_string() . "\n\nmatching term 2:\n" .
        $found_existing_terms[1]->to_string() . "\n";
    } else {
      if (@found_existing_terms == 1) {
        my $existing_term = $found_existing_terms[0];
        $existing_term->merge($term);
        $term = $existing_term;
      } else {
        PomBase::Chobo::OntologyTerm::bless_object($term);
      }
    }

    for my $id (@new_term_ids) {
      $terms_by_id->{$id} = $term;

      my ($db_name, $accession);

      unless (($db_name, $accession) = $id =~ /^(\S+):(.+?)\s*$/) {
        $db_name = 'null';
        $accession = $id;
      }

      $term->{accession} = $accession;
      $term->{db_name} = $db_name;

      $self->terms_by_db_name()->{$db_name}->{$accession} = $term;
    }

    my $name = $term->{name};

    if (defined $name) {
      $terms_by_name->{$name} = $term;
    }

    my $term_namespace = $term->namespace();

    if (defined $term_namespace) {
      $terms_by_cv_name->{$term->{namespace}}->{$term->{id}} = $term;

      if (!exists $metadata_by_namespace->{$term_namespace}) {
        $metadata_by_namespace->{$term_namespace} = clone $metadata;
      }
    }
  };

  map { $proc->($_); } @{$terms};
}

sub term_by_name
{
  my $self = shift;
  my $name = shift;

  return $self->terms_by_name()->{$name};
}

sub term_by_id
{
  my $self = shift;
  my $id = shift;

  return $self->terms_by_id()->{$id};
}

sub get_cv_names
{
  my $self = shift;

  return keys %{$self->terms_by_cv_name()};
}

sub get_terms_by_cv_name
{
  my $self = shift;
  my $cv_name = shift;

  return values %{$self->terms_by_cv_name()->{$cv_name}};
}

sub get_db_names
{
  my $self = shift;

  return keys %{$self->terms_by_db_name()};
}

sub get_terms_by_db_name
{
  my $self = shift;
  my $db_name = shift;

  return values %{$self->terms_by_db_name()->{$db_name}};
}

sub get_terms
{
  my $self = shift;

  return map { $self->get_terms_by_cv_name($_); } $self->get_cv_names();
}

sub get_namespaces
{
  my $self = shift;

  return keys %{$self->metadata_by_namespace()};
}

sub get_metadata_by_namespace
{
  my $self = shift;
  my $namespace = shift;

  return $self->metadata_by_namespace()->{$namespace};
}

1;
