#!/usr/bin/perl
# SmartFleet Server (LoxBerry-Plugin)
# Copyright (c) 2026 Michael Schlenstedt. Alle Rechte vorbehalten.
# Nutzung, Weitergabe und Veraenderung nur nach den Lizenzbedingungen,
# die diesem Programm beiliegen (LICENSE).

use strict;
use warnings;
use LoxBerry::System;
use LoxBerry::Web;
use HTML::Template;
use JSON::PP;

our %L;
my $version = LoxBerry::System::pluginversion();

my $template = LoxBerry::System::read_file("$lbptemplatedir/index.html");
my $out = HTML::Template->new_scalar_ref(\$template, global_vars => 1, die_on_bad_params => 0);
%L = LoxBerry::System::readlanguage($out, 'language.ini');

sub datei_lesen {
    my ($f) = @_;
    open my $h, '<:encoding(UTF-8)', $f or return undef;
    local $/;
    my $inhalt = <$h>;
    close $h;
    return $inhalt;
}

my $config = "$lbpdatadir/server/config.php";
if (-f $config) {
    my $cfg  = eval { JSON::PP->new->decode(datei_lesen("$lbpconfigdir/server.json") // '') } || {};
    my $ip   = LoxBerry::System::get_localip() || $cfg->{ip} || '';
    my $port = $cfg->{port} || '';
    my ($mail) = (datei_lesen($config) // '') =~ /'admin_mail'\s*=>\s*'([^']*)'/;
    $out->param(EINGERICHTET => 1, URL => "https://$ip:$port/", ADMIN_MAIL => $mail // '');
} else {
    my @fehler = grep { /<(FAIL|ERROR)>/ } split /\n/, (datei_lesen("$lbplogdir/einrichten.log") // '');
    $out->param(FEHLER => join("\n", @fehler[($#fehler > 2 ? $#fehler - 2 : 0) .. $#fehler])) if @fehler;
}

LoxBerry::Web::lbheader($L{'SFS.PLUGINTITLE'} . " V$version", 'https://smartfleetmanager.de/docs/', '', 'nojqm');
print $out->output();
LoxBerry::Web::lbfooter();
exit 0;

