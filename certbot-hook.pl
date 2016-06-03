#!/usr/bin/env perl

=head1 NAME

certbot-hook -- Hook for copying Let's encrypt certificates

=cut

use utf8;
use strict;
use warnings;

use Pod::Usage;
use YAML::Tiny;
use File::Spec;
use File::Temp;
use Net::OpenSSH;
use Getopt::Long qw/:config auto_version auto_help/;

our $VERSION = 1.0;
my $verbose = 0;

GetOptions(
    'verbose|v'     => \$verbose,
) or pod2usage(2);


=head1 SYNOPSIS

certbot-hook.pl [ OPTIONS ]

  Options:
    --man
    --help|-h
    --verbose|-v

=cut

my @config_path = (
    "./certbot-hook.yaml",
    "/etc/letsencrypt/certbot-hook.yaml",
);

my $main_config;
foreach my $path (@config_path) {
    $main_config = YAML::Tiny->read($path) and last;
}

die "Cannot read main config file!" unless defined $main_config;
$main_config = $main_config->[0];

my $config = YAML::Tiny->read($main_config->{config_file}) or die "Cannot read config file!";
{
    my %config = ();
    %config = (%config, %$_) for (@$config);
    $config = \%config;
}

# Main hook
sub install {
    my ($live_dir, $cert, $config) = @_;
    print "Installing certificate $cert\n" if $verbose;
    # Create source files
    my $format = $config->{format};
    my $dir = File::Temp->newdir;
    my %files;
    for my $file (keys %{$main_config->{formats}->{$format}->{files}}) {
        print "Creating $file\n" if $verbose;
        $files{$file} = {
            source => File::Spec->catfile($dir->dirname, $file),
            target => File::Spec->catfile(
                $main_config->{formats}->{$format}->{files}->{$file}->{path},
                $cert.$main_config->{formats}->{$format}->{files}->{$file}->{ext}
            ),
        };
        open (my $fh, ">", $files{$file}->{source});
        for my $source (@{$main_config->{formats}->{$format}->{files}->{$file}->{source}}) {
            print "Concatening $source\n" if $verbose;
            open (my $in, "<", File::Spec->catfile($live_dir,$source)) or die "Cannot open $source!";
            while (<$in>) {
                print $fh $_;
            }
            close $in;
        }
        close $fh;
    }
    # Copy files to server
    for my $server (@{$config->{server}}) {
        print "Connecting to $server\n" if $verbose;
        my $ssh = Net::OpenSSH->new(host => $server, user => $main_config->{ssh_user}, batch_mode => 1, key_path => $main_config->{key_file});
        $ssh->error and die "Error: Cannot connect to $server: ".$ssh->error."\n";
        # Call pre hook
        if (defined $main_config->{formats}->{$format}->{cmd_pre}) {
            print "Calling command '".$main_config->{formats}->{$format}->{cmd_pre}."'\n" if $verbose;
            $ssh->system({stderr_discard => ($verbose?0:1), stdout_discard => ($verbose?0:1)}, $main_config->{formats}->{$format}->{cmd_pre}) or print "Warning: Command not successful: ".$ssh->error."\n";
        }
        for (keys %files) {
            print "Copying ".$files{$_}->{source}." to ".$server.":".$files{$_}->{target}."\n" if $verbose;
            $ssh->scp_put($files{$_}->{source}, $files{$_}->{target}) or print "Warning: Cannot copy file: ".$ssh->error."\n";
        }
        # Call post hook
        if (defined $main_config->{formats}->{$format}->{cmd_post}) {
            print "Calling command '".$main_config->{formats}->{$format}->{cmd_post}."'\n" if $verbose;
            $ssh->system({stderr_discard => ($verbose?0:1), stdout_discard => ($verbose?0:1)}, $main_config->{formats}->{$format}->{cmd_post}) or print "Warning: Command not successful: ".$ssh->error."\n";
        }
        $ssh->stop;
    }
}

# Basic check
if (not defined $ENV{RENEWED_LINEAGE}) {
    print "Warning: No certificate renewed!\n";
    exit 5;
}
# Get directory with certificate
my $live_dir = $ENV{RENEWED_LINEAGE};
-d $live_dir or die "Directory $live_dir not found!";
# Parse main domain name (config key)
my @directories = grep /^..*$/, File::Spec->splitdir($live_dir);
my $cert = $directories[-1];
if (not defined $config->{$cert}) {
    print "Warning: Missing config for $cert, cannot install certificate!\n";
    exit 10;
}
# Run hook
install $live_dir, $cert, $config->{$cert};
exit 0;
