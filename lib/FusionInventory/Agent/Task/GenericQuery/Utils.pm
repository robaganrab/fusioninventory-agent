package FusionInventory::Agent::Task::GenericQuery::Utils;

use Data::Dumper;
use File::Find;
use File::stat;

sub find {
    my (%params) = @_;
    my @ret;

use Data::Dumper;
print Dumper(%params);

    my $where = $params{where} or return; 

    File::Find::find(
    {
        wanted => sub {
            next if $params{exclude_dir} && -d $File::Find::name;
            next if $params{exclude_file} && -f $File::Find::name;


#            next if $params{ $e->
#            my $e = stat();
#            print  $File::Find::name."\n";
        

        },
        no_chdir => 1
    },
    $where
    );



}

1;
