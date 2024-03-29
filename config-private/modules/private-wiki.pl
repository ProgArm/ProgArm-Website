# Copyright (C) 2015  Alex-Daniel Jakimenko <alex.jakimenko@gmail.com>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

use strict;
# use warnings;
use v5.10;
use utf8;

use Crypt::Rijndael;
use Crypt::Random::Seed;

AddModuleDescription('private-wiki.pl', 'Private Wiki Extension');

our ($q, $FS, @IndexList, %IndexHash, $IndexFile, $TempDir, $KeepDir, %LockCleaners);

my ($cipher, $random);
my $PrivateWikiInitialized = '';

sub PrivateWikiInit {
  return if $PrivateWikiInitialized;
  $PrivateWikiInitialized = 1;
  if (UserIsEditor()) {
    # keysize() is 32, but 24 and 16 are also possible, blocksize() is 16
    my $pass = GetParam('pwd');
    $cipher = Crypt::Rijndael->new(pack("H*", GetParam('pwd')), Crypt::Rijndael::MODE_CBC());
    # TODO print error if the password Is not in hex?

    # We are using /dev/urandom (or other nonblocking source) because we don't want
    # to make our users wait for a couple of minutes until we get our numbers...
    $random = Crypt::Random::Seed->new(NonBlocking => 1) // die "No random sources exist";
  }
}

sub PadTo16Bytes { # use this only on UTF-X strings (after utf8::encode)
  my ($data, $minLength) = @_;
  my $endBytes = length($data) % 16;
  $data .= "\0" x (16 - $endBytes) if $endBytes != 0;
  $data .= "\0" x ($minLength - length $data) if $minLength;
  return $data;
}

my $errorMessage = T('This error should not happen. If your password is set correctly and you are still'
		     . ' seeing this message, then it is a bug, please report it. If you are just a stranger'
		     . ' and trying to get unsolicited access, then keep in mind that all of the data is'
		     . ' encrypted with AES-256 and the key is not stored on the server, good luck.');

*OldPrivateWikiReadFile = \&ReadFile;
*ReadFile = \&NewPrivateWikiReadFile;

sub NewPrivateWikiReadFile {
  ReportError(T('Attempt to read encrypted data without a password.'), '403 FORBIDDEN', 0,
	      $q->p($errorMessage)) if not UserIsEditor();
  PrivateWikiInit();
  my $file = shift;
  utf8::encode($file); # filenames are bytes!
  if (open(my $IN, '<', $file)) {
    local $/ = undef; # Read complete files
    my $data = <$IN>;
    close $IN;
    return (1, '') unless $data;
    $cipher->set_iv(substr $data, 0, 16);
    $data = $cipher->decrypt(substr $data, 16);
    my $copy = $data; # copying is required, see https://github.com/briandfoy/crypt-rijndael/issues/5
    $copy =~ s/\0+$//;
    utf8::decode($copy);
    return (1, $copy);
  }
  return (0, '');
}

*OldPrivateWikiWriteStringToFile = \&WriteStringToFile;
*WriteStringToFile = \&NewPrivateWikiWriteStringToFile;

sub NewPrivateWikiWriteStringToFile {
  ReportError(T('Attempt to read encrypted data without a password.'), '403 FORBIDDEN', 0,
	      $q->p($errorMessage)) if not UserIsEditor();
  PrivateWikiInit();
  my ($file, $string) = @_;
  utf8::encode($file);
  open(my $OUT, '>', $file) or ReportError(Ts('Cannot write %s', $file) . ": $!", '500 INTERNAL SERVER ERROR');
  utf8::encode($string);
  my $iv = $random->random_bytes(16);
  $cipher->set_iv($iv);
  print $OUT $iv;
  print $OUT $cipher->encrypt(PadTo16Bytes $string);
  close($OUT);
}

# TODO is there any better way to append data to encrypted files?
sub AppendStringToFile {
  my ($file, $string) = @_;
  WriteStringToFile($file, ReadFile($file) . $string); # This should be happening under a lock
}

# We do not want to store page names in plaintext, let's encrypt them!
# Therefore we will rely on the pageidx file.

#*OldPrivateWikiRefreshIndex = \&RefreshIndex;
*RefreshIndex = \&NewPrivateWikiRefreshIndex;

sub NewPrivateWikiRefreshIndex {
  if (not -f $IndexFile) { # Index file does not exist yet, this is a new wiki
    my $fh;
    open($fh, '>', $IndexFile) or die "Unable to open file $IndexFile : $!"; # 'touch' equivalent
    close($fh) or die "Unable to close file : $IndexFile $!";
    return;
  }
  return;
  #ReportError(T('Cannot refresh index.'), '500 Internal Server Error', 0,
  #$q->p('If you see this message, then there is a bug, please report it. '
  #. 'Normally Private Wiki Extension should prevent attempts to refresh the index, but this time something weird has happened.'));
}

our %PageIvs = ();

#*OldPrivateWikiReadIndex = \&ReadIndex;
*ReadIndex = \&NewPrivateWikiReadIndex;

sub NewPrivateWikiReadIndex {
  my ($status, $rawIndex) = ReadFile($IndexFile); # not fatal
  if ($status) {
    my @rawPageList = split(/ /, $rawIndex);
    for (@rawPageList) {
      my ($pageName, $iv) = split /!/, $_, 2;
      push @IndexList, $pageName;
      $PageIvs{$pageName} = pack "H*", $iv; # decode hex string
    }
    %IndexHash = map {$_ => 1} @IndexList;
    return @IndexList;
  }
  return;
}

#*OldPrivateWikiWriteIndex = \&WriteIndex;
*WriteIndex = \&NewPrivateWikiWriteIndex;

sub NewPrivateWikiWriteIndex {
  WriteStringToFile($IndexFile, join(' ', map { $_ . '!' . unpack "H*", $PageIvs{$_} } @IndexList));
}

# pages longer than 6 blocks will result in filenames that are longer than 255 bytes
our $PageNameLimit = 96;

sub GetPrivatePageFile {
  my ($id) = @_;
  PrivateWikiInit();
  my $iv = $PageIvs{$id};
  if (not $iv) {
    # generate iv for new pages. It is okay if we are not called from SavePage, because
    # in that case the caller will probably check if that file exists (and it clearly does not)
    $iv = $random->random_bytes(16);
    $PageIvs{$id} = $iv;
  }
  $cipher->set_iv($iv);
  # We cannot use full byte range because of the filesystem limits
  utf8::encode($id);
  my $returnName = unpack "H*", $iv . $cipher->encrypt(PadTo16Bytes $id, 96); # to hex string
  return $returnName;
}

*OldPrivateWikiGetPageFile = \&GetPageFile;
*GetPageFile = \&NewPrivateWikiGetPageFile;

sub NewPrivateWikiGetPageFile {
  OldPrivateWikiGetPageFile(GetPrivatePageFile @_);
}

*OldPrivateWikiGetKeepDir = \&GetKeepDir;
*GetKeepDir = \&NewPrivateWikiGetKeepDir;

sub NewPrivateWikiGetKeepDir {
  OldPrivateWikiGetKeepDir(GetPrivatePageFile @_);
}

# Now let's do some hacks!

# First of all, "ban" all users so they can't see anything
# (Note: they will not see anything anyway, since the pages will only
# get decrypted when the user provides correct password)

our $BannedCanRead = 0;

sub UserIsBanned {
  return GetParam('action', '') ne 'password'; # login is always ok
}

# Oddmuse attempts to read pageidx file sometimes. If the password is not set let's just skip it

*OldPrivateWikiAllPagesList = \&AllPagesList;
*AllPagesList = \&NewPrivateWikiAllPagesList;

our @MyInitVariables;
push(@MyInitVariables, \&AllPagesList);

sub NewPrivateWikiAllPagesList {
  return () if not UserIsEditor(); # no key - no AllPagesList
  OldPrivateWikiAllPagesList(@_);
}

# Then, let's allow DoDiff to save stuff in unencrypted form so that it can be diffed.
# We will wipe the files right after the diff action.

# This sub is copied from the core. Lines marked with CHANGED were changed.
sub DoDiff {      # Actualy call the diff program
  CreateDir($TempDir);
  my $oldName = "$TempDir/old";
  my $newName = "$TempDir/new";
  RequestLockDir('diff') or return '';
  $LockCleaners{'diff'} = sub { unlink $oldName if -f $oldName; unlink $newName if -f $newName; };
  OldPrivateWikiWriteStringToFile($oldName, $_[0]); # CHANGED Here we use the old sub!
  OldPrivateWikiWriteStringToFile($newName, $_[1]); # CHANGED
  my $diff_out = `diff -- \Q$oldName\E \Q$newName\E`;
  utf8::decode($diff_out); # needs decoding
  $diff_out =~ s/\n\K\\ No newline.*\n//g; # Get rid of common complaint.
  # CHANGED We have to unlink the files because we don't want to store them in plaintext!
  unlink $oldName, $newName; # CHANGED
  ReleaseLockDir('diff');
  return $diff_out;
}

# Same thing has to be done with MergeRevisions

# This sub is copied from the core. Lines marked with CHANGED were changed.
sub MergeRevisions {   # merge change from file2 to file3 into file1
  my ($file1, $file2, $file3) = @_;
  my ($name1, $name2, $name3) = ("$TempDir/file1", "$TempDir/file2", "$TempDir/file3");
  CreateDir($TempDir);
  RequestLockDir('merge') or return T('Could not get a lock to merge!');
  $LockCleaners{'merge'} = sub { # CHANGED
    unlink $name1 if -f $name1; unlink $name2 if -f $name2; unlink $name3 if -f $name3;
  };
  OldPrivateWikiWriteStringToFile($name1, $file1); # CHANGED
  OldPrivateWikiWriteStringToFile($name2, $file2); # CHANGED
  OldPrivateWikiWriteStringToFile($name3, $file3); # CHANGED
  my ($you, $ancestor, $other) = (T('you'), T('ancestor'), T('other'));
  my $output = `diff3 -m -L \Q$you\E -L \Q$ancestor\E -L \Q$other\E -- \Q$name1\E \Q$name2\E \Q$name3\E`;
  utf8::decode($output); # needs decoding
  unlink $name1, $name2, $name3; # CHANGED unlink temp files -- we don't want to store them in plaintext!
  ReleaseLockDir('merge');
  return $output;
}

# Surge protection has to be unencrypted because in the context of this module
# it is a tool against people who have no password set (thus we have no key
# to do encryption).

our ($VisitorFile, %RecentVisitors, $Now, $SurgeProtectionTime, $SurgeProtectionViews);

# This sub is copied from the core. Lines marked with CHANGED were changed.
sub ReadRecentVisitors {
  my ($status, $data) = OldPrivateWikiReadFile($VisitorFile); # CHANGED
  %RecentVisitors = ();
  return unless $status;
  foreach (split(/\n/, $data)) {
    my @entries = split /$FS/;
    my $name = shift(@entries);
    $RecentVisitors{$name} = \@entries if $name;
  }
}

# This sub is copied from the core. Lines marked with CHANGED were changed.
sub WriteRecentVisitors {
  my $data = '';
  my $limit = $Now - $SurgeProtectionTime;
  foreach my $name (keys %RecentVisitors) {
    my @entries = @{$RecentVisitors{$name}};
    if ($entries[0] >= $limit) { # if the most recent one is too old, do not keep
      $data .=  join($FS, $name, @entries[0 .. $SurgeProtectionViews - 1]) . "\n";
    }
  }
  OldPrivateWikiWriteStringToFile($VisitorFile, $data); # CHANGED
}

# At the same time, we don't want to store any information about the editors
# because it reveals their usernames. A bit paranoidal, but why not.

*OldPrivateWikiAddRecentVisitor = \&AddRecentVisitor;
*AddRecentVisitor = \&NewPrivateWikiAddRecentVisitor;

sub NewPrivateWikiAddRecentVisitor {
  return if UserIsEditor();
  OldPrivateWikiAddRecentVisitor(@_);
}

*OldPrivateWikiDelayRequired = \&DelayRequired;
*DelayRequired = \&NewPrivateWikiDelayRequired;

sub NewPrivateWikiDelayRequired {
  return '' if UserIsEditor();
  OldPrivateWikiDelayRequired(@_);
}

# PageIsUploadedFile attempts to read the file partially, which does not work that
# well on encrypted data. Therefore, we disable file uploads for now.

our $UploadAllowed = 0;
sub PageIsUploadedFile { '' }

# Finally, we have to fix RecentChanges

our ($RcDefault, $RcFile, $RcOldFile, $FreeLinkPattern, $LinkPattern, $ShowEdits, $PageCluster);

# This sub is copied from the core. Lines marked with CHANGED were changed.
sub GetRcLines { # starttime, hash of seen pages to use as a second return value
  my $starttime = shift || GetParam('from', 0) ||
      $Now - GetParam('days', $RcDefault) * 86400; # 24*60*60
  my $filterOnly = GetParam('rcfilteronly', '');
  # these variables apply accross logfiles
  my %match = $filterOnly ? map { $_ => 1 } SearchTitleAndBody($filterOnly) : ();
  my %following = ();
  my @result = ();
  # check the first timestamp in the default file, maybe read old log file
	use warnings;
  my $filelike = ReadFile($RcFile); # CHANGED
	utf8::encode($filelike);
	#ReportError($filelike);
  open(my $F, '<', \$filelike) or die $!; # CHANGED

  my $line = <$F>;
  my ($ts) = split(/$FS/, $line); # the first timestamp in the regular rc file
  if (not $ts or $ts > $starttime) { # we need to read the old rc file, too
    push(@result, GetRcLinesFor($RcOldFile, $starttime, \%match, \%following));
  }
  push(@result, GetRcLinesFor($RcFile, $starttime, \%match, \%following));
  # GetRcLinesFor is trying to save memory space, but some operations
  # can only happen once we have all the data.
  return LatestChanges(StripRollbacks(@result));
}

# This sub is copied from the core. Lines marked with CHANGED were changed.
sub GetRcLinesFor {
  my $file = shift;
  my $starttime = shift;
  my %match = %{$_[0]}; # deref
  my %following = %{$_[1]}; # deref
  # parameters
  my $showminoredit = GetParam('showedit', $ShowEdits); # show minor edits
  my $all = GetParam('all', 0);
  my ($idOnly, $userOnly, $hostOnly, $clusterOnly, $filterOnly, $match, $lang,
      $followup) = map { UnquoteHtml(GetParam($_, '')); }
  qw(rcidonly rcuseronly rchostonly
        rcclusteronly rcfilteronly match lang followup);
  # parsing and filtering
  my @result = ();

  my $filelike = ReadFile($file); # CHANGED
	utf8::encode($filelike);
  open(my $F, '<:encoding(UTF-8)', \$filelike) or return (); # CHANGED

  while (my $line = <$F>) {
    chomp($line);
    my ($ts, $id, $minor, $summary, $host, $username, $revision,
	$languages, $cluster) = split(/$FS/, $line);
    next if $ts < $starttime;
    $following{$id} = $ts if $followup and $followup eq $username;
    next if $followup and (not $following{$id} or $ts <= $following{$id});
    next if $idOnly and $idOnly ne $id;
    next if $filterOnly and not $match{$id};
    next if ($userOnly and $userOnly ne $username);
    next if $minor == 1 and not $showminoredit; # skip minor edits (if [[rollback]] this is bogus)
    next if not $minor and $showminoredit == 2; # skip major edits
    next if $match and $id !~ /$match/i;
    next if $hostOnly and $host !~ /$hostOnly/i;
    my @languages = split(/,/, $languages);
    next if $lang and @languages and not grep(/$lang/, @languages);
    if ($PageCluster) {
      ($cluster, $summary) = ($1, $2) if $summary =~ /^\[\[$FreeLinkPattern\]\] ?: *(.*)/
	  or $summary =~ /^$LinkPattern ?: *(.*)/;
      next if ($clusterOnly and $clusterOnly ne $cluster);
      $cluster = '' if $clusterOnly; # don't show cluster if $clusterOnly eq $cluster
      if ($all < 2 and not $clusterOnly and $cluster) {
	$summary = "$id: $summary"; # print the cluster instead of the page
	$id = $cluster;
	$revision = '';
      }
    } else {
      $cluster = '';
    }
    $following{$id} = $ts if $followup and $followup eq $username;
    push(@result, [$ts, $id, $minor, $summary, $host, $username, $revision,
		   \@languages, $cluster]);
  }
  return @result;
}

# We do not want to print the header to unauthorized users because it contains
# the gotobar, our logo and a useless search form.

*OldPrivateWikiGetHeaderDiv = \&GetHeaderDiv;
*GetHeaderDiv = \&NewPrivateWikiGetHeaderDiv;

sub NewPrivateWikiGetHeaderDiv {
  return OldPrivateWikiGetHeaderDiv(@_) if UserIsEditor();
  my ($id, $title, $oldId, $embed) = @_;
  my $result .= $q->start_div({-class=>'header'});
  our $Message;
  $result .= $q->div({-class=>'message'}, $Message) if $Message;
  $result .= GetHeaderTitle($id, $title, $oldId);
  $result .= $q->end_div();
  return $result;
}
