package Net::API::Gett::File;

=head1 NAME

Net::API::Gett::File - Gett file object

=cut

use Moo;
use Sub::Quote;
use Carp qw(croak);

=head1 ATTRIBUTES

These are read only attributes. 

You normally shouldn't instantiate this class on its own, as the library will create and return this
object as appropriate.

=over 

=item filename

Scalar string

=item fileid

Scalar integer

=item downloads

Scalar integer. The number of times this particular file has been downloaded

=item readystate

Scalar string. Signifies the state a particular file is in. See the 
L<Gett developer docs|http://ge.tt/developers> for more information.

=item url

Scalar string. The URL to use in a browser to access a file

=item download

Scalar string. The URL to use to get the file contents.

=item size

Scalar integer. The size in bytes of this file.

=item created

Scalar integer. The Unix epoch time when this file was created in Gett. This value is suitable
for use in C<localtime()>.

=item sharename

Scalar string.  The share in which this file lives inside.

=item put_upload_url

Scalar string.  The url to use to upload the contents of this file using the PUT method. (This
method is only populated during certain times.)

=item post_upload_url

Scalar string. This url to use to upload the contents of this file using the POST method. (This
method is only populated during certain times.)

=back

=cut

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

has 'sharename' => (
    is => 'ro',
);

has 'put_upload_url' => (
    is => 'ro',
);

has 'post_upload_url' => (
    is => 'ro',
);

=head1 SEE ALSO

L<Net::API::Gett>

=cut

1;
