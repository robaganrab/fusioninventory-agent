package FusionInventory::Agent::Task::GenericQuery;

use strict;
use warnings;
use base 'FusionInventory::Agent::Task';

use FusionInventory::Agent::Config;
use FusionInventory::Agent::HTTP::Client::Fusion;
use FusionInventory::Agent::Logger;
use FusionInventory::Agent::Task::Inventory::Inventory;
use FusionInventory::Agent::XML::Query::Inventory;
use FusionInventory::VMware::SOAP;
use UNIVERSAL::require;
use English qw(-no_match_vars);

our $VERSION = "0.0.1";

sub isEnabled {
    my ($self) = @_;

    return $self->{target}->isa('FusionInventory::Agent::Target::Server');
}

sub run {
    my ( $self, %params ) = @_;

    $self->{logger}->debug("FusionInventory GenericQuery $VERSION");
    my $remoteURL = $params{remoteURL};

    $self->{client} = FusionInventory::Agent::HTTP::Client::Fusion->new(
        logger       => $self->{logger},
        user         => $params{user},
        password     => $params{password},
        proxy        => $params{proxy},
        ca_cert_file => $params{ca_cert_file},
        ca_cert_dir  => $params{ca_cert_dir},
        no_ssl_check => $params{no_ssl_check},
        debug        => $self->{debug}
    );
    die unless $self->{client};


    # Transition OCS/XML → REST/JSON
    if ( !$remoteURL ) {
        my $globalRemoteConfig = $self->{client}->send(
            "url" => $self->{target}->{url},
            args  => {
                action    => "getConfig",
                machineid => $self->{deviceid},
                task      => { ESX => $VERSION },
            }
        );

        return unless $globalRemoteConfig->{schedule};
        return unless ref( $globalRemoteConfig->{schedule} ) eq 'ARRAY';

        foreach my $job ( @{ $globalRemoteConfig->{schedule} } ) {
            next unless $job->{task} eq "ESX";
            $remoteURL = $job->{remote};
        }
        if ( !$remoteURL ) {
            $self->{logger}->info("Nothing to do.");
            return;
        }
    }

    my $jobs = $self->{client}->send(
        "url" => $remoteURL,
        args  => {
            action    => "getJobs",
            machineid => $self->{deviceid}
        }
    );
    use Data::Dumper;
    print Dumper($jobs);

    return unless $jobs;
    return unless ref( $jobs ) eq 'ARRAY';
    $self->{logger}->info(
        "Got " . int( @$jobs ) . " Actions to do." );

    JOB:
    foreach my $job ( @$jobs ) {
        foreach (qw/module function/) {
            next if $job->{$_} =~ /^[A-Za-z\d]+$/;
            $self->{logger}->error("receive bad data from server");
            next JOB;
        }

        my $module = sprintf(
                "%s::%s",
                __PACKAGE__,
                $job->{module});

        eval {
            $module->require() or die;
        };
        $self->{logger}->error($EVAL_ERROR) if $EVAL_ERROR;

        my $f = $module."::".$job->{function};
        eval {
            no strict 'refs';
            &$f(%{$job->{params}});
        };
        $self->{logger}->error($EVAL_ERROR) if $EVAL_ERROR;



    }

    return $self;
}

1;
