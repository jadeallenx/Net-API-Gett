package Net::API::Gett::Share;

use Moo;
use Sub::Quote;
use Carp qw(croak);

has 'sharename' => (
    is => 'ro',
);

has 'title' => (
    is => 'ro',
);

has 'created' => (
    is => 'ro',
);

sub add_file {
    my $self = shift;
    my $file = shift;

    return undef unless ref($file) =~ /File/;

    push @{ $self->{'files'} }, $file;
}

sub files {
    my $self = shift;

    return () unless exists $self->{'files'};

    return @{ $self->{'files'} };
}

1;
