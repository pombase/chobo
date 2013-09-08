package PomBase::Chobo::OntologyConf;

=head1 NAME

PomBase::Chobo::OntologyConf - Configuration for ontology data

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomBase::Chobo::OntologyConf

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use warnings;

use String::Strip;

our %field_conf = (
  id => {
    type => 'SINGLE',
  },
  name => {
    type => 'SINGLE',
  },
  is_obsolete => {
    type => 'SINGLE',
    process => sub {
      my $val = shift;
      if ($val eq 'true') {
        return 1;
      } else {
        return 0;
      }
    },
 },
  namespace => {
    type => 'SINGLE',
    merge => sub {
      my $self = shift;
      my $other = shift;

      my $self_namespace = $self->{namespace};
      my $other_namespace = $other->{namespace};
      if (defined $self_namespace &&
          defined $other_namespace) {
        # if the namespace is the same as the db_name, remove it and use the
        # namespace from the other term to avoid a namespace clash
        if ($self_namespace eq $self->{db_name}) {
          $self->{namespace} = undef;
        } else {
          if ($other_namespace eq $other->{db_name}) {
            $other->{namespace} = undef;
          }
        }
      }
      # do default merging
      return undef;
    },
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
      if ($val =~ /^"(.+)"\s*(.*)/) {
        my $synonym = $1;
        my $rest = $2;
        my %ret = (
          synonym => $synonym,
        );

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
        die "unknown synonym format: $val\n";
        return undef;
      }
    },
    to_string => sub {
      my $val = shift;
      my $ret_string = $val->{synonym};
      if (defined $val->{scope}) {
        $ret_string .= ' ' . $val->{scope};
      }
      if (defined $val->{type}) {
        $ret_string .= ' ' . $val->{type};
      }
      if (defined $val->{dbxrefs}) {
        $ret_string .= ' [' . (join ", ", @{$val->{dbxrefs}}) . ']';
      }

      return $ret_string;
    },
  },
);

1;
