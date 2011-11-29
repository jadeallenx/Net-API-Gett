package Net::API::Gett;

use strict;
use warnings;

use v5.10;

use Moo;
use Sub::Quote;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common;
use Scalar::Util qw(looks_like_number);
use File::Slurp qw(read_file);
use Carp qw(croak);

use Net::API::Gett::User;
use Net::API::Gett::Share;
use Net::API::Gett::File;

BEGIN {
    require LWP::Protocol::https or die "This module requires HTTPS, please install LWP::Protocol::https\n";
}

=head1 NAME

Net::API::Gett - Perl bindings for Ge.tt API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use v5.10;
    use Net::API::Gett;

    my $gett = Net::API::Gett->new( 
        api_key      => 'GettAPIKey',
        email        => 'me@example.com',
        password     => 'mysecret',
    );

    my $file = "/some/path/name.txt";

    die "Can't read $file: $!" unless -r $file;

    my $url = $gett->share("My awesome example", $file);

    say "$file is now available at $url";

=head1 SUBROUTINES/METHODS

=cut

has 'api_key' => ( 
    is        => 'ro', 
    required  => 1,
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless /[a-z0-9]+/ }
);

has 'email' => (
    is => 'ro',
    required => 1,
    isa => quote_sub q{ die "$_[0] is not email" unless /.+@.+/ }
);

has 'password' => (
    is => 'ro',
    required => 1,
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless /\w+/ }
);

has 'access_token' => (
    is        => 'rw',
    predicate => 'has_access_token',
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless /[\w\.-]+/ }
);

has 'access_token_expiration' => (
    is        => 'rw',
    isa => quote_sub q{ die "$_[0] is not a number" unless looks_like_number($_[0]) }
);

has 'refresh_token' => (
    is        => 'rw',
    predicate => 'has_refresh_token',
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless /[\w\.-]+/ }
);

has 'base_url' => (
    is        => 'rw',
    default   => 'https://open.ge.tt/1',
);

has 'ua' => (
    is => 'rw',
    isa => quote_sub q{ die "$_[0] is not LWP::UserAgent unless ref($_[0]) =~ /LWP::UserAgent/ },
    default => quote_sub q{ 
        my $ua = LWP::UserAgent->new(); 
        $ua->user_agent("Net-API-Gett/$VERSION/(Perl)"); 
        return $ua;
    },
);

has 'user' => (
    is => 'rw',
    isa => quote_sub q{ die "$_[0] is not Net::API::Gett::User unless ref($_[0]) =~ /User/ },
);

sub _encode {
    my $self = shift;
    my $hr = shift;

    return encode_json($hr);
}

sub _decode {
    my $self = shift;
    my $json = shift;

    return decode_json($json);
}

sub _send {
    my $self = shift;
    my $method = uc shift;
    my $endpoint = shift;
    my $data = shift;
    my $headers = shift;

    my $url = $self->base_url . $endpoint;

    my $response;
    if ( $method eq "POST" ) {
        $response = $self->ua->request("POST $url", $headers, $data);
    }
    elsif ( $method eq "GET" ) {
        $response = $self->ua->request("GET $url", $headers);
    }
    elsif ( $method eq "PUT" ) {
        $response = $self->ua->request("PUT $url", $headers, $data);
    }
    else {
        croak "$method is not supported.";
    }

    if ( $response->is_success ) {
        return $self->_decode($response->content());
    }
    else {
        croak "$method $url said " . $response->status_line . "\n";
    }
}

sub _build_user {
    my $self = shift;
    my $uref = shift; # hashref https://open.ge.tt/1/doc/rest#users/me
    
    return undef unless ref($uref) eq "HASH";

    return Net::API::Gett::User->new(
        userid => $uref->{'userid'},
        fullname => $uref->{'fullname'},
        email => $uref->{'email'},
        storage_used => $uref->{'storage'}->{'used'},
        storage_limit => $uref->{'storage'}->{'limit'},
    );
}

sub login {
    my $self = shift;

    my %hr;

    @hr{'apikey', 'email', 'password'} = ( 
        $self->api_key,
        $self->email,
        $self->password);


    my $response = $self->_send('POST', '/user/login', $self->_encode(\%hr));

    # $response is a hashref
    # see https://open.ge.tt/1/doc/rest#users/login for response keys

    if ( $response ) {
        $self->access_token( $response->{'accesstoken'} );
        $self->access_token_expiration( time + $response->{'expires'} );
        $self->refreshtoken( $response->{'refreshtoken'} );
        $self->user( $self->_build_user( $response->{'user'} ) );
        return $response;
    }
    else {
        return undef;
    }
}






=head1 AUTHOR

Mark Allen, C<< <mrallen1 at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-api-gett at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-API-Gett>.  I will 
be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::API::Gett

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-API-Gett>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-API-Gett>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-API-Gett>

=item * MetaCPAN

L<https://metacpan.org/module/Net::API::Gett/>

=item * GitHub

L<https://github.com/mrallen1/Net-API-Gett>

=back

=head1 SEE ALSO

L<Gett API documentation|http://ge.tt/developers>

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Mark Allen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of Net::API::Gett
