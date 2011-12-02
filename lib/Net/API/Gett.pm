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

=head1 ABOUT

L<Gett|http://ge.tt> is a clutter-free file sharing service that allows its users to 
share up to 2 GB of files for free.  They recently implemented a REST API; this is a 
binding for the API. See L<http://ge.tt/developers> for full details and how to get an
API key.

=head1 ATTRIBUTES

=over 

=item api_key

Scalar string. Read-only. Required at object construction.

=back

=cut

has 'api_key' => ( 
    is        => 'ro', 
    required  => 1,
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless $_[0] =~ /[a-z0-9]+/ }
);

=over 

=item email

Scalar string. Read-only. Required at object construction.

=back

=cut

has 'email' => (
    is => 'ro',
    required => 1,
    isa => quote_sub q{ die "$_[0] is not email" unless $_[0] =~ /.+@.+/ }
);

=over

=item password

Scalar string. Read-only. Required at object construction.

=back

=cut

has 'password' => (
    is => 'ro',
    required => 1,
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless $_[0] =~ /\w+/ }
);

=over

=item access_token

Scalar string. Populated by C<login> call.

=back 

=cut

has 'access_token' => (
    is        => 'rw',
    predicate => 'has_access_token',
    isa => quote_sub q{ die "$_[0] is not alphanumeric" unless $_[0] =~ /[\w\.-]+/ }
);

=over

=item access_token_expiration

Scalar integer. Unix epoch seconds until an access token is no longer valid which is 
currently 24 hours (86400 seconds.) This value is suitable for use in a call to C<localtime()>.
C<has_access_token()> predicate.

=back

=cut

has 'access_token_expiration' => (
    is        => 'rw',
    isa => sub { die "$_[0] is not a number" unless looks_like_number $_[0] }
);

=over

=item refresh_token

Scalar string. Populated by C<login> call.  Can be used to generate a new valid
access token without reusing an email/password login method.  C<has_refresh_token()> 
predicate.

=back

=cut

has 'refresh_token' => (
    is        => 'rw',
    predicate => 'has_refresh_token',
    isa => sub { die "$_[0] is not alphanumeric" unless $_[0] =~ /[\w\.-]+/ }
);

=over

=item base_url

Scalar string. Read-only. Populated at object construction. Default value: L<https://open.ge.tt/1>. 

=back

=cut

has 'base_url' => (
    is        => 'ro',
    default   => sub { 'https://open.ge.tt/1' },
);

=over

=item ua

L<LWP::UserAgent> object. Read only. Populated at object construction. Uses a default L<LWP::UserAgent>
if not supplied.

=back

=cut

has 'ua' => (
    is => 'ro',
    default => sub { 
        my $ua = LWP::UserAgent->new(); 
        $ua->agent("Net-API-Gett/$VERSION/(Perl)"); 
        return $ua;
    },
    isa => sub { die "$_[0] is not LWP::UserAgent" unless ref($_[0])=~/UserAgent/ },
);

=over

=item user

L<Net::API::Gett::User> object. Populated by C<login> and/or C<my_user_data>. 
C<has_user()> predicate.

=back

=cut

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

=head1 METHODS

Unless otherwise noted, these methods die if an error occurs or if they get a response from the API
which is not successful. If you need to handle errors more gracefully, use L<Try::Tiny> to catch fatal 
errors.

=head2 Account methods 

=over

=item login()

This method populates the C<access_token>, C<refresh_token> and C<user> attributes.  It usually
doesn't need to be explicitly called since methods which require an access token will automatically
attempt to log in to the API and get one.

Returns a perl hash representation of the JSON output for L<https://open.ge.tt/1/users/login>.

=back

=cut

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

=over

=item my_user_data()

Retrieves (and/or refreshes) user data held in the C<user> attribute.  This method returns a
L<Net::API::Gett::User> object.

=back

=cut

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

=head2 Share functions

All of these functions cache L<Net::API::Gett::Share> objects in the C<shares> attribute. 
The cache is updated whenever calls return successfully from the API so the
local cache will be in sync with remote information about a given share as long as
no changes were made to a share outside of this library.

=over

=item get_shares()

Retrieves B<all> share information for the given user.  Takes optional scalar integers 
C<offset> and C<limit> parameters, respectively. 

Returns a list of L<Net::API::Gett::Share> objects. 

=back

=cut

sub get_shares {
    my $self = shift;
    my $offset = shift;
    my $limit = shift;

    $self->login unless $self->has_access_token;

    my $endpoint = "/shares?accesstoken=" . $self->access_token;

    if ( defined $offset && looks_like_number $offset ) {
        $endpoint .= "&skip=$offset";
    }

    if ( defined $limit && looks_like_number $limit ) {
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

=over

=item get_share()

Retrieves (and/or refreshes cached) information about a specific single share. 
Requires a C<sharename> parameter. 

Returns a L<Net::API::Gett::Share> object.

=back

=cut

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

=over

=item create_share()

This method creates a new share instance to hold files. Takes an optional string scalar
parameter which sets the share's title attribute.

Returns the new share as a L<Net::API::Gett::Share> object.

=back

=cut

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

=over

=item update_share()

This method updates share attributes.  At present, only the share title can be changed (or deleted), 
so pass in a string to set a new title for a specific share.

Calling this method with an empty parameter list or explicitly passing C<undef> 
will B<delete> any title currently set on the share.

Returns a L<Net::API::Gett:Share> object with updated values.

=back

=cut
        
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

=over

=item destroy_share()

This method destroys the specified share and all of that share's files.  Returns a true boolean
on success.

=back

=cut

sub destroy_share {
    my $self = shift;
    my $name = shift;

    $self->login unless $self->has_access_token;

    my $response = $self->_send('POST', "/shares/$name/destroy?accesstoken=".$self->access_token);

    if ( $response ) {
        delete $self->{'shares'}->{$name};
        return 1;
    }
    else {
        return undef;
    }
}

=head2 File functions

=over

=item get_file()

Returns a L<Net::API::Gett::File> object given a C<sharename> and a C<fileid>.

=back

=cut

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

=over

=item upload_file()

This method uploads a file to Gett. The following key/value pairs are valid:

=over

=item *

sharename (optional) 
    
If not specified, a new share will be automatically created.

=item *

title (optional) 
    
If specified, this value is used when creating a new share to hold the file.

=item * 

filename (required) 
    
What to call the uploaded file when it's inside of the Gett service.

=item *

content (optional) 

A representation of the file's contents.  This can be one of:

=over

=item A buffer

=item An L<IO::Handle> object

=item A FILEGLOB

=item A pathname to a file to be read

=back

If not specified, the filename parameter is used as a pathname.

=item *

encoding

An encoding scheme for the file content. By default it uses C<:raw>

=back

Returns a L<Net::API::Gett:File> object representing the uploaded file.

=back

=cut

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

=over

=item send_file()

This method actually uploads the file to the Gett service. This method is normally invoked by the
C<upload_file()> method, but it's a public method which might be useful in combination with 
C<get_new_upload_url()>. It takes the following parameters:

=over

=item * 

a PUT based Gett upload url

=item * 

a scalar representing the file contents which can be one of: a buffer, an L<IO::Handle> object, a FILEGLOB, or a 
file pathname.

=item *

an encoding scheme. By default, it uses C<:raw> (see C<perldoc -f binmode> for more information.)

=back

Returns a true value on success.

=back

=cut

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

=over

=item get_new_upload_url()

This method returns a scalar PUT upload URL for the specified sharename/fileid parameters. 
Potentially useful in combination with C<send_file()>.

=back

=cut

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

=over

=item destroy_file()

This method destroys a file specified by the given sharename/fileid parameters. Returns a true value.

=back

=cut

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

=over

=item get_file_contents()

This method retrieves the contents of a file in the Gett service given by the sharename/fileid parameters.
You are responsible for outputting the file (if desired) with any appropriate encoding.

=back

=cut

sub get_file_contents {
    my $self = shift;
    my $sharename = shift;
    my $fileid = shift;

    return $self->_file_contents("/files/$sharename/$fileid/blob");
}

=over

=item get_thumbnail()

This method returns a thumbnail if the file in Gett is an image. Requires a
sharename and fileid.

=back

=cut

sub get_thumbnail {
    my $self = shift;
    my $sharename = shift;
    my $fileid = shift;

    return $self->_file_contents("/files/$sharename/$fileid/blob/thumb");
}

=over

=item get_scaled_contents()

This method returns scaled image data (assuming the file in Gett is an image.) Requires
sharename, fileid, width and height paramters, respectively.

=back

=cut

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

=over

=item add_share()

This method populates/updates the L<Net::API::Gett:Share> object local cache.

=back

=cut

sub add_share {
    my $self = shift;
    my $share = shift;

    return undef unless ref($share) =~ /Share/;

    my $sharename = $share->sharename();

    $self->{'shares'}->{$sharename} = $share;
}

=over

=item shares()

This method retrieves one or more cached L<Net::API::Gett::Share> objects. Objects are
requested by sharename.  If no parameter list is specified, B<all> cached objects are 
returned in an unordered list. (The list will B<not> be in the order shares were added
to the cache.)

If no objects are cached, this method returns an empty list.

=back

=cut

sub shares {
    my $self = shift;

    if ( @_ ) {
        return map { $self->{'shares'}->{$_} } @_;
    }

    return () unless exists $self->{'shares'};

    return values %{ $self->{'shares'} };
}

=head1 AUTHOR

Mark Allen, C<mrallen1 at yahoo dot com>

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
