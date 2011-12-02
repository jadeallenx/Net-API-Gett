package Net::API::Gett::Share;

=head1 NAME

Net::API::Gett::Share - Gett share object

=cut

use Moo;
use Sub::Quote;
use Carp qw(croak);

=head1 ATTRIBUTES

These are read only attributes.  You normally shouldn't instantiate this class on its own, as the
library will create and return this object as appropriate.

=over 

=item sharename

Scalar string.

=item title

Scalar string.

=item created 

Scalar integer. This value is in Unix epoch seconds, suitable for use in a call to C<localtime()>.

=item files

This attribute holds any L<Net::API::Gett:File> objects linked to a particular 
share instance. It returns a list of L<Net::API::Gett:File> objects if 
there are any, otherwise returns an empty list.

=back

=cut

has 'sharename' => (
    is => 'ro',
);

has 'title' => (
    is => 'ro',
);

has 'created' => (
    is => 'ro',
);

=head1 METHODS

=over

=item add_file()

This method stores a new L<Net::API::Gett::File> object in the share object.
It returns undef if the value passed is not an L<Net::API::Gett::File> object.

=back

=cut

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

=head1 SEE ALSO

L<Net::API::Gett>

=cut

1;
