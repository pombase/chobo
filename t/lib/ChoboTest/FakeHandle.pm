package ChoboTest::FakeHandle;

use Mouse;

use List::Util qw(first);

use ChoboTest::FakeStatement;

sub first_index
{
  my $val = shift;
  my @array = @_;

  return first { $array[$_] eq $val } 0..$#array;
}

sub check_unique
{
  my @rows = @_;

  my %counts = ();

  for my $row (@rows) {
    if ($counts{$row}) {
      return $row;
    }

    $counts{$row} = 1;
  }

  return undef;
}

has current_sth => (is => 'rw', isa => 'Maybe[ChoboTest::FakeStatement]', required => 0);
has storage => (is => 'rw', isa => 'HashRef',
                default => sub {
                  {
                    db => {
                      id_counter => 102,
                      column_names => [
                        'db_id', 'name',
                      ],
                      rows => [
                        [ 100, 'core' ],
                        [ 101, 'internal' ],
                      ],
                      unique_columns => ['name'],
                    },
                    dbxref =>{
                      id_counter => 203,
                      column_names => [
                        'dbxref_id', 'accession', 'db_id',
                      ],
                      rows => [
                        [ 200, 'is_a', 100 ],
                        [ 201, 'exact', 101 ],
                        [ 202, 'narrow', 101 ],
                      ],
                      unique_columns => ['accession', 'db_id'],
                    },
                    cv => {
                      id_counter => 302,
                      column_names => [
                        'cv_id', 'name',
                      ],
                      rows => [
                        [ 300, 'core' ],
                        [ 301, 'synonym_type' ],
                      ],
                      unique_columns => ['name'],
                    },
                    cvterm => {
                      id_counter => 401,
                      column_names => [
                        'cvterm_id', 'name', 'cv_id',
                        'dbxref_id', 'is_relationshiptype', 'is_obsolete',
                      ],
                      rows => [
                        [ 400, 'is_a', 300, 200, 1, 0],
                        [ 401, 'exact', 301, 201, 0, 0],
                        [ 402, 'narrow', 301, 202, 0, 0],
                      ],
                      unique_columns => ['name', 'cv_id'],
                    },
                    cvtermsynonym => {
                      id_counter => 501,
                      column_names => [
                        'cvtermsynonym_id', 'cvterm_id', 'synonym', 'type_id',
                      ],
                      rows => [
                      ],
                    },
                    cvterm_relationship => {
                      id_counter => 601,
                      column_names => [
                        'cvterm_relationship_id', 'subject_id', 'type_id', 'object_id',
                      ],
                      rows => [
                      ],
                    },
                    cvterm_dbxref => {
                      id_counter => 701,
                      column_names => [
                        'cvterm_dbxref_id', 'cvterm_id', 'dbxref_id',
                      ],
                      rows => [
                      ],
                    },
                  }
                });

sub BUILD
{
  my $self = shift;

  for my $key (keys %{$self->storage()}) {
    my @column_names = @{$self->storage()->{$key}->{column_names}};
    for (my $i = 0; $i < @column_names; $i++) {
      my $col_name = $column_names[$i];
      $self->storage()->{$key}->{column_info}->{$col_name} = {
        index => $i,
      }
    }
  }
}

sub do
{
  my $self = shift;

  $self->current_sth(ChoboTest::FakeStatement->new(statement => $_[0],
                                                   storage => $self->storage()));
}

sub pg_putcopydata
{
  my $self = shift;

  return $self->current_sth()->pg_putcopydata(@_);
}

sub pg_getcopydata
{
  my $self = shift;

  return $self->current_sth()->pg_getcopydata(@_);
}

sub pg_putcopyend
{
  my $self = shift;

  my $store_table_name = $self->current_sth()->query_table_name();
  my $table_storage = $self->storage()->{$store_table_name};

  my $unique_columns = $table_storage->{unique_columns};

  if ($unique_columns) {
    my $column_names = $table_storage->{column_names};
    my $rows = $table_storage->{rows};

    my @column_indexes = map {
      first_index($_, @$column_names);
    } @$unique_columns;

    my $col_values = sub {
      my $row = shift;

      return map {
        $row->[$_];
      } @column_indexes;
    };

    my $check_return =
      check_unique(map { join '-', $col_values->($_); } @$rows);

    if ($check_return) {
      die "unique constraint failed for $store_table_name: $check_return\n";
    }
  }

  $self->current_sth(undef);

  return 1;
}

sub errstr
{
  return '';
}

sub prepare
{
  my $self = shift;

  return ChoboTest::FakeStatement->new(storage => $self->storage(), statement => $_[0]);
}

1;
