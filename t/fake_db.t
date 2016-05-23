use strict;
use warnings;
use Test::More tests => 12;
use Test::Deep;

use lib qw(t/lib);

use ChoboTest::FakeHandle;

my $fake_dbh = ChoboTest::FakeHandle->new();


my $sth = $fake_dbh->prepare("select cvterm_id, name, cv_id from cvterm");
is ($sth->query_table_name(), 'cvterm');

my $row_1 = $sth->fetchrow_hashref();
cmp_deeply($row_1, { cvterm_id => 400, name => 'is_a', cv_id => 300 });

my $row_2 = $sth->fetchrow_hashref();
is($row_2, undef);


$fake_dbh->do('COPY db(name) FROM STDIN CSV');
$fake_dbh->pg_putcopydata("test_db\n");
$fake_dbh->pg_putcopyend();

$sth = $fake_dbh->prepare("select db_id, name from db");
is ($sth->query_table_name(), 'db');

$row_1 = $sth->fetchrow_hashref();
cmp_deeply($row_1, { db_id => 100, name => 'core' });
$row_1 = $sth->fetchrow_hashref();
cmp_deeply($row_1, { db_id => 101, name => 'test_db' });
$row_2 = $sth->fetchrow_hashref();
is($row_2, undef);


$fake_dbh->do('COPY dbxref(accession, db_id) FROM STDIN CSV');
$fake_dbh->pg_putcopydata("test_dbref_1,101");
$fake_dbh->pg_putcopydata("test_dbref_2,101");
$fake_dbh->pg_putcopyend();


$sth = $fake_dbh->prepare("select dbxref_id, accession, db_id from dbxref");
is ($sth->query_table_name(), 'dbxref');

$row_1 = $sth->fetchrow_hashref();
cmp_deeply($row_1, { dbxref_id => 200, accession => 'is_a', db_id => 100 });

$row_2 = $sth->fetchrow_hashref();
cmp_deeply($row_2, { dbxref_id => 201, accession => 'test_dbref_1', db_id => 101 });

my $row_3 = $sth->fetchrow_hashref();
cmp_deeply($row_3, { dbxref_id => 202, accession => 'test_dbref_2', db_id => 101 });

my $row_4 = $sth->fetchrow_hashref();
is($row_4, undef);
