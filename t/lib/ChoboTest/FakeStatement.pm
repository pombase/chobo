package ChoboTest::FakeStatement;

use Mouse;

has statement => (is => 'rw', required => 1);
has storage => (is => 'rw', required => 1, isa => 'HashRef');
has query_table_name => (is => 'rw');
has query_column_names => (is => 'rw', isa => 'ArrayRef');
has rows => (is => 'rw', isa => 'ArrayRef');

sub BUILD
{
  my $self = shift;

  my $statement = $self->statement();

  if ($statement =~ /select\s+(.*?)\s+from\s+(\S+)/) {
    $self->query_table_name($2);

    my @column_names = split /,\s*/, $1;

    $self->query_column_names(\@column_names);
  }

  $self->rows($self->storage()->{$self->query_table_name()}->{rows});
}

sub execute
{

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

    $ret{$query_col_name} = $row->[$index];
  }

  return \%ret;
}

sub fetchrow_hashref
{
  my $self = shift;
  return $self->_as_hashref(shift @{$self->rows()});
}

sub finish
{
  warn "FINISH()";
}

1;
