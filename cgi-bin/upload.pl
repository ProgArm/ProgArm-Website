#!/usr/bin/perl -T
use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

$CGI::POST_MAX = 1024 * 100000;
my $filenameWhitelist = "a-zA-Z0-9_.-";
my @additionalChars = ('A'..'Z', 'a'..'z', '0'..'9');
my $uploadDir = "../u/";
my $logFile = "../upload.log";

my $q = new CGI;

if (!$q->param("fileToUpload0")) {
  die 'Error: There was a problem uploading your file (try a smaller file)';
}

for (my $i=0; $q->param("fileToUpload$i"); $i++) {
  if ($i >= 100) { # Uploading more than 100 files? What?
    die 'Error: Cannot upload more than 100 files at once';
  }

  my $curFilename = substr $q->param("fileToUpload$i"), -100;

  my($name, $path, $extension) = fileparse($curFilename, '\..*');
  $name =~ tr/ /_/;
  $name =~ s/[^$filenameWhitelist]//g;
  $extension =~ tr/ /_/;
  $extension =~ s/[^$filenameWhitelist]//g;

  $curFilename = $name . $extension;

  while (-e "$uploadDir/$curFilename") { # keep adding random characters until we get unique filename
    die 'Error: Cannot save file with such filename' if length $curFilename >= 150; # cannot find available filename after so many attempts
    $name .= $additionalChars[rand @additionalChars];
    $curFilename = $name . $extension;
  }

  if ($curFilename =~ /^([$filenameWhitelist]+)$/) { # filename is already safe, but we have to untaint it
    $curFilename = $1;
  } else {
    die 'Error: Filename contains invalid characters'; # this should not happen
  }

  open(LOGFILE, '>>', $logFile) or die "$!";
  print LOGFILE $ENV{REMOTE_ADDR} . ' ' . $curFilename . "\n";
  close LOGFILE;

  my $uploadFileHandle = $q->upload("fileToUpload$i");

  open(UPLOADFILE, '>', "$uploadDir/$curFilename") or die "$!";
  binmode UPLOADFILE;
  while (<$uploadFileHandle>) {
    print UPLOADFILE;
  }
  close UPLOADFILE;
  print $q->header();
  print "$curFilename\n"
}
