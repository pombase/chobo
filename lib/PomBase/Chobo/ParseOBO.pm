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

has terms => (is => 'rw', init_arg => undef);


sub _save_stanza_line
{
  my $stanza = shift;
  my $line = shift;

  if ($line =~ /^\s*(\S+):\s+(.+?)\s*$/) {
    my $field_name = $1;
    my $field_value = $2;

    my $field_conf = $PomBase::Chobo::OntologyConf::field_conf{$field_name};

    if (defined $field_conf) {
      if (defined $field_conf->{process}) {
        $field_value = $field_conf->{process}->($field_value);
      }
      if (defined $field_conf->{type} && $field_conf->{type} eq 'SINGLE') {
        $stanza->{$field_name} = $field_value;
      } else {
        push @{$stanza->{$field_name}}, $field_value;
      }
    }
  }
}

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

    # the namespace may be undef, temporary - hopefully it will merge with a
    # term/stanza that has a namespace before we use it
  }

  $current->{filename} = $filename;
  $current->{metadata} = $metadata_ref;

  PomBase::Chobo::OntologyTerm::bless_object($current);

  push @$terms_ref, $current;
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
    $line =~ s/!.*//;
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
    _finish_stanza($filename, $current, \@terms, \%metadata);
  }

  close $fh or die "can't close $filename: $!";

  $self->terms(\@terms);

  try {
    $ontology_data->add(metadata => \%metadata,
                        terms => \@terms);
  } catch {
    die "$filename: $_\n";
  }
}

1;
