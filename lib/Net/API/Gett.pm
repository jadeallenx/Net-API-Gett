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

    # Get API Key from http://ge.tt/developers

    my $gett = Net::API::Gett->new( 
        api_key      => 'GettAPIKey',
        email        => 'me@example.com',
        password     => 'mysecret',
    );


    my $file_obj = $gett->upload_file( 
        filename => "ossm.txt",
        contents => "/some/path/example.txt",
           title => "My Awesome File", 
        encoding => ":encoding(UTF-8)" 
    );

    say "File has been shared at " . $file_obj->url;

    my $file_contents = $gett->get_file_contents( $file_obj->sharename, 
            $file_obj->fileid );

    open my $fh, ">:encoding(UTF-8)", "/some/path/example-copy.txt" 
        or die $!;
    print $fh $file_contents;
    close $fh;

    # clean up share and file(s)
    $gett->destroy_share($file_obj->sharename);

=head1 SUBROUTINES/METHODS

=cut

has 'api_key' => ( 
    is        => 'ro', 
    required  => 1,
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless $_[0] =~ /[a-z0-9]+/ }
);

has 'email' => (
    is => 'ro',
    required => 1,
    isa => quote_sub q{ die "$_[0] is not email" unless $_[0] =~ /.+@.+/ }
);

has 'password' => (
    is => 'ro',
    required => 1,
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless $_[0] =~ /\w+/ }
);

has 'access_token' => (
    is        => 'rw',
    predicate => 'has_access_token',
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless $_[0] =~ /[\w\.-]+/ }
);

has 'access_token_expiration' => (
    is        => 'rw',
    isa => sub { die "$_[0] is not a number" unless looks_like_number $_[0] }
);

has 'refresh_token' => (
    is        => 'rw',
    predicate => 'has_refresh_token',
    isa => sub { die "$_[0] is not alphanumeric" unless $_[0] =~ /[\w\.-]+/ }
);

has 'base_url' => (
    is        => 'ro',
    default   => sub { 'https://open.ge.tt/1' },
);

has 'ua' => (
    is => 'rw',
    default => sub { 
        my $ua = LWP::UserAgent->new(); 
        $ua->agent("Net-API-Gett/$VERSION/(Perl)"); 
        return $ua;
    },
    isa => sub { die "$_[0] is not LWP::UserAgent" unless ref($_[0])=~/UserAgent/ },
);

has 'user' => (
    is => 'rw',
    predicate => 'has_user',
    isa => quote_sub q{ die "$_[0] is not Net::API::Gett::User" unless ref($_[0]) =~ /User/ },
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

    my $url = $self->base_url . $endpoint;

    my $req;
    if ( $method eq "POST" ) {
        $req = POST $url, Content => $data;
    }
    elsif ( $method eq "GET" ) {
        $req = GET $url;
    }
    else {
        croak "$method is not supported.";
    }

    my $response = $self->ua->request($req);

    if ( $response->is_success ) {
        return $self->_decode($response->content());
    }
    else {
        croak "$method $url said " . $response->status_line;
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

    my $response = $self->_send('POST', '/users/login', $self->_encode(\%hr));

    # $response is a hashref
    # see https://open.ge.tt/1/doc/rest#users/login for response keys

    if ( $response ) {
        $self->access_token( $response->{'accesstoken'} );
        $self->access_token_expiration( time + $response->{'expires'} );
        $self->refresh_token( $response->{'refreshtoken'} );
        $self->user( $self->_build_user( $response->{'user'} ) );
        return $response;
    }
    else {
        return undef;
    }
}

sub my_user_data {
    my $self = shift;

    $self->login unless $self->has_access_token;

    my $endpoint = "/users/me?accesstoken=" . $self->access_token;

    my $response = $self->_send('GET', $endpoint);

    if ( $response ) {
        $self->user( $self->_build_user($response) );
        return $self->user;
    }
    else {
        return undef;
    }
}

sub get_shares {
    my $self = shift;
    my $offset = shift;
    my $limit = shift;

    $self->login unless $self->has_access_token;

    my $endpoint = "/shares?accesstoken=" . $self->access_token;

    if ( $offset && looks_like_number $offset ) {
        $endpoint .= "&skip=$offset";
    }

    if ( $limit && looks_like_number $limit ) {
        $endpoint .= "&limit=$limit";
    }

    my $response = $self->_send('GET', $endpoint);

    if ( $response ) {
        foreach my $share_href ( @{ $response } ) {
            next unless $share_href;
            $self->add_share(
                $self->_build_share($share_href)
            );
        }
        return $self->shares;
    }
    else {
        return undef;
    }
}

sub get_share {
    my $self = shift;
    my $sharename = shift;

    return undef unless $sharename =~ /\w+/;

    my $response = $self->_send('GET', "/shares/$sharename");

    if ( $response ) {
        my $share = $self->_build_share($response);
        $self->add_share($share);
        return $share;
    }
    else {
        return undef;
    }
}

sub create_share {
    my $self = shift;
    my $title = shift;

    $self->login unless $self->has_access_token;

    my @args = ('POST', "/shares/create?accesstoken=".$self->access_token);
    if ( $title ) {
        push @args, $self->_encode({ title => $title });
    }
    my $response = $self->_send(@args);

    if ( $response ) {
        my $share = $self->_build_share($response);
        $self->add_share($share);
        return $share;
    }
    else {
        return undef;
    }
}
        
sub update_share {
    my $self = shift;
    my $name = shift;
    my $title = shift;

    $self->login unless $self->has_access_token;

    my $response = $self->_send('POST', "/shares/$name/update?accesstoken=".$self->access_token, 
            $self->_encode( { title => $title } )
    );

    if ( $response ) {
        my $share = $self->_build_share($response);
        $self->add_share($share);
        return $share;
    }
    else {
        return undef;
    }
}

sub destroy_share {
    my $self = shift;
    my $name = shift;

    $self->login unless $self->has_access_token;

    my $response = $self->_send('POST', "/shares/$name/destroy?accesstoken=".$self->access_token);

    if ( $response ) {
        return 1;
    }
    else {
        return undef;
    }
}

sub get_file {
    my $self = shift;
    my $sharename = shift;
    my $fileid = shift;

    my $response = $self->_send('GET', "/files/$sharename/$fileid");

    if ( $response ) {
        return $self->_build_file($response);
    }
    else {
        return undef;
    }
}

sub upload_file {
    my $self = shift;
    my $opts = { @_ };

    return undef unless ref($opts) eq "HASH";

    my $sharename = $opts->{'sharename'};

    if ( not $sharename ) {
        my $share = $self->create_share($opts->{'title'});
        $sharename = $share->sharename;
    }

    $self->login unless $self->has_access_token;

    my $endpoint = "/files/$sharename/create?accesstoken=".$self->access_token;
    
    my $filename = $opts->{'filename'};

    my $response = $self->_send('POST', $endpoint, $self->_encode( { filename => $filename } ));

    if ( not exists $opts->{'contents'} ) {
        $opts->{'contents'} = $filename;
    }

    if ( $response ) {
        my $file = $self->_build_file($response);
        if ( $file->readystate eq "remote" ) {
            my $put_upload_url = $file->put_upload_url;
            croak "Didn't get put upload URL from $endpoint" unless $put_upload_url;
            if ( $self->send_file($put_upload_url, $opts->{'contents'}, $opts->{'encoding'}) ) {
                return $file;
            }
            else {
                croak "There was an error reading data from " . $opts->{'contents'};
            }
        }
        else {
            croak "$endpoint doesn't have right readystate";
        }
    }
    else {
        return undef;
    }
}

sub send_file {
    my $self = shift;
    my $url = shift;
    my $contents = shift;
    my $encoding = shift || ":raw";

    my $data = read_file($contents, { binmode => $encoding });

    return 0 unless $data;

    my $response = $self->ua->request(PUT $url, Content => $data);

    if ( $response->is_success ) {
        return 1;
    }
    else {
        croak "$url said " . $response->status_line;
    }
}

sub get_new_upload_url {
    my $self = shift;
    my $sharename = shift;
    my $fileid = shift;

    $self->login unless $self->has_access_token;

    my $endpoint = "/files/$sharename/$fileid/upload?accesstoken=".$self->access_token;

    my $response = $self->_send('GET', $endpoint);

    if ( $response && exists $response->{'puturl'} ) {
        return $response->{'puturl'};
    }
    else {
        croak "Could not get a PUT url from $endpoint";
    }
}

sub destroy_file {
    my $self = shift;
    my $sharename = shift;
    my $fileid = shift;

    $self->login unless $self->has_access_token;

    my $endpoint = "/files/$sharename/$fileid/destroy?accesstoken=".$self->access_token;

    my $response = $self->_send('POST', $endpoint);

    if ( $response ) {
        return 1;
    }
    else {
        return undef;
    }
}
        
sub _file_contents {
    my $self = shift;
    my $endpoint = $self->base_url . shift;

    my $response = $self->ua->request(GET $endpoint);

    if ( $response->is_success ) {
        return $response->content();
    }
    else {
        croak "$endpoint said " . $response->status_line;
    }
}

sub get_file_contents {
    my $self = shift;
    my $sharename = shift;
    my $fileid = shift;

    return $self->_file_contents("/files/$sharename/$fileid/blob");
}

sub get_thumbnail {
    my $self = shift;
    my $sharename = shift;
    my $fileid = shift;

    return $self->_file_contents("/files/$sharename/$fileid/blob/thumb");
}

sub get_scaled_contents {
    my $self = shift;
    my ( $sharename, $fileid, $width, $height ) = @_;

    return $self->_file_contents("/files/$sharename/$fileid/blob/scale?size=$width"."x$height");
}

sub _build_share {
    my $self = shift;
    my $share_href = shift;

    my $share = Net::API::Gett::Share->new(
        sharename => $share_href->{'sharename'},
        created => $share_href->{'created'},
        title => $share_href->{'title'},
    );
    foreach my $file_href ( @{ $share_href->{'files'} } ) {
        next unless $file_href;
        $share->add_file(
            $self->_build_file($file_href)
        );
    }
    return $share;
}

sub _build_file {
    my $self = shift;
    my $file_href = shift;

    my %attrs = (
        filename => $file_href->{'filename'},
        size => $file_href->{'size'},
        created => $file_href->{'created'},
        fileid => $file_href->{'fileid'},
        downloads => $file_href->{'downloads'},
        readystate => $file_href->{'readystate'},
        url => $file_href->{'getturl'},
        download => $file_href->{'downloadurl'},
        sharename => $file_href->{'sharename'},
    );

    if ( exists $file_href->{'upload'} ) {
        @attrs{'put_upload_url', 'post_upload_url'} = (
                $file_href->{'upload'}->{'puturl'},
                $file_href->{'upload'}->{'posturl'}
        );
    }

    my $file = Net::API::Gett::File->new( %attrs );

    return $file;
}

sub add_share {
    my $self = shift;
    my $share = shift;

    return undef unless ref($share) =~ /Share/;

    my $sharename = $share->sharename();

    $self->{'shares'}->{$sharename} = $share;
}

sub shares {
    my $self = shift;

    if ( @_ ) {
        return map { $self->{'shares'}->{$_} } @_;
    }

    return () unless exists $self->{'shares'};

    return values %{ $self->{'shares'} };
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
