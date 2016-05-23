package ChoboTest::FakeHandle;

use Mouse;

use ChoboTest::FakeStatement;

has current_sth => (is => 'rw', isa => 'Maybe[ChoboTest::FakeStatement]', required => 0);
has storage => (is => 'rw', isa => 'HashRef',
                default => sub {
                  {
                    db => {
                      id_counter => 101,
                      column_names => [
                        'db_id', 'name',
                      ],
                      rows => [
                        [ 100, 'core', ]
                      ],
                    },
                    dbxref =>{
                      id_counter => 201,
                      column_names => [
                        'dbxref_id', 'accession', 'db_id',
                      ],
                      rows => [
                        [ 200, 'is_a', 100, ]
                        ],
                    },
                    cv => {
                      id_counter => 301,
                      column_names => [
                        'cv_id', 'name',
                      ],
                      rows => [
                        [ 300, 'core' ],
                      ]
                    },
                    cvterm => {
                      id_counter => 401,
                      column_names => [
                        'cvterm_id', 'name', 'cv_id',
                        'dbxref_id', 'is_relationshiptype', 'is_obsolete',
                      ],
                      rows => [
                        [ 400, 'is_a', 300, 200, 1, 0]
                      ]
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
