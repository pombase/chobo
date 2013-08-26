package PomBase::Chobo::ParseOBO;

=head1 NAME

PomBase::Chobo::ParseOBO - Parse the bits of an OBO file needed for
                           loading Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomBase::Chobo::ParseOBO

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Mouse;
use FileHandle;

use PomBase::Chobo::OntologyData;

has terms => (is => 'rw', init_arg => undef);

my %field_conf = (
  id => {
    type => 'SINGLE',
  },
  name => {
    type => 'SINGLE',
  },
  namespace => {
    type => 'SINGLE',
  },
  alt_id => {
    type => 'ARRAY',
  },
  is_a => {
    type => 'ARRAY',
  },
  xref => {
    type => 'ARRAY',
  },
  synonym => {
    type => 'ARRAY',
    process => sub {
      my $val = shift;
      if ($val =~ /"(.+)"\s*(.*)/) {
        my $synonym = $1;
        my $rest = $2;
        my %ret = (
          synonym => $synonym,
        );

        $rest =~ s/^\s+//;

        if ($rest =~ /(\S+)\s+(?:(?:(\S+)\s+)?(?:\s+\[(.*)\]))?/) {
          my ($scope, $type, $dbxrefs) = ($1, $2, $3);

          $ret{scope} = $scope;
          $ret{type} = $type;

          my @dbxrefs = ();
          if (defined $dbxrefs) {
            @dbxrefs = split /\s*,\s*/, $dbxrefs;
          }
          $ret{dbxrefs} = \@dbxrefs;
        }

        return \%ret;
      } else {
        warn "unknown synonym format: $val\n";
        return undef;
      }
    },
  },
);

sub _save_stanza_line
{
  my $stanza = shift;
  my $line = shift;

  if ($line =~ /^\s*(\S+):\s+(.+?)\s*$/) {
    my $field_name = $1;
    my $field_value = $2;

    my $field_conf = $field_conf{$field_name};

    if (defined $field_conf) {
      if (defined $field_conf->{process}) {
        $field_value = $field_conf->{process}->($field_value);
      }
      if (defined $field_conf->{type} && $field_conf->{type} eq 'SINGLE') {
        $stanza->{$field_name} = $field_value;
      } else {
        push @{$stanza->{$field_name . '_list'}}, $field_value;
      }
    }
  }
}

sub _clean_line
{
  my $line_ref = shift;

  chomp $$line_ref;
  $$line_ref =~ s/!.*//;
  $$line_ref =~ s/^\s+//;
  $$line_ref =~ s/\s+$//;
}

sub _finish_stanza
{
  my $current = shift;
  my $terms_ref = shift;
  my $relations_ref = shift;
  my $metadata_ref = shift;

  if (!defined $current->{id}) {
    warn "stanza at line ", $current->{line}, " has no id: - skipped\n";
    return;
  }
  if (!defined $current->{name}) {
    warn "stanza at line ", $current->{line}, " has no name: - skipped\n";
    return;
  }

  if (!defined $current->{namespace}) {
    $current->{namespace} = $metadata_ref->{'default-namespace'};
  }

  if ($current->{is_relationshiptype}) {
    push @$relations_ref, $current;
  } else {
    push @$terms_ref, $current;
  }
}

sub fatal
{
  my $message = shift;

  die "fatal: $message\n";
}

my %interesting_metadata = (
  'default-namespace' => 1,
  'ontology' => 1,
  'date' => 1,
);

sub parse
{
  my $self = shift;
  my %args = @_;

  my $filename = $args{filename};

  my %metadata = ();
  my @terms = ();
  my @relations = ();

  my $current = undef;
  my @synonyms = ();

  my %meta = ();

  my $fh = FileHandle->new($filename, 'r') or die "can't open $filename: $!";

  while (defined (my $line = <$fh>)) {
    _clean_line(\$line);

    next if length $line == 0;

    if ($line =~ /^\[(.*)\]$/) {
      my $stanza_type = $1;

      if (defined $current) {
        _finish_stanza($current, \@terms, \@relations, \%metadata);
      }

      my $is_relationshiptype = 0;
      my $line_number = $fh->input_line_number();

      if ($stanza_type eq 'Typedef') {
        $is_relationshiptype = 1;
      } else {
        if ($stanza_type ne 'Term') {
          die "unknown stanza type '[$stanza_type]'\n";
        }
      }
      $current = { is_relationshiptype => $is_relationshiptype };
      $current->{line} = $line_number;
    } else {
      if ($current) {
        _save_stanza_line($current, $line);
      } else {
        if ($line =~ /^(.+?):\s*(.*)/) {
          my ($key, $value) = ($1, $2);

          if ($interesting_metadata{$key}) {
            if (defined $metadata{$key}) {
              fatal qq(metadata key "$key" occurs more than once in header);
            }
            $metadata{$key} = $value;
          }
        } else {
          fatal "can't parse header line: $line";
        }
      }
    }
  }

  if (defined $current) {
    _finish_stanza($current, \@terms, \@relations, \%metadata);
  }

  close $fh or die "can't close $filename: $!";

  $self->terms(\@terms);

  return PomBase::Chobo::OntologyData->new(metadata => \%metadata,
                                           terms => \@terms,
                                           relations => \@relations);
}

1;
