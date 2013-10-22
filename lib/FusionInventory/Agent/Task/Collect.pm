package FusionInventory::Agent::Task::Collect;

use strict;
use warnings;
use base 'FusionInventory::Agent::Task';

use FusionInventory::Agent::HTTP::Client::Fusion;
use FusionInventory::Agent::Logger;
use FusionInventory::Agent::Tools;

use English qw(-no_match_vars);
use File::Find;
use File::stat;
use File::Basename;
use Digest::SHA;

our $VERSION = $FusionInventory::Agent::VERSION;

sub isEnabled {
    my ($self) = @_;

    return
        $self->{controller}->isa('FusionInventory::Agent::Controller::Server');
}

sub _getFromRegistry {
    my %params = @_;

    return unless FusionInventory::Agent::Tools::Win32->require();

    my $values = FusionInventory::Agent::Tools::Win32::getRegistryValues(path => $params{path});

    return unless $values;

    my $result;
    if (ref($values) eq 'HASH') { # I don't like that. We should always get href
        foreach my $k (keys %$values) {
            my $v = FusionInventory::Agent::Tools::Win32::encodeFromRegistry($values->{$k});
            $result->{$k}=$v;
        }
    }

    return ($result);
}

sub _findFile {
    my %params = (
        dir => '/',
        limit => 50
        , @_);

    return unless -d $params{dir};

    my @result;

    File::Find::find(
        {
            wanted => sub {
#                    print $File::Find::name."\n";
#
                if (!$params{recursive} && $File::Find::name ne $params{dir}) {
                    $File::Find::prune = 1  # Don't recurse.
                }


                if (   $params{filter}{is_dir}
                    && !$params{filter}{checkSumSHA512}
                    && !$params{filter}{checkSumSHA2} )
                {
                    return unless -d $File::Find::name;
                }

                if ( $params{filter}{is_file} ) {
                    return unless -f $File::Find::name;
                }

                my $filename = basename($File::Find::name);

                if ( $params{filter}{name} ) {
                    return if $filename ne $params{filter}{name};
                }

                if ( $params{filter}{iname} ) {
                    return if lc($filename) ne lc( $params{filter}{iname} );
                }

                if ( $params{filter}{regex} ) {
                    my $re = qr($params{filter}{regex});
                    return unless $File::Find::name =~ $re;
                }

                my $st   = stat($File::Find::name);
                my $size = $st->size;
#                print "name: $File::Find::name\n";
                if ( $params{filter}{sizeEquals} ) {
                    return unless $size == $params{filter}{sizeEquals};
                }

                if ( $params{filter}{sizeGreater} ) {
                    return if $size < $params{filter}{sizeGreater};
                }

                if ( $params{filter}{sizeLower} ) {
                    return if $size > $params{filter}{sizeLower};
                }

                if ( $params{filter}{checkSumSHA512} ) {
                    my $sha = Digest::SHA->new('512');
                    $sha->addfile( $File::Find::name, 'b' );
                    return
                      if $sha->hexdigest ne $params{filter}{checkSumSHA512};
                }

                if ( $params{filter}{checkSumSHA2} ) {
                    my $sha = Digest::SHA->new('2');
                    $sha->addfile( $File::Find::name, 'b' );
                    return if $sha->hexdigest ne $params{filter}{checkSumSHA2};
                }

                push @result,
                  {
                    size => $size,
                    path => $File::Find::name
                  };
                goto DONE if @result >= $params{limit};
            },
            no_chdir => 1

        },
        $params{dir}
    );
  DONE:

    return @result;
}

sub _runCommand {
    my %params = @_;

    my $line;

    if ( $params{filter}{firstMatch} ) {
        $line = getFirstMatch(
            command => $params{command},
            pattern => $params{filter}{firstMatch}
        );
    }
    elsif ( $params{filter}{firstLine} ) {
        $line = getFirstLine( command => $params{command} );

    }
    elsif ( $params{filter}{lineCount} ) {
        $line = getLinesCount( command => $params{command} );
    }
    else {
        $line = getAllLines( command => $params{command} );

    }

    return ( { output => $line } );
}

sub _getFromWMI {
    my %params = @_;

    return unless FusionInventory::Agent::Tools::Win32->require();

    return unless $params{properties};
    return unless $params{class};

    my @return;

    my @objs = FusionInventory::Agent::Tools::Win32::getWMIObjects(%params);
    return unless @objs;

    foreach my $obj (@objs) {
        push @return, $obj; 
    }

    return @return;
}


my %functions = (
    getFromRegistry => \&_getFromRegistry,
    findFile        => \&_findFile,
# As decided by the FusInv-Agent developers, the runCommand function
# is disabled for the moment.
#    runCommand      => \&_runCommand,
    getFromWMI      => \&_getFromWMI
);

sub run {
    my ( $self, %params ) = @_;

    $self->{logger}->debug("FusionInventory Collect task $VERSION");

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

    my $globalRemoteConfig = $self->{client}->send(
        "url" => $self->{controller}->{url},
        args  => {
            action    => "getConfig",
            machineid => $self->{deviceid},
            task      => { Collect => $VERSION },
        }
    );

    return unless $globalRemoteConfig->{schedule};
    return unless ref( $globalRemoteConfig->{schedule} ) eq 'ARRAY';

    foreach my $job ( @{ $globalRemoteConfig->{schedule} } ) {
        next unless $job->{task} eq "Collect";
        $self->{collectRemote} = $job->{remote};
    }
    if ( !$self->{collectRemote} ) {
        $self->{logger}->info("Collect support disabled server side.");
        return;
    }

    my $jobs = $self->{client}->send(
        "url" => $self->{collectRemote},
        args  => {
            action    => "getJobs",
            machineid => $self->{deviceid}
        }
    );

    return unless $jobs;
    return unless ref($jobs) eq 'ARRAY';

    $self->{logger}->info( "Got " . int( @{$jobs} ) . " collect order(s)." );

    foreach my $job (@$jobs) {
        if ( !$job->{uuid} ) {
            $self->{logger}->error("UUID key missing");
            next;
        }

        if ( !defined( $functions{ $job->{function} } ) ) {
            $self->{logger}->error("Bad function `$job->{function}'");
            next;
        }

        my @result = &{ $functions{ $job->{function} } }(%$job);

        next unless @result;

        my $cpt = int(@result);
        foreach my $r (@result) {
            next unless ref($r) eq 'HASH';
            next unless keys %$r;
            $r->{uuid}   = $job->{uuid};
            $r->{action} = "setAnswer";
            $r->{cpt}    = $cpt--;
            $self->{client}->send(
                url  => $self->{collectRemote},
                args => $r
            );

        }

    }

    return $self;
}

1;
