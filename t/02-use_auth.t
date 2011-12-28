#!/usr/bin/perl

use strict;
use Test::More;

if (!eval { require Socket; Socket::inet_aton('open.ge.tt') }) {
    plan skip_all => "Cannot connect to the API server";
} 
elsif ( ! $ENV{GETT_API_KEY} || ! $ENV{GETT_EMAIL} || ! $ENV{GETT_PASSWORD} ) {
    plan skip_all => "API credentials required for these tests";
}
else {
    plan tests => 10;
}

use Net::API::Gett;

my $gett = Net::API::Gett->new(
    api_key  => $ENV{GETT_API_KEY},
    email    => $ENV{GETT_EMAIL},
    password => $ENV{GETT_PASSWORD},
);

isa_ok($gett, 'Net::API::Gett', "Gett object constructed");
isa_ok($gett->request, 'Net::API::Gett::Request', "Gett request constructed");

isa_ok($gett->user, 'Net::API::Gett::User', "Gett User object constructed");
is($gett->user->has_access_token, 1, "Has access token");

# Upload a file, download its contents, then destroy the share and the file
my $file = $gett->upload_file(
    filename => "test.t",
    content => "t/00-load.t",
    title => "perltest",
);

isa_ok($file, 'Net::API::Gett::File', "File uploaded");

is($file->filename, "test.t", "Got right filename");
is($file->size, 178, "Got right filesize");

my $content = $file->contents();

like($content, qr/use_ok/, "Got right file content");

my $share = $gett->get_share( $file->sharename );

is($share->title, "perltest", "Got right share title");

is($share->destroy(), 1, "Share destroyed");
