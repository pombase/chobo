use strict;
use warnings;
use Test::More tests => 3;
use Test::Deep;

use lib qw(t/lib);

use ChoboTest::FakeHandle;

my $fake_handle = ChoboTest::FakeHandle->new();

my $sth = $fake_handle->prepare("select cvterm_id, name, cv_id from cvterm");

is ($sth->query_table_name(), 'cvterm');

my $row_1 = $sth->fetchrow_hashref();
cmp_deeply($row_1, { cvterm_id => 400, name => 'is_a', cv_id => 300 });

my $row_2 = $sth->fetchrow_hashref();
is($row_2, undef);

