package ChoboTest::FakeStatement;

use Mouse;

use Clone qw(clone);

has statement => (is => 'rw', required => 1);
has storage => (is => 'rw', required => 1, isa => 'HashRef');
has query_table_name => (is => 'rw');
has query_column_names => (is => 'rw', isa => 'ArrayRef');
has rows => (is => 'rw', isa => 'ArrayRef');

sub BUILD
{
  my $self = shift;

  my $statement = $self->statement();

  if ($statement =~ /select\s+(.*?)\s+from\s+(\S+)/i) {
    $self->query_table_name($2);

    my @column_names = split /,\s*/, $1;

    $self->query_column_names(\@column_names);
  } else {
    if ($statement =~ /copy\s+(.*?)\s*\((.+)\) (FROM STDIN|TO STDOUT) CSV/i) {
      $self->query_table_name($1);

      my @column_names = split /,\s*/, $2;

      $self->query_column_names(\@column_names);
    } else {
      die "can't parse statement in BUILD: ", $statement;
    }
  }

  $self->rows(clone $self->storage()->{$self->query_table_name()}->{rows});
}

sub execute
{
  return 1;
}

sub _as_hashref
{
  my $self = shift;
  my $row = shift;

  if (!$row) {
    return undef;
  }

  my %ret = ();

  my $table_storage = $self->storage()->{$self->query_table_name};

  for my $query_col_name (@{$self->query_column_names()}) {
    my $index = $table_storage->{column_info}->{$query_col_name}->{index};

    if (!defined $index) {
      die "no such column: $query_col_name\n";
    }

    $ret{$query_col_name} = $row->[$index];
  }

  return \%ret;
}

sub fetchrow_hashref
{
  my $self = shift;
  return $self->_as_hashref(shift @{$self->rows()});
}

sub pg_putcopydata
{
  my $self = shift;

  my $storage = $self->storage();
  my $table_data = $storage->{$self->query_table_name()};
  my $query_table_name = $self->query_table_name();

  my $row_data = shift;
  chomp $row_data;

  my @parsed_row_data = split /,/, $row_data;

  my @insert_row = ();

  my $id_index = $table_data->{column_info}->{$query_table_name . '_id'}->{index};

  for (my $i = 0; $i < @{$self->query_column_names()}; $i++) {
    my $query_column_name = $self->query_column_names()->[$i];
    my $query_column_index = $table_data->{column_info}->{$query_column_name}->{index};

    if (!defined $query_column_index) {
      die "no such column: $query_column_name\n";
    }

    $insert_row[$query_column_index] = $parsed_row_data[$i];
  }

  $insert_row[$id_index] = $table_data->{'id_counter'}++;

  push @{$table_data->{rows}}, \@insert_row;
}

sub pg_getcopydata
{
  my $self = shift;
  my $line_ref = shift;

  my $storage = $self->storage();
  my $table_data = $storage->{$self->query_table_name()};
  my $query_table_name = $self->query_table_name();

  my $row_data = $self->fetchrow_hashref();

  if (!$row_data) {
    return -1;
  }

  my @ret_col_values = ();

  for my $ret_col_name (@{$self->query_column_names()}) {
    push @ret_col_values, $row_data->{$ret_col_name};
  }

  $$line_ref = (join ',', @ret_col_values) . "\n";

  return length $$line_ref;
}

sub finish
{
}

1;
