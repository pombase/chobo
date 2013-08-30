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

use PomBase::Chobo::OntologyTerm;


has terms_by_id => (is => 'rw', init_arg => undef, isa => 'HashRef',
                    default => sub { {} });
has terms_by_name => (is => 'rw', init_arg => undef, isa => 'HashRef',
                      default => sub { {} });
has terms_by_cv_name => (is => 'rw', init_arg => undef, isa => 'HashRef',
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
    my $term = shift;

    bless $term, 'PomBase::Chobo::OntologyTerm';

    my $id = $term->{id};
    my $name = $term->{name};

    $terms_by_id->{$id} = $term;
    $terms_by_name->{$name} = $term;

    my $term_namespace = $term->namespace();

    if (!exists $metadata_by_namespace->{$term_namespace}) {
      $metadata_by_namespace->{$term_namespace} = clone $metadata;
    }

    for my $alt_id (@{$term->{alt_id}}) {
      my $existing_term = $terms_by_id->{$alt_id};
      if (defined $existing_term) {
        die qq("$id" is the ID of:\n\n) . $term->to_string() .
          "\n\nand an alt_id of:\n" . $existing_term->to_string() .
          "\n";
      }
    }

    if (defined $term->{namespace}) {
      $terms_by_cv_name->{$term->{namespace}}->{$term->{id}} = $term;
    } else {
      die "term ", $term->{id}, " has no namespace or default-namespace\n";
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

sub get_terms
{
  my $self = shift;

  return values %{$self->terms_by_id()};
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
