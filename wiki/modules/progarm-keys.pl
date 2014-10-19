# Copyright (C) 2014  Alex-Daniel Jakimenko <alex.jakimenko@gmail.com>
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

package OddMuse;

AddModuleDescription('progarm-keys.pl');

my %KEYS = ('SX SX' => 'SPACE','XS XS' => 'BACKSPACE','SS SS' => 'ENTER','SX XS' => 'SHIFT','XS SX' => 'SYMBOLS','SX SS' => 'E','XS SS' => 'T','SS SX' => 'A','SS XS' => 'O','SX LX' => 'I','LX SX' => 'N','XS XL' => 'S','XL XS' => 'H','SS LL' => 'R','LL SS' => 'D','SX XL' => 'L','LX XS' => 'C','XS LX' => 'U','XL SX' => 'M','SX LL' => 'W','LX SS' => 'F','XS LL' => 'G','XL SS' => 'Y','SS LX' => 'P','SS XL' => 'B','LL SX' => 'V','LL XS' => 'K','LX LX' => 'J','XL XL' => 'X','LL LL' => 'Q','LX XL' => 'Z','XL LX' => 'CTRL','LX LL' => 'ALT','XL LL' => 'ESCAPE','LL LX' => 'TAB',);
my %COMBINATIONS = reverse %KEYS;

push(@MyRules, \&ProgArmKeyRule);

sub GetProgArmPressDescription {
  my ($part1, $part2) = @_;
  my $type = ($part1 eq 'L' or $part2 eq 'L') ? 'long' : 'short';
  return "make a $type press on both buttons" if $part1 eq $part2;;
  return "make a $type press on the lower button" if $part1 ne 'x';
  return "make a $type press on the upper button" if $part2 ne 'x';
}

sub GetProgArmColoredButton {
  my ($button, $class) = @_;
  $q->span({-class=>($button eq 'x' ? 'keynone ' : '') . $class}, $button);
}

sub ProgArmKeyRule {
  if (m/\G(Key\{([a-zA-Z ]+)\})/cgi) {
    Dirty($1);
    my $input = $2;
    my $key;
    my $combination;
    my $shift = '';
    if ($input =~ /^[LlSs]{2} [LlSs]{2}$/) {
      $combination = uc($input);
      return "Unknown combination: $input" unless exists $KEYS{$combination};
      $key = $KEYS{$combination};
    } elsif ($input =~ /^[a-zA-Z]+$/) {
      $key = uc($input);
      return "Unknown key: $input" unless exists $COMBINATIONS{$key};
      $combination = $COMBINATIONS{$key};
      $shift = $input =~ /^[A-Z]$/;
    } else {
      return "Unknown key: $input";
    }
    $combination =~ s/X/x/g;
    $combination =~ /(.)(.) (.)(.)/;
    my $result = GetProgArmColoredButton($1, 'key1') . GetProgArmColoredButton($2, 'key2') . GetProgArmColoredButton(' ', 'keyspacer')
	. GetProgArmColoredButton($3, 'key1') . GetProgArmColoredButton($4, 'key2');

    my $descriptionStart = $shift ? 'press Shift key, then ' : '';
    my $part1 .= GetProgArmPressDescription($1, $2);
    my $part2 .= GetProgArmPressDescription($3, $4);
    my $description = $descriptionStart . ($part1 eq $part2 ? $part1 . ' twice' : $part1 . ' and then ' . $part2);

    print $q->span({-class=>'key', -title=>$description}, $q->span({-class=>'keyname'}, $input) . ' (' . $result . ')');
    return '';
  }
  return undef; # the rule didn't match
}
