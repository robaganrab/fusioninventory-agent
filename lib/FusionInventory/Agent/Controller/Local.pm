package FusionInventory::Agent::Controller::Local;

use strict;
use warnings;
use base 'FusionInventory::Agent::Controller';

my $count = 0;

sub new {
    my ($class, %params) = @_;

    die "no path parameter" unless $params{path};

    my $self = $class->SUPER::new(%params);

    $self->{path} = $params{path};

    $self->{format} = $params{html} ? 'html' :'xml';

    $self->_init(
        id     => 'local' . $count++,
        vardir => $params{basevardir} . '/__LOCAL__',
    );

    return $self;
}

sub getPath {
    my ($self) = @_;

    return $self->{path};
}

sub _getName {
    my ($self) = @_;

    return $self->{path};
}

sub _getType {
    my ($self) = @_;

    return 'local';
}

1;

__END__

=head1 NAME

FusionInventory::Agent::Controller::Local - Local controller

=head1 DESCRIPTION

This is a local execution controller.

=head1 METHODS

=head2 new(%params)

The constructor. The following parameters are allowed, in addition to those
from the base class C<FusionInventory::Agent::Controller>, as keys of the %params
hash:

=over

=item I<path>

the output directory path (mandatory)

=back

=head2 getPath()

Return the local output directory for this target.
