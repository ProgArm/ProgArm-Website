#!/usr/bin/perl -T
use strict;
use v5.10;
use CGI;
#use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

$CGI::POST_MAX = 1024 * 100000;
my $filenameWhitelist = 'a-zA-Z0-9_.-';
my @additionalChars = ('A'..'Z', 'a'..'z', '0'..'9');
my $urlStart = 'https://files.progarm.org/';
my $uploadDir = '/srv/data/upload/';
my $logFile = '/srv/data/upload.log';
my %keys = qw(c69c999336d0d5a5829a alex
              96ec6a016064b7d915ea progarm
              312b9de13286653e48c5 ta
              80b7342d3902f9c86974 m);

sub squeak {
  say shift;
  die;
}

my $q = new CGI;
print $q->header();

if (not exists $keys{$q->param("key")}) {
  squeak 'Error: Not authorized to upload';
}

if (not $q->param("fileToUpload0")) {
  squeak 'Error: There was a problem uploading your file (try a smaller file)';
}

for (my $i=0; $q->param("fileToUpload$i"); $i++) {
  if ($i >= 100) { # Uploading more than 100 files? What?
    squeak 'Error: Cannot upload more than 100 files at once';
  }

  my $curFilename = substr $q->param("fileToUpload$i"), -100;

  my($name, $path, $extension) = fileparse($curFilename, '\..*');
  $name =~ tr/ /_/;
  $name =~ s/[^$filenameWhitelist]//g;
  $extension =~ tr/ /_/;
  $extension =~ s/[^$filenameWhitelist]//g;

  $curFilename = $name . $extension;

  while (-e "$uploadDir/$curFilename") { # keep adding random characters until we get unique filename
    squeak 'Error: Cannot save file with such filename' if length $curFilename >= 150; # cannot find available filename after so many attempts
    $name .= $additionalChars[rand @additionalChars];
    $curFilename = $name . $extension;
  }

  if ($curFilename =~ /^([$filenameWhitelist]+)$/) { # filename is already safe, but we have to untaint it
    $curFilename = $1;
  } else {
    squeak 'Error: Filename contains invalid characters'; # this should not happen
  }

  open(LOGFILE, '>>', $logFile) or squeak "$!";
  print LOGFILE $q->param("key") . ' ' . $ENV{REMOTE_ADDR} . ' ' . $curFilename . "\n";
  close LOGFILE;

  my $uploadFileHandle = $q->upload("fileToUpload$i");

  open(UPLOADFILE, '>', "$uploadDir/$curFilename") or squeak "$!";
  binmode UPLOADFILE;
  while (<$uploadFileHandle>) {
    print UPLOADFILE;
  }
  close UPLOADFILE;
  if ($q->param("nameOnly")) {
    print "$curFilename\n";
  } else {
    print "$urlStart$curFilename\n";
  }
}
