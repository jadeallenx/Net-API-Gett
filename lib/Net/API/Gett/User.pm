package Net::API::Gett::User;

use Moo;
use Sub::Quote;
use Carp qw(croak);

=head1 NAME

Net::API::Gett::User - Gett User object

=head1 ATTRIBUTES

These are read only attributes. You normally shouldn't instanstiate this class on its own as
the library will create and return this object when appropriate.

=over

=item userid

Scalar string.

=item fullname

Scalar string.

=item email

Scalar string.

=item storage_used

Scalar integer. In bytes.

=item storage_limit

Scalar integer. In bytes.

=back

=head1 SEE ALSO

L<Net::API::Gett>

=cut

has 'userid' => (
    is => 'ro',
    isa => sub { croak "$_[0] isn't alphanumeric\n" unless $_[0] =~ /[\w-]+/ },
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

