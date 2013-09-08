package PomBase::Chobo::Role::ChadoStore;

=head1 NAME

PomBase::Chobo::Role::ChadoStore - Code for storing terms in Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomBase::Chobo::Role::ChadoStore

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Mouse::Role;

requires 'dbh';
requires 'chado_data';
requires 'ontology_data';

use PomBase::Chobo::ChadoData;

sub _copy_to_table
{
  my $self = shift;
  my $table_name = shift;
  my $column_names_ref = shift;
  my @column_names = @$column_names_ref;
  my $data_ref = shift;
  my @data = @$data_ref;

  my $dbh = $self->dbh();

  my $column_names = join ',', @column_names;

  $dbh->do("COPY $table_name($column_names) FROM STDIN")
    or die "failed to COPY into $table_name: ", $dbh->errstr, "\n";

  for my $row (@data) {
    $dbh->pg_putcopydata((join "\t", @$row) . "\n");
  }

  $dbh->pg_putcopyend();

  warn "COPY $table_name FROM STDIN finished\n";
}

my %row_makers = (
  db => sub {
    my $ontology_data = shift;

    return map {
      [$_];
    } $ontology_data->get_db_names();
  },
  dbxref => sub {
    my $ontology_data = shift;
    my $chado_data = shift;

    map {
      my $db_name = $_;
      my $db_id = $chado_data->get_db_by_name($db_name)->{db_id};

      my %current_db_terms = %{$ontology_data->terms_by_db_name()->{$db_name}};

      map {
        my $accession = $_;
        [$db_id, $accession];
     } keys %current_db_terms;
    } $ontology_data->get_db_names();
  },

);

my %table_column_names = (
  db => [qw(name)],
  dbxref => [qw(db_id accession)],
);

sub chado_store
{
  my $self = shift;

  my @cvterm_column_names =
    @PomBase::Chobo::ChadoData::cvterm_column_names;

  my $chado_data = $self->chado_data();

  my @tables_to_store = qw(db dbxref);

  for my $table_to_store (@tables_to_store) {
    my @rows = $row_makers{$table_to_store}->($self->ontology_data(),
                                              $self->chado_data());

    $self->_copy_to_table($table_to_store, $table_column_names{$table_to_store},
                          \@rows);
  }

}

1;
