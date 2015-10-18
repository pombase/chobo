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
use Try::Tiny;
use FileHandle;
use String::Strip;

use PomBase::Chobo::OntologyData;

sub die_line
{
  my $filename = shift;
  my $linenum = shift;
  my $message = shift;

  die "$filename:$linenum:$message\n";
}

sub _finish_stanza
{
  my $filename = shift;
  my $current = shift;
  my $terms_ref = shift;
  my $metadata_ref = shift;

  if (!defined $current->{id}) {
    die_line $filename,  $current->{line}, "stanza has no id\n";
    return;
  }

  if (!defined $current->{namespace}) {
    $current->{namespace} =
      $metadata_ref->{'default-namespace'};

    # the namespace may be undef, temporarily - hopefully it will merge with a
    # term/stanza that has a namespace before we use it
  }

  $current->{metadata} = $metadata_ref;
  $current->{source_file} = $filename;
  $current->{relationship} //= [];

  if ($current->{is_a}) {
    map {
      push @{$current->{relationship}},
        {
          'relationship_name' => 'is_a',
          'other_term' => $_,
        };
    } @{$current->{is_a}};

    delete $current->{is_a};
  }


  push @$terms_ref, PomBase::Chobo::OntologyTerm->new($current);
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
  if (!defined $filename) {
    die 'no filename passed to parse()';
  }

  my $ontology_data = $args{ontology_data};
  if (!defined $ontology_data) {
    die 'no ontology_data passed to parse()';
  }

  my %metadata = ();
  my @terms = ();

  my $current = undef;
  my @synonyms = ();

  my %meta = ();

  my $fh = FileHandle->new($filename, 'r') or die "can't open $filename: $!";

  while (defined (my $line = <$fh>)) {
    chomp $line;
    $line =~ s/![^"\n]*$//;
    StripLTSpace($line);

    next if length $line == 0;

    if ($line =~ /^\[(.*)\]$/) {
      my $stanza_type = $1;

      if (defined $current) {
        _finish_stanza($filename, $current, \@terms, \%metadata);
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
      $current = {
        is_relationshiptype => $is_relationshiptype,
        source_file_line_number => $line_number,
      };
    } else {
      if ($current) {
        my @bits = split /: /, $line, 2;
        if (@bits == 2) {
          my $field_name = $bits[0];
          my $field_value = $bits[1];

          my $field_conf = $PomBase::Chobo::OntologyConf::field_conf{$field_name};

          if (defined $field_conf) {
            if (defined $field_conf->{process}) {
              try {
                $field_value = $field_conf->{process}->($field_value);
              } catch {
                warn qq(warning "$_" at $filename line $.\n);
              };
            }
            if (defined $field_value) {
              if (defined $field_conf->{type} && $field_conf->{type} eq 'SINGLE') {
                $current->{$field_name} = $field_value;
              } else {
                push @{$current->{$field_name}}, $field_value;
              }
            }
          }
        } else {
          die "can't parse line - no colon: $line\n";
        }
      } else {
        # we're parsing metadata
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
    _finish_stanza($filename, $current, \@terms, \%metadata);
  }

  close $fh or die "can't close $filename: $!";

  try {
    $ontology_data->add(metadata => \%metadata,
                        terms => \@terms);
  } catch {
    die "failed while reading $filename: $_\n";
  }
}

1;
