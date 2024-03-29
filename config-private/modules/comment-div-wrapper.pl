# Copyright (C) 2014  Alex-Daniel Jakimenko <alex.jakimenko@gmail.com>
# Copyright (C) 2014  Alex Schroeder <alex@gnu.org>

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

package OddMuse;

AddModuleDescription('comment-div-wrapper.pl', 'Comment Div Wrapper Extension');

our ($q, $bol, $OpenPageName, @MyRules, %RuleOrder, $CommentsPrefix, $CommentsPattern, $FS);
my $CommentDiv = 0;
push(@MyRules, \&CommentDivWrapper);
$RuleOrder{\&CommentDivWrapper} = -50;

sub CommentDivWrapper {
  if (substr($OpenPageName, 0, length($CommentsPrefix)) eq $CommentsPrefix) {
    if (pos == 0 and not $CommentDiv) {
      $CommentDiv = 1;
      return $q->start_div({-class=>'userComment'});
    }
  }
  if ($OpenPageName =~ /$CommentsPattern/o) {
    if ($bol and m/\G(\s*\n)*----+[ \t]*\n?/cg) {
      my $html = CloseHtmlEnvironments()
	  . ($CommentDiv++ > 0 ? $q->end_div() : $q->h2({-class=>'commentsHeading'}, T('Comments:'))) . $q->start_div({-class=>'userComment'})
	  . AddHtmlEnvironment('p');
      return $html;
    }
  }
  return;
}

# close final div
*OldCommentDivApplyRules = \&ApplyRules;
*ApplyRules = \&NewCommentDivApplyRules;

sub NewCommentDivApplyRules {
  my ($blocks, $flags) = OldCommentDivApplyRules(@_);
  if ($CommentDiv) {
    print $q->end_div();
    $blocks .= $FS . $q->end_div();
    $flags .= $FS . 0;
    $CommentDiv = 0;
  }
  return ($blocks, $flags);
}
