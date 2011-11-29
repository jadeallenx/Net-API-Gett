package Net::API::Gett::User;

use Moo;
use Sub::Quote;
use Carp qw(croak);

has 'userid' => (
    is => 'ro',
    isa => quote_sub q{ croak "$_[0] isn't alphanumeric\n" unless $_[0] =~ /[\w-]+/ },
);

has 'fullname' => (
    is => 'ro',
);

has 'email' => (
    is => 'ro',
);

has 'storage_used' => (
    is => 'ro',
);

has 'storage_limit' => (
    is => 'ro',
);

1;
