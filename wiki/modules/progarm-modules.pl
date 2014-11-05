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

AddModuleDescription('progarm-modules.pl');

my $sourceUrl = 'https://raw.githubusercontent.com/ProgArm/ProgArm-Client/master/modules/';
my $viewUrl = 'https://github.com/ProgArm/ProgArm-Client/blob/master/modules/';

push(@MyRules, \&ProgArmModuleRule);
sub ProgArmModuleRule {
  if (m/\G(#ProgArmModule\s+([a-z_]+\.pl))/cgi) {
    my $moduleName = $2;
    my $source = GetRaw($sourceUrl . $moduleName);
    $source =~ /(^|\n)[\$\@]Keys\{(qw\()?([\w ]+)\)?}\s*=\s*(qw\(|\')([\w ]+)(\)|\');/;
    my @subs = split /\s+/, $3;
    my @keys = split /\s+/, $5;

    my @vars = ();
    # TODO support individual variables like "our $test = '...';"
    @vars = split /[,\s]+/, $2 if $source =~ /(^|\n)our ?\(([\w \$\%\@,]+)\);/;

    my %ignoreVars = ();
    @ignoreVars{qw(%Keys %Actions %Commands %CODES %KEYS $Android)} = undef;
    @vars = grep {not exists $ignoreVars{$_}} @vars;

    my $out .= qq{Source code: <a href="$viewUrl$moduleName">$moduleName</a>};

    if (@subs) {
      $out .= '<h2>Provided keys:</h2>';
      $out .= '<table class="user">';
      $out .= '<tr><th>Function</th><th>Key</th></tr>';
      for (0 .. $#subs) {
	$out .= qq{<tr><td><div class="subroutine">$subs[$_]</div></td><td>};
	$out .= ProgArmProcessKey($keys[$_]) . '</td></tr>';
      }
      $out .= '</table>';
    }

    if (@vars) {
      $out .= '<h2>Provided variables:</h2>';
      $out .= join ' ', map { qq{<div class="variable">$_</div>} } @vars;
    }
    return $out;
  }
  return undef; # the rule didn't match
}
