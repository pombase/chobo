package PomBase::Chobo::OntologyTerm;

=head1 NAME

PomBase::Chobo::OntologyTerm - Simple class for accessing term data

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomBase::Chobo::OntologyTerm

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Mouse;
use Carp;

use PomBase::Chobo::OntologyConf;

use Clone qw(clone);
use Data::Compare;
use List::Compare;

has id => (is => 'ro', isa => 'Str', required => 1);
has name => (is => 'ro', isa => 'Str');
has namespace => (is => 'ro', isa => 'Str');
has alt_id => (is => 'ro', isa => 'ArrayRef');
has is_relationshiptype => (is => 'ro', isa => 'Bool');
has source_file => (is => 'ro', isa => 'Str', required => 1);
has source_file_line_number => (is => 'ro', isa => 'Str', required => 1);

our @field_names;
our %field_conf;

BEGIN {
  %field_conf = %PomBase::Chobo::OntologyConf::field_conf;
  @field_names = qw(id name);

  for my $field_name (sort grep { $_ ne 'id' && $_ ne 'name' } keys %field_conf) {
    push @field_names, $field_name;
  }
}

sub bless_object
{
  my $object = shift;

  $object->{alt_id} //= [];

  my ($db_name, $accession);

  unless (($db_name, $accession) = $object->{id} =~ /^(\S+):(.+?)\s*$/) {
    $db_name = $object->{namespace} //
      $object->{ontology} // $object->{source_file};
    $accession = $object->{id};

    $object->{id} = "$db_name:$accession";
  }

  $object->{accession} = $accession;
  $object->{db_name} = $db_name;

  if (!defined $object->{source_file}) {
    confess "source_file attribute of object is required\n";
  }

  if (!defined $object->{source_file_line_number}) {
    confess "source_file_line attribute of object is required\n";
  }

  bless $object, __PACKAGE__;
}

=head2 merge

 Usage   : my $merged_term = $term->merge($other_term);
 Function: Attempt to merge $other_term into this term.  Only merges if at least
           one of the ID or alt_ids from this term match the ID or an alt_id
           from $other_term
 Args    : $other_term - the term to merge with
 Return  : undef - if no id from this term matches one from $other_term
           $self - if there is a match
=cut

sub merge
{
  my $self = shift;
  my $other_term = shift;

  return if $self == $other_term;

  my $lc = List::Compare->new([$self->{id}, @{$self->{alt_id}}],
                              [$other_term->{id}, @{$other_term->{alt_id}}]);

  if (scalar($lc->get_intersection()) == 0) {
    return undef;
  }

  my @new_alt_id = List::Compare->new([$lc->get_union()], [$self->id()])->get_unique(1);

  $self->{alt_id} = \@new_alt_id;

  my $merge_field = sub {
    my $name = shift;
    my $other_term = shift;

    my $field_conf = $PomBase::Chobo::OntologyConf::field_conf{$name};

    if (defined $field_conf) {
      if (defined $field_conf->{type} && $field_conf->{type} eq 'SINGLE') {
        my $res = undef;
        if (defined $field_conf->{merge}) {
          $res = $field_conf->{merge}->($self, $other_term);
        }

        if (defined $res) {
          $self->{$name} = $res;
        } else {
          my $new_field_value = $other_term->{$name};

          if (defined $new_field_value) {
            if (defined $self->{$name}) {
              if ($self->{$name} ne $new_field_value) {
                warn qq|"$name" tag of this stanza (from |,
                  $other_term->source_file(), " line ",
                  $other_term->source_file_line_number(), ") ",
                  "differs from previously ",
                  "seen value (from ", $self->source_file(),
                  " line ", $self->source_file_line_number(), q|) "|,
                  $self->{$name}, ") ",
                  qq(" - ignoring new value:\n\n),
                  $other_term->to_string() . "\n\n",
                  "merging into:\n\n",
                  $self->to_string(), "\n\n";

              }
            } else {
              $self->{$name} = $new_field_value;
            }
          } else {
            # no merging to do
          }
        }
      } else {
        my $new_field_value = $other_term->{$name};
        for my $single_value (@$new_field_value) {
          if (!grep { Compare($_, $single_value) } @{$self->{$name}}) {
            push @{$self->{$name}}, clone $single_value;
          }
        }
      }
    } else {
      die "unhandled field in merge(): $name\n";
    }
  };

  for my $field_name (@field_names) {
    next if $field_name eq 'id' or $field_name eq 'alt_id';

    if (!Compare($self->{$field_name}, $other_term->{$field_name})) {
      $merge_field->($field_name, $other_term);
    }
  }

  return $self;
}

sub to_string
{
  my $self = shift;

  my @lines = ();

  if ($self->is_relationshiptype()) {
    push @lines, "[Typedef]";
  } else {
    push @lines, "[Term]";
  }

  my $line_maker = sub {
    my $name = shift;
    my $value = shift;

    my @ret_lines = ();

    if (ref $value) {
      for my $single_value (@$value) {
        my $to_string_proc = $field_conf{$name}->{to_string};
        my $value_as_string;
        if (defined $to_string_proc) {
          $value_as_string = $to_string_proc->($single_value);
        } else {
          $value_as_string = $single_value;
        }
        push @ret_lines, "$name: $value_as_string";
      }
    } else {
      push @ret_lines, "$name: $value";
    }

    return @ret_lines;
  };

  for my $field_name (@field_names) {
    my $field_value = $self->{$field_name};

    if (defined $field_value) {
      push @lines, $line_maker->($field_name, $field_value);
    }
  }

  return join "\n", @lines;
}

1;
