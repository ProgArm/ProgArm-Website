#!/usr/bin/perl -T
use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

$CGI::POST_MAX = 1024 * 100000;
my $filenameWhitelist = "a-zA-Z0-9_.-";
my @additionalChars = ('A'..'Z', 'a'..'z', '0'..'9');
my $uploadDir = "../u";
my $logFile = "../upload.log";

my $query = new CGI;

print $query->header();
if (!$query->param("fileToUpload0")) {
    print "Error: There was a problem uploading your file (try a smaller file).";
    exit;
}

for (my $i=0; $query->param("fileToUpload$i"); $i++) {
    if ($i >= 100) { # Uploading more than 100 files? What?
        print "Error: Cannot upload more than 100 files at once";
        exit;
    }

    my $curFilename = substr $query->param("fileToUpload$i"), -100;

    my($name, $path, $extension) = fileparse($curFilename, '\..*');
    $name =~ tr/ /_/;
    $name =~ s/[^$filenameWhitelist]//g;
    $extension =~ tr/ /_/;
    $extension =~ s/[^$filenameWhitelist]//g;

    $curFilename = $name . $extension;

    while (-e "$uploadDir/$curFilename") {
        if (length $curFilename >= 150) {
            print "Error: Cannot save file";
            exit;
        }
        $name .= $additionalChars[rand @additionalChars];
        $curFilename = $name . $extension;
    }

    if ($curFilename =~ /^([$filenameWhitelist]+)$/) { # data is already safe, but we have to untaint it
        $curFilename = $1;
    } else {
        print "Error: Filename contains invalid characters";
        exit;
    }

    my $rhost = $ENV{REMOTE_HOST}; # tests are written to avoid -w warnings.
    if (not $rhost and $ENV{REMOTE_ADDR}) {
        # Catch errors (including bad input) without aborting the script
        eval 'use Socket; my $iaddr = inet_aton($ENV{REMOTE_ADDR});'
            . '$rhost = gethostbyaddr($iaddr, AF_INET) if $iaddr;';
    }
    if (! $rhost) {
        $rhost = $ENV{REMOTE_ADDR};
    }

    open(LOGFILE, ">>", $logFile) or die "$!";
    print LOGFILE $rhost . '; ' . $curFilename . "\n";
    close LOGFILE;

    my $uploadFileHandle = $query->upload("fileToUpload$i");

    open(UPLOADFILE, ">", "$uploadDir/$curFilename") or die "$!";
    binmode UPLOADFILE;
    while (<$uploadFileHandle>) {
        print UPLOADFILE;
    }
    close UPLOADFILE;
    print "$curFilename\n"
}
