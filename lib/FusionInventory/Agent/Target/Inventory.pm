package FusionInventory::Agent::Target::Inventory;

use strict;
use warnings;

use UNIVERSAL::require;

sub create {
    my ($class, %params) = @_;

    my $target = $params{target};
    my $output_class =
        !defined $target         ? 'FusionInventory::Agent::Target::Inventory::Stdout'    :
        $target =~ m{^https?://} ? 'FusionInventory::Agent::Target::Inventory::Server'    :
        -d $target               ? 'FusionInventory::Agent::Target::Inventory::Filesystem':
                                   undef                                       ;

    die "invalid target $target" unless $output_class;
    $output_class->require();

    return $output_class->new(%params);
}

1;
