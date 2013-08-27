package PomBase::Chobo::ChadoData;

=head1 NAME

PomBase::Chobo::ChadoData - Read and store cv/db data from Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomBase::Chobo::ChadoData

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Mouse;

has dbh => (is => 'ro');

has cv_data => (is => 'ro', init_arg => undef, lazy_build => 1);
has db_data => (is => 'ro', init_arg => undef, lazy_build => 1);

has cvterm_data => (is => 'ro', init_arg => undef, lazy_build => 1);
has dbxref_data => (is => 'ro', init_arg => undef, lazy_build => 1);

has cvtermsynonyms_by_cvterm_id => (is => 'rw', init_arg => undef, lazy_build => 1);

our @cvterm_column_names = qw(cvterm_id name cv_id dbxref_id is_obsolete is_relationshiptype);
our @dbxref_column_names = qw(dbxref_id db_id accession version);

sub _execute
{
  my $self = shift;
  my $sql = shift;
  my $proc = shift;

  my $dbh = $self->dbh();

  my $sth = $dbh->prepare($sql);
  my $rv = $sth->execute();
  if (!$rv) {
    die "couldn't execute() $sql: ", $dbh->errstr(), "\n";
  }

  while (my $ref = $sth->fetchrow_hashref() ) {
    $proc->($ref);
  }

  $sth->finish();
}

sub _get_cv_or_db
{
  my $self = shift;
  my $table_name = shift;

  my %by_id = ();
  my %by_name = ();

  my $proc = sub {
    my $row_ref = shift;
    $by_id{$row_ref->{"${table_name}_id"}} = $row_ref;
    $by_name{$row_ref->{name}} = $row_ref;
  };

  $self->_execute("select * from $table_name", $proc);

  return \%by_id, \%by_name;
}

sub _build_cv_data
{
  my $self = shift;

  my ($cvs_by_cv_id, $cvs_by_cv_name) = $self->_get_cv_or_db('cv');
  return { by_id => $cvs_by_cv_id, by_name => $cvs_by_cv_name };
}

sub get_cv_by_id
{
  my $self = shift;
  my $cv_id = shift;

  return $self->cv_data()->{by_id}->{$cv_id};
}

sub get_cv_by_name
{
  my $self = shift;
  my $cv_name = shift;

  return $self->cv_data()->{by_name}->{$cv_name};
}

sub get_cv_names
{
  my $self = shift;

  return keys %{$self->cv_data()->{by_name}};
}

sub _build_db_data
{
  my $self = shift;

  my ($dbs_by_db_id, $dbs_by_db_name) = $self->_get_cv_or_db('db');
  return { by_id => $dbs_by_db_id, by_name => $dbs_by_db_name, };
}

sub get_db_by_id
{
  my $self = shift;
  my $db_id = shift;

  return $self->db_data()->{by_id}->{$db_id};
}

sub get_db_by_name
{
  my $self = shift;
  my $db_name = shift;

  return $self->db_data()->{by_name}->{$db_name};
}

sub get_db_names
{
  my $self = shift;

  return keys %{$self->db_data()->{by_name}};
}

sub _get_by_copy
{
  my $self = shift;
  my $table_name = shift;
  my $column_names_ref = shift;
  my @column_names = @$column_names_ref;
  my $proc = shift;

  my $dbh = $self->dbh();

  my $column_names = join ',', @column_names;

  $dbh->do("COPY $table_name($column_names) TO STDOUT")
    or die "failed to COPY $table_name: ", $dbh->errstr, "\n";

  my $tsv = Text::CSV->new({sep_char => "\t"});

  my $line = undef;

  while ($dbh->pg_getcopydata(\$line) > 0) {
    chomp $line;
    if ($tsv->parse($line)) {
      my @fields = $tsv->fields();
      $proc->(\@fields);
    } else {
      die "couldn't parse this line as tab separated values: $line\n";
    }
  }
}

sub _get_cvtermsynonyms
{
  my $self = shift;

  my $dbh = $self->dbh();

  my @column_names = qw(cvtermsynonym_id cvterm_id synonym type_id);

  my %by_cvterm_id = ();

  my $proc = sub {
    my $fields_ref = shift;
    my @fields = @$fields_ref;
    my ($cvtermsynonym_id, $cvterm_id, $synonym, $type_id) = @fields;
    $by_cvterm_id{$cvterm_id} = \@fields;
  };

  $self->_get_by_copy('cvtermsynonym', \@column_names, $proc);

  return \%by_cvterm_id
}

sub _build_cvterm_data
{
  my $self = shift;

  my %by_cvterm_id = ();
  my %by_cv_id = ();
  my %by_dbxref_id = ();

  my $proc = sub {
    my $fields_ref = shift;
    my @fields = @$fields_ref;
    my ($cvterm_id, $name, $cv_id, $dbxref_id, $is_obsolete,
        $is_relationshiptype) = @fields;
    $by_cvterm_id{$cvterm_id} = \@fields;
    $by_cv_id{$cv_id}->{$name} = \@fields;
    $by_dbxref_id{$dbxref_id} = \@fields;
  };

  $self->_get_by_copy('cvterm', \@cvterm_column_names, $proc);

  my $dbxref_by_termid = $self->dbxref_data()->{by_termid};

  my %by_termid = map {
    my $dbxref_id = $dbxref_by_termid->{$_}->[0];
    my $cvterm_data = $by_dbxref_id{$dbxref_id};
    if (defined $cvterm_data) {
      ($_, $cvterm_data);
    } else {
      ();
    }
  } $self->get_all_termids();

  return {
    by_cvterm_id => \%by_cvterm_id,
    by_cv_id => \%by_cv_id,
    by_dbxref_id => \%by_dbxref_id,
    by_termid => \%by_termid,
  };
}

sub get_cvterm_by_cvterm_id
{
  my $self = shift;

  return $self->cvterm_data()->{by_cvterm_id};
}

sub get_cvterms_by_cv_id
{
  my $self = shift;
  my $cv_id = shift;

  return $self->cvterm_data()->{by_cv_id}->{$cv_id};
}

sub get_cvterm_by_dbxref_id
{
  my $self = shift;
  my $dbxref_id = shift;

  return $self->cvterm_data()->{by_dbxref_id}->{$dbxref_id};
}

sub get_cvterm_by_termid
{
  my $self = shift;
  my $termid = shift;

  return $self->cvterm_data()->{by_termid}->{$termid};
}

sub get_all_termids
{
  my $self = shift;

  return keys %{$self->dbxref_data()->{by_termid}};
}

sub get_dbxref_by_dbxref_id
{
  my $self = shift;
  my $dbxref_id = shift;

  return $self->dbxref_data()->{by_dbxref_id}->{$dbxref_id};
}

sub get_dbxref_by_termid
{
  my $self = shift;
  my $termid = shift;

  return $self->dbxref_data()->{by_termid}->{$termid};
}

sub _build_dbxref_data
{
  my $self = shift;

  my $dbh = $self->dbh();

  my $db_data = $self->db_data();

  my %by_id = ();
  my %by_termid = ();

  my $proc = sub {
    my $fields_ref = shift;
    my @fields = @$fields_ref;
    my ($dbxref_id, $db_id, $accession, $version) = @fields;
    $by_id{$dbxref_id} = \@fields;
    my $db_name = $db_data->{by_id}->{$db_id}->{name};
    if (!defined $db_name) {
      die "no db name for db $db_id";
    }
    my $termid = "$db_name:$accession";
    push @fields, $termid;
    $by_termid{$termid} = \@fields;
  };

  $self->_get_by_copy('dbxref', \@dbxref_column_names, $proc);

  return {
    by_dbxref_id => \%by_id,
    by_termid => \%by_termid,
  };
}

sub _build_cvtermsynonyms_by_cvterm_id
{
  my $self = shift;

  return $self->_get_cvtermsynonyms();
}

sub get_cvtermsynonyms_by_cvterm_id
{
  my $self = shift;
  my $cvterm_id = shift;

  return $self->cvtermsynonyms_by_cvterm_id()->{$cvterm_id};
}

1;
