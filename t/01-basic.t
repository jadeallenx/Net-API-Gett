#!/usr/bin/perl

use strict;
use Test::More;

if (!eval { require Socket; Socket::inet_aton('open.ge.tt') }) {
    plan skip_all => "Cannot connect to the API server";
} 
else {
    plan tests => 12;
}

use Net::API::Gett;

# doesn't require auth
# get_share()
# get_file()
# get_file_content()

my $gett = Net::API::Gett->new(
    api_key => "fake",
    email => 'me@example.com',
    password => 'fake',
);

isa_ok($gett, 'Net::API::Gett', "Gett object constructed");

my $share = $gett->get_share("928PBdA");

isa_ok($share, 'Net::API::Gett::Share', "share object constructed");

is($share->sharename, "928PBdA", "got share name");
is($share->created, "1322847473", "got share created");
like($share->title, qr/Test/, "got share title");
is(scalar $share->files, 2, "got 2 files");

my $file = $gett->get_file("928PBdA", 0); #hello.c

isa_ok($file, 'Net::API::Gett::File', "file object constructed");

is($file->created, 1322847473, "got file created");
is($file->fileid, 0, "got fileid");
is($file->filename, "hello.c", "got filename");

my $contents = $gett->get_file_contents("928PBdA", 0);

like($contents, qr/Hello world/, "Got hello.c content");
is(length($contents), $file->size, "file content size matches file object");
