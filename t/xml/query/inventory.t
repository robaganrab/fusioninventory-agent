#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Test::Deep;
use Test::Exception;
use Test::More;
use XML::TreePP;

use FusionInventory::Agent::Inventory;
use FusionInventory::Agent::XML::Query::Inventory;

plan tests => 5;

my $query;
throws_ok {
    $query = FusionInventory::Agent::XML::Query::Inventory->new();
} qr/^no content/, 'no content';

my $inventory =  FusionInventory::Agent::Inventory->new();
lives_ok {
    $query = FusionInventory::Agent::XML::Query::Inventory->new(
        deviceid => 'foo',
        content  => $inventory->getContent()
    );
} 'everything OK';

isa_ok($query, 'FusionInventory::Agent::XML::Query::Inventory');

my $tpp = XML::TreePP->new();

cmp_deeply(
    scalar $tpp->parse($query->getContent()),
    {
        REQUEST => {
            DEVICEID => 'foo',
            QUERY    => 'INVENTORY',
            CONTENT  => {
                HARDWARE => {
                    ARCHNAME => $Config{archname},
                    VMSYSTEM => 'Physical'
                },
                VERSIONCLIENT => $FusionInventory::Agent::AGENT_STRING,
            },
        }
    },
    'empty inventory, expected content'
);

$inventory->addEntry(
    section => 'SOFTWARES',
    entry   => {
        NAME => '<&>',
    }
);

$query = FusionInventory::Agent::XML::Query::Inventory->new(
    deviceid => 'foo',
    content => $inventory->getContent()
);

cmp_deeply(
    scalar $tpp->parse($query->getContent()),
    {
        REQUEST => {
            DEVICEID => 'foo',
            QUERY => 'INVENTORY',
            CONTENT => {
                HARDWARE => {
                    ARCHNAME => $Config{archname},
                    VMSYSTEM => 'Physical'
                },
                VERSIONCLIENT => $FusionInventory::Agent::AGENT_STRING,
                SOFTWARES => {
                    NAME => '<&>'
                }
            },
        }
    },
    'additional content with prohibited characters, expected content'
);
