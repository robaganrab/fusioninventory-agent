package FusionInventory::Agent::Task::Inventory::OS::Win32::Bios;

use strict;
use warnings;

use constant KEY_WOW64_64KEY => 0x100;

use English qw(-no_match_vars);
use Win32::TieRegistry (
    Delimiter   => '/',
    ArrayValues => 0,
    qw/KEY_READ/
);

# Only run this module if dmidecode has not been found
our $runMeIfTheseChecksFailed = ["FusionInventory::Agent::Task::Inventory::OS::Generic::Dmidecode::Bios"];

use FusionInventory::Agent::Task::Inventory::OS::Win32;

sub isInventoryEnabled {
    return 1;
}

sub getBiosInfoFromRegistry {
    my ($logger) = @_;

    my $machKey= $Registry->Open('LMachine', {
        Access=> KEY_READ | KEY_WOW64_64KEY
    }) or $logger->fault("Can't open HKEY_LOCAL_MACHINE key: $EXTENDED_OS_ERROR");

    my $data =
        $machKey->{"Hardware/Description/System/BIOS"};

    my $info;

    foreach my $tmpkey (%$data) {
        next unless $tmpkey =~ /^\/(.*)/;
        my $key = $1;

        $info->{$key} = $data->{$tmpkey};
    }

    return $info;
}




sub doInventory {
    my $params = shift;
    my $inventory = $params->{inventory};

    my $smodel;
    my $smanufacturer;
    my $ssn;
    my $enclosureSerial;
    my $baseBoardSerial;
    my $biosSerial;
    my $bdate;
    my $bversion;
    my $bmanufacturer;
    my $mmanufacturer;
    my $msn;
    my $mmodel;
    my $assettag;


    my $registryInfo = getBiosInfoFromRegistry();

    $bdate = $registryInfo->{BIOSReleaseDate};

    foreach my $Properties (getWmiProperties('Win32_Bios', qw/
        SerialNumber Version Manufacturer SMBIOSBIOSVersion BIOSVersion
    /)) {
        $biosSerial = $Properties->{SerialNumber};
        $ssn = $Properties->{SerialNumber} unless $ssn;
        $bmanufacturer = $Properties->{Manufacturer} unless $bmanufacturer;
        $bversion = $Properties->{SMBIOSBIOSVersion} unless $bversion;
        $bversion = $Properties->{BIOSVersion} unless $bversion;
        $bversion = $Properties->{Version} unless $bversion;
    }

    foreach my $Properties (getWmiProperties('Win32_ComputerSystem', qw/
        Manufacturer Model
    /)) {
        $smanufacturer = $Properties->{Manufacturer} unless $smanufacturer;
        $smodel = $Properties->{Model} unless $smodel;
    }

    foreach my $Properties (getWmiProperties('Win32_SystemEnclosure', qw/
        SerialNumber SMBIOSAssetTag
    /)) {
        $enclosureSerial = $Properties->{SerialNumber} ;
        $ssn = $Properties->{SerialNumber} unless $ssn;
        $assettag = $Properties->{SMBIOSAssetTag} unless $assettag;
    }

    foreach my $Properties (getWmiProperties('Win32_BaseBoard', qw/
        SerialNumber Product Manufacturer
    /)) {
        $baseBoardSerial = $Properties->{SerialNumber};
        $ssn = $Properties->{SerialNumber} unless $ssn;
        $mmodel = $Properties->{Product} unless $mmodel;
        $smanufacturer = $Properties->{Manufacturer} unless $smanufacturer;

    }

    $inventory->setBios({
        SMODEL => $smodel,
        SMANUFACTURER =>  $smanufacturer,
        SSN => $ssn,
        BDATE => $bdate,
        BVERSION => $bversion,
        BMANUFACTURER => $bmanufacturer,
        MMANUFACTURER => $mmanufacturer,
        MSN => $msn,
        MMODEL => $mmodel,
        ASSETTAG => $assettag,
        ENCLOSURESERIAL => $enclosureSerial,
        BASEBOARDSERIAL => $baseBoardSerial,
        BIOSSERIAL => $biosSerial,
    });

    my $vmsystem;
# it's more reliable to do a regex on the CPU NAME
# QEMU Virtual CPU version 0.12.4
#    if ($bmanufacturer eq 'Bochs' || $mmodel eq 'Bochs') {
#        $vmsystem = 'QEMU';
#    } els
    if ($smanufacturer eq 'Xen' || $bmanufacturer eq 'Xen') {
        $vmsystem = 'Xen';
    } elsif ($bversion eq 'VirtualBox' || $mmodel eq 'VirtualBox') {
        $vmsystem = 'VirtualBox';
    } elsif ($smodel =~  /VMware/i) {
        $vmsystem = 'VMware';
    } elsif ($biosSerial =~  /VMware/i) {
        $vmsystem = 'VMware';
    }

    if ($vmsystem) {
        $inventory->setHardware ({
            VMSYSTEM => $vmsystem 
        });
    }

}

1;