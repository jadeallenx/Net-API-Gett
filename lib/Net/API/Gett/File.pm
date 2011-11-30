package Net::API::Gett::File;

use Moo;
use Sub::Quote;
use Carp qw(croak);

has 'filename' => (
    is => 'ro',
);

has 'fileid' => (
    is => 'ro',
);

has 'downloads' => (
    is => 'ro',
);

has 'readystate' => (
    is => 'ro',
);

has 'url' => (
    is => 'ro',
);

has 'download' => (
    is => 'ro',
);

has 'size' => (
    is => 'ro',
);

has 'created' => (
    is => 'ro',
);

1;
