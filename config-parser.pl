#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use YAML::Tiny;

if ($#ARGV+1 != 1) {
    print "Usage: $0 input.yaml\n";
    exit 1;
}

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

my $input = YAML::Tiny->read($ARGV[0]) or die "Cannot read input config!";
$input = $input->[0];

my $config = YAML::Tiny->new;

for my $entry (@$input) {
    for my $cert (@{$entry->{cert}}) {
        push @$config, { $cert => {
            server => ($entry->{server}),
            format => $entry->{format},
        }};
    }
}

$config->write($main_config->{config_file}) or die "Cannot write config file!";
