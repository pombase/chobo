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

use Moose;

has dbh => (is => 'ro');

has cvs_by_cv_id => (is => 'rw', init_arg => undef);
has cvs_by_cv_name => (is => 'rw', init_arg => undef);
has dbs_by_db_id => (is => 'rw', init_arg => undef);
has dbs_by_db_name => (is => 'rw', init_arg => undef);
has cvterms_by_cvterm_id => (is => 'rw', init_arg => undef);
has cvterms_by_cv_id => (is => 'rw', init_arg => undef);
has cvterms_by_dbxref_id => (is => 'rw', init_arg => undef);
has cvterms_by_termid => (is => 'rw', init_arg => undef);
has dbxrefs_by_dbxref_id => (is => 'rw', init_arg => undef);
has dbxrefs_by_termid => (is => 'rw', init_arg => undef);

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

sub _get_cv_db
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

sub _get_cvs
{
  my $self = shift;

  return $self->_get_cv_db('cv');
}

sub _get_dbs
{
  my $self = shift;

  return $self->_get_cv_db('db');
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

  warn "COPY finished\n";
}


sub _get_cvterms
{
  my $self = shift;

  my @column_names = qw(cvterm_id name cv_id dbxref_id is_obsolete is_relationshiptype);

  my %by_id = ();
  my %by_cv_id = ();
  my %by_dbxref_id = ();

  my $proc = sub {
    my $fields_ref = shift;
    my @fields = @$fields_ref;
    my ($cvterm_id, $name, $cv_id, $dbxref_id, $is_obsolete,
        $is_relationshiptype) = @fields;
    $by_id{$cvterm_id} = \@fields;
    $by_cv_id{$cv_id}->{$name} = \@fields;
    $by_dbxref_id{$dbxref_id} = \@fields;
  };

  $self->_get_by_copy('cvterm', \@column_names, $proc);

  return \%by_id, \%by_cv_id, \%by_dbxref_id;
}

sub _get_dbxrefs
{
  my $self = shift;
  my $dbs_by_id = shift;

  my %db_id_names = map { ($_, $dbs_by_id->{$_}->{name}) } keys %$dbs_by_id;

  my $dbh = $self->dbh();

  my @column_names = qw(dbxref_id db_id accession version);

  my %by_id = ();
  my %by_termid = ();

  my $proc = sub {
    my $fields_ref = shift;
    my @fields = @$fields_ref;
    my ($dbxref_id, $db_id, $accession, $version) = @fields;
    $by_id{$dbxref_id} = \@fields;
    my $db_name = $db_id_names{$db_id};
    if (!defined $db_name) {
      die "no db name for db $db_id";
    }
    my $termid = "$db_name:$accession";
    push @fields, $termid;
    $by_termid{$termid} = \@fields;
  };

  $self->_get_by_copy('dbxref', \@column_names, $proc);

  return \%by_id, \%by_termid;
}


sub BUILD
{
  my $self = shift;

  my ($cvs_by_cv_id, $cvs_by_cv_name) = $self->_get_cvs();
  $self->cvs_by_cv_id($cvs_by_cv_id);
  $self->cvs_by_cv_name($cvs_by_cv_name);

  my ($dbs_by_db_id, $dbs_by_db_name) = $self->_get_dbs();
  $self->dbs_by_db_id($dbs_by_db_id);
  $self->dbs_by_db_name($dbs_by_db_name);

  my ($cvterms_by_cvterm_id, $cvterms_by_cv_id, $cvterms_by_dbxref_id) =
    $self->_get_cvterms();
  $self->cvterms_by_cvterm_id($cvterms_by_cvterm_id);
  $self->cvterms_by_cv_id($cvterms_by_cv_id);
  $self->cvterms_by_dbxref_id($cvterms_by_dbxref_id);

  my ($dbxrefs_by_dbxref_id, $dbxrefs_by_termid) =
    $self->_get_dbxrefs($dbs_by_db_id);
  $self->dbxrefs_by_dbxref_id($dbxrefs_by_dbxref_id);
  $self->dbxrefs_by_termid($dbxrefs_by_termid);

  my %cvterms_by_termid = map {
    my $dbxref_id = $dbxrefs_by_termid->{$_}->[0];
    my $cvterm_data = $cvterms_by_dbxref_id->{$dbxref_id};
    if (defined $cvterm_data) {
      ($_, $cvterm_data);
    } else {
      ();
    }
  } keys %$dbxrefs_by_termid;

  $self->cvterms_by_termid(\%cvterms_by_termid);
}

1;
