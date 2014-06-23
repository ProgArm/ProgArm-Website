# Copyright (C) 2003, 2004  Alex Schroeder <alex@emacswiki.org>
# Copyright (C) 2004  Haixing Hu <huhaixing@msn.com>
# Copyright (C) 2004, 2005 Todd Neal <tolchz@tolchz.net>
# Copyright (C) 2008 Eric Hsu <apricotan@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA
#

# External programs needed
# LaTeX   - http://www.latex-project.org
# TeX     - http://www.tug.org/teTeX/
# pdflatex - http://www.tug.org/applications/pdftex/
# pdfcrop 	- http://www.ctan.org/tex-archive/help/Catalogue/entries/pdfcrop.html (comes in TeXLive)
# convert - http://www.imagemagick.org/

# And optionally
# dvipng  - http://sourceforge.net/projects/dvipng/
#
# CSS Styles:
# span.eqCount
# img.LaTeX
# img.InlineMath
# img.DisplayMath

# table.minilinks
# td.pngwithlinks
# span.minilinks

use vars qw($LatexDir $LatexLinkDir $LatexExtendPath $LatexSingleDollars $RawLatexOutput, $SmallExportLinks);

# One of the following options must be set correctly to the full path of
# either dvipng or convert.  If both paths are set correctly, dvipng is used
# instead of convert. 

# pdfcrop is typically in the same path as pdflatex, but you can change it here if you like. 

my $dvipngPath  = "/opt/local/bin/dvipng";
my $convertPath = "/opt/local/bin/convert";
my $pdfcropPath = "pdfcrop";
my $pdflatexPath = "pdflatex";

# Set $dispErrors to display LaTeX errors inline on the page.
my $dispErrors = 1;

# Set $useMD5 to 1 if you want to use MD5 hashes for filenames, set it to 0 to use
# a url-encoded hash. If $useMD5 is set and the Digest::MD5 module is not available,
# latex.pl falls back to urlencode
# my $useMD5 = 0;
my $useMD5 = 1;

# PATH must be extended in order to make latex available along with
# any binaries that it may need to work
$LatexExtendPath =
  ':/usr/share/texmf/bin:/usr/bin:/usr/local/bin:/opt/local/bin';

# Allow single dollars signs to escape LaTeX math commands
$LatexSingleDollars = 0;

# Set $allowPlainTeX to 1 to allow normal LaTeX commands inside of $[ ]$
# to be executed outside of the math environment.  This should only be done
# if your wiki is not publically editable because of the possible security risk
$allowPlainLaTeX = 1 unless (defined($allowPlainLaTeX));

# (BFC) If you allow plain latex, we give the option of outputting to PDF and embedding it into the file. The following can also be "pdf".
$RawLatexOutput = "png" unless (defined($RawLatexOutput));

# (BFC) By default, we put a little pdf link next to each raw latex png to give the option of popping up a PDF version. 
$SmallExportLinks = 1 unless (defined($SmallExportLinks));

# $LatexDir must be accessible from the outside as $LatexLinkDir.  The
# first directory is used to *save* the pictures, the second directory
# is used to produce the *link* to the pictures.
#
# Example: You store the images in /org/org.emacswiki/htdocs/test/latex.
# This directory is reachable from the outside as http://www.emacswiki.org/test/latex/.
# /org/org.emacswiki/htdocs/test is your $DataDir.
# $LatexDir    = "$DataDir/latex";
# $LatexLinkDir= "/wiki/latex";

$LatexDir     = "/Users/erichsu/www/Documents/latex" unless (defined($LatexDir));
$LatexLinkDir = "/latex" unless (defined($LatexLinkDir));

# Text used when referencing equations with EQ(equationLabel)
my $eqAbbrev = "Eq. ";

# You also need a template stored as $DataDir/template.latex.  The
# template must contain the string <math> where the LaTeX code is
# supposed to go.  It will be created on the first run.
my $LatexDefaultTemplateName = "$LatexDir/template.latex";

$ModulesDescription .=
  '<p>$Id: latex-bfc.pl,v 1.5 2008/08/02 14:50:04 Eric Hsu Exp $</p>';

# Internal Equation counting and referencing variables
my $eqCounter = 0;
my %eqHash;

my $LatexDefaultTemplate = << 'EOT';
\documentclass[12pt]{article}
\usepackage{amssymb,amsmath,graphicx,hyperref}

\hypersetup{ pdfnewwindow=true, pdffitwindow=false }

\pagestyle{empty}
\begin{document}
<math>
\end{document}

EOT

push( @MyRules, \&LatexRule );
push (@MyMacros, \&HoldRawLatexByNoneditors);

sub LatexRule {   
		
    if (m/\G\\\[(\(.*?\))?((.*\n)*?.*?)\\\]/gc) {
        my $label = $1;
        my $latex = $2;
		
		return ($label . $latex) if ($PassToHtmlEditor); # leave raw for wysiwyg editor
		 
        $label =~ s#\(?\)?##g; # Remove the ()'s from the label and convert case
        $label =~ tr/A-Z/a-z/;
        $eqCounter++;
        $eqHash{$label} = $eqCounter;
        return &MakeLaTeX( "\\begin{displaymath} $latex \\end{displaymath}",
            "display math", $label );
    }
    elsif (m/\G\$\$((.*\n)*?.*?)\$\$/gc) {
		return ("\$\$ $1 \$\$") if ($PassToHtmlEditor); # leave raw for wysiwyg editor
		
        return &MakeLaTeX( "\$\$ $1 \$\$",
            $LatexSingleDollars ? "display math" : "inline math" );
    }
    elsif ( $LatexSingleDollars and m/\G\$((.*\n)*?.*?)\$/gc ) {
		return ("\$ $1 \$") if ($PassToHtmlEditor); # leave raw for wysiwyg editor
        return &MakeLaTeX( "\$ $1 \$", "inline math" );
    }
    elsif ( $allowPlainLaTeX && m/\G\$\[((.*\n)*?.*?)\]\$/gc )
    {    #Pick up plain LaTeX commands		
		return ("\$\[$1\]\$") if ($PassToHtmlEditor); # leave raw for wysiwyg editor
        return &MakeLaTeX( "$1", "LaTeX" );
    }
    elsif (m/\GEQ\((.*?)\)/gc) {    # Handle references to equations
        my $label = $1;
		return ("EQ($1)") if ($PassToHtmlEditor); # leave raw for wysiwyg editor
        $label =~ tr/A-Z/a-z/;
        if ( $eqHash{$label} ) {
            return
                $eqAbbrev
              . "<a href=\"#$label\">"
              . $eqHash{$label} . "</a>";
        }
        else {
            return "[ Equation $label not found ]";
        }
    }
    return undef;
}

sub MakeLaTeX {
    my ( $latex, $type, $label ) = @_;

    $ENV{PATH} .= $LatexExtendPath
      if $LatexExtendPath and $ENV{PATH} !~ /$LatexExtendPath/;

	my $filetype="png"; # default
	$filetype = $RawLatexOutput if (defined ($RawLatexOutput));
	my $ret="";
	my $crop_graphic=1;
	my ($tight, $crop);
	my $documentclass="";
		
    # Select which binary to use for conversion of dvi to images
    my $useConvert = 0;
    if ( not -e $dvipngPath ) {
        if ( not -e $convertPath ) {
            return
"[Error: dvipng binary and convert binary not found at $dvipngPath or $converPath ]";
        }
        else {
            $useConvert =
              1;  # Fall back on convert if dvipng is missing and convert exists
        }
    }

    $latex = UnquoteHtml($latex);    # Change &lt; back to <, for example

    # User selects which hash to use
    my $hash;
    my $hasMD5;
    if ($useMD5) { $hasMD5 = eval "require Digest::MD5;"; }
    if ( $useMD5 && $hasMD5 ) {
        $hash = Digest::MD5::md5_base64($latex);
        $hash =~ s/\//a/g;
    }
    else {
        $hash = UrlEncode($latex);
        $hash =~ s/%//g;
    }

	$hash = "cache-" . $hash;
	
	# Notice we process/strip the leading options AFTER hash, so changing options guarantees a recompute
	my $is_tex;
	
	if ($type eq "LaTeX") {
		
		if ($latex =~ /^(tex)/s) {
			$is_tex=1;
			$latex =~ s/^(tex)//s;
		}
		
		# Now get the output type override.
		if ($latex =~ /^(pdf|png)?full/s) {
			$crop_graphic = 0;
		}
		if ( $latex =~ /^(pdf|png)/s) {
			$filetype = $1;
		}		
		$latex =~ s/^(pdf|png)?(full)?//;
		
		#Next, if there is something that looks like [opt]{style}, then we use it as our \documentclass
		# if ($latex =~ /^(\[.*?\])?(\{.*?\})/) {
		if ($latex =~ /^(\[.*?\])?(\{.*?\})/) {
			$documentclass = $1 . $2;
			$latex =~ s/^(\[.*?\])?(\{.*?\})//;
			# $ret = "<pre>" . $latex . "</pre>";
		}
	}
	if ($crop_graphic) {
		$crop = "-crop";
		$tight= "tight";
	}

	# CHECK CACHE
	# if we've processed this before, there's a directory with some nice pngs or pdfs, 
	# so we check if there is a cache hit. (Unless it's raw LaTeX mode, assume there is only one file, $hash/srender1.png)
	# if not, create the directory, create the files and then read back the 
	# directory to see what graphic files got created.
	
	# We don't allow non-editors to create new raw latex unless $RawLatexForAll=1
	# (This is filtered by the @MyMacro at text save.)
	
	my $dir = "$LatexDir/$hash";
    my $output;

	my $oldpng = "$LatexDir/$hash/srender$crop.png";
	my $oldpng1= "$LatexDir/$hash/srender1$crop.png";
	my $oldpdf = "$LatexDir/$hash/srender.pdf";

    unless ( ($filetype eq "png" && ( -e "$oldpng1" || -e "$oldpng") )  || 
 			 ($filetype eq "pdf" &&  -e "$oldpdf") ) {

        # read template and replace <math>
        mkdir($LatexDir) unless -d $LatexDir;
        if ( not -f $LatexDefaultTemplateName ) {
            open( F, "> $LatexDefaultTemplateName" )
              or return '[Unable to write template]';
            print F $LatexDefaultTemplate;
            close(F);
        }
        my $template = ReadFileOrDie($LatexDefaultTemplateName);
        
        # A little fix to includegraphics to add ../ to the filename, so we can use 
		# graphics stored in $LatexDir (since work files end up in $LatexDir/$hash)

		$latex =~ s/(\\includegraphics.*?\{)\s*/$1..\//g;
		
		unless ($is_tex) {
			$template =~ s/<math>/$latex/ig;
		
			if ($documentclass) {
				$template =~ s/\\documentclass.*?\}/\\documentclass$documentclass/;			
			}
		} else {
			$template = $latex;
		}
        #setup rendering directory
        if ( -d $dir ) {
            unlink( glob('$dir/*') );
        }
        else {
            mkdir($dir) or return "[Unable to create $dir]";
        }
        chdir($dir) or return "[Unable to switch to $dir]";
        WriteStringToFile( "srender.tex", $template );
        WriteStringToFile( "srender.txt", $template );
		# $output = qx (ln -s srender.tex srender.txt);
		#         return "[couldn't link srender.tex error $? ($output)]" if $?;			
		
        my $errorText;
 		
		if ($type eq "LaTeX") {
			$pdflatexPath =~ s/pdflatex/pdftex/g  if ($is_tex);
			$errorText = qx($pdflatexPath srender.tex);	
			# for raw latex, we always make a pdf		
			# and convert to png for good measure
		} else {
			$errorText = qx(latex srender.tex);
		} 
		
        return "[Illegal LaTeX markup: <pre>$latex</pre>] <br/> Error: <pre>$errorText</pre>"
          if ( $? && $dispErrors );
        return "[Illegal LaTeX markup: <pre>$latex</pre>] <br/>" if $?;
		


		if ($type eq "LaTeX") {
			# If we want it cropped, we use pdfcrop.
			if ($crop_graphic) {
				$output = qx($pdfcropPath srender.pdf);
	            return "[pdfcrop error $? ($output)]" if $?;			
			}
			# for raw latex, we've already made a pdf. Now make the PNG.
			
			# BETTER OUTPUT
			# $output = qx($convertPath -antialias -crop 0x0 -density 120x120 -transparent white srender$crop.pdf srender$crop.png );
			$output = qx($convertPath -antialias -crop 0x0 -density 240x240 -transparent white -resize 50% srender$crop.pdf srender$crop.png );
	            return "[convert error $? ($output)]" if $?;			
		} else {
	        # Use specified binary to convert dvi to png
	        if ($useConvert && $filetype eq "png") {
	            $output = qx($convertPath -antialias -crop 0x0 -density 120x120 -transparent white srender.dvi srender1.$filetype );
	            return "[convert error $? ($output)]" if $?;
	        }
	        elsif ($filetype eq "png") {			
				$output = qx($dvipngPath -T $tight -bg Transparent -Q 5 srender.dvi);

	            return "[dvipng error $? ($output)]" if $?;
	        }
		}
   }

   # my $result;

    # Finally print the html for the image

    chdir($dir) or return "[Unable to switch to $dir]";
	
     if ( $type eq "inline math" ) {    # inline math
         $ret .= "<img class='InlineMath' "
           . "src='$LatexLinkDir/$hash/srender1.png' alt='$latex'\/>";
     }
     elsif ( $type eq "display math" ) {    # display math
         if ($label) { $ret .= "<a name='$label'>"; }
         $ret .= "<center><img class='DisplayMath' "
           . "src='$LatexLinkDir/$hash/srender1.png' alt='$latex'> <span class=\'eqCount\'>($eqCounter)</span><\/center>";
     }
     else {                                 
		# latex format
		# be sure to print a link for each png produced.
		
		my $count = 0;
		my $pnglinks;
		$latex =~ s/[\"\']//g; # clean it up for use as alt text.
		
		if ($filetype eq "png") {
			if (-e "srender$crop.png") {
				$pnglinks .= "<img class='LaTeX' "
			      . "src='$LatexLinkDir/$hash/srender$crop.png' alt='$latex' \/><br\/>";
				
			} else {
				while (-e "srender$crop-$count.png") {
					$pnglinks .= "<img class='LaTeX' "
				      . "src='$LatexLinkDir/$hash/srender$crop-$count.png' alt='$latex' \/><br\/>";
					$latex=""; # only as alt for first png.
					$count++;
				}	
				
			}
			if ($SmallExportLinks) {
				my $graphics = IncludedGraphics($latex);
				$graphics = " and $graphics" if ($graphics);
				my $type = "latex";
				$type = "tex" if ($is_tex);
				my $pdflinks = <<EOL;
<a href="$LatexLinkDir/$hash/srender.pdf" alt='pdf' target="_new">&nbsp;&bull; pdf</a><br/>
<a href="$LatexLinkDir/$hash/srender$crop.pdf" alt='pdfcrop' target="_new">&nbsp;&bull; pdf tight</a><br/>
<a href="$LatexLinkDir/$hash/srender.txt" alt='latex' target="_new">&nbsp;&bull; $type</a>$graphics<br/>
EOL
				$pnglinks = "<table class=minilinkstable ><tr><td class=pngwithlinks width=700>$pnglinks</td><td valign=top ><span class=minilinks>$pdflinks</span></td></tr></table>";
			}
			$ret .= $pnglinks;					
			
		} elsif ($filetype eq "pdf") {
			$ret .= "<embed width=1000 height=500 src='$LatexLinkDir/$hash/srender$crop.pdf'>";
		}
     }
    return ($ret);

    # unlink( glob('*') );
    # chdir($LatexDir);
    # rmdir($dir);
    # return $result;
}
sub IncludedGraphics {
	my $text = shift;
	my $ret;
	
	$text =~ s/[^\\]\%.*//g;  # ignore graphics in comments.
	
	my (@graphics) = ($text=~/\\includegraphics.*?\{(.*?)\}/g);
	return unless (scalar @graphics);
		
	# $ret = "figures ";
	my $fignum;
	my $alreadydone;
	
	foreach $filename (@graphics) {
		next if ($alreadydone->{$filename});
		$alreadydone->{$filename}++;
		$fignum++;
		$ret .= ", " unless ($fignum == 1);
		$filename =~ s/\.\.\///;
		$ret .= qq(<a href="$LatexLinkDir/$filename" alt='fig $fignum' target="_new">fig $fignum</a>);
	}
	$ret .= "<br/>";
	
	return ($ret);
}

sub HoldRawLatexByNoneditors {
	# This macro quotes raw latex by non-editors to reduce slightly the security risk.
	
	# skip the quoting for Editors, but we still need Comments to end with a double <hr>.
	
	return if (UserIsEditor() || $RawLatexForAll); 
	
	my (@comments, $lastpiece);
	my $THISWORKS=0;  
	# Don't have time to put in a properly working hack to only edit the last comment.
	# By turning the hack off, it means that anonymous commenters that add raw latex will cause the whole comment page's raw latex to be quoted. Which is a pretty rare case that anyone would legitimately be using raw latex in a comment! 
	
	# if a user can only add comments, when they try forbidden latex in a comment, 
	# only mark their piece as bad.
	if ($EditAllowed == 3 && $THISWORKS) {
		@comments = split(/\-\-\-\-/, $_);
		$lastpiece = pop @comments;
		$lastpiece =~ s/\$\[(.*?)\]\$/\n\{\{\{\n***Raw LaTeX requires Editor review.\n\n$1\n\}\}\}\n/gs;
		$_ = join("----", @comments, $lastpiece);
	} else {
		s/\$\[(.*?)\]\$/\n\{\{\{\n***Raw LaTeX requires Editor review.\n\n$1\n\}\}\}\n/gs;
	}
}

# =====================
# = LatexSearchResult =
# =====================

# If we find raw latex in the file, we display the first such chunk.

push @MyPrintSearchResults, \&LatexSearchResult;

sub LatexSearchResult {
	my ($name, $regex, $text, $type) = @_;
	my $html;
	
	if ( $allowPlainLaTeX && $text =~ m/\G\$\[((.*\n)*?.*?)\]\$/gc ) {    
		$html = &MakeLaTeX( "$1", "LaTeX" );

		# Make sure we only show the first page.
		my $more = "<br/>(more pages...)";
		$html =~ s/(<br\s*\/?>).*img.*(<\/td>)/$1$more$3/s;

		PrintPage($name);
		print $html;
		return 1;
    } else {
	return 0;
	}
    
}

__END__
=
latex-bfc.pl: an enhancement of latex.pl to allow raw latex to produce multiple PNGs or embedded PDFs; now uses amsmath and hyperref packages by default; requires pdflatex for PDF mode (not for PNGs)

* enhanced raw latex mode (not secure, so don’t let random people be editors!) (default $allowPlainLaTeX=1)
* $[ and ]$ to delimit raw LaTeX commands. Not suitable for use on a publicly editable wiki.
* raw latex produces full-page PNGs (one for each page) by default, with option to embed a PDF instead ($RawLatexOutput=“pdf”). This allows entire latex files to be displayed.
* $[type[options]{class} are options.
type is the filetype of the output and can be pdf, png or pngtight (margins clipped)
{class} is the LaTeX \documentclass. [opt] are options for {class}. They are optional and cannot stand by themselves.
* raw latex mode is restricted to Editors and Admins unless $RawLatexForAll=1

Otherwise similar to latex.pl in Oddmuse Extensions.
(1.5) Tweaked the convert imagemagick settings to improve the look of the pngs: double density, rescale (-density 240x240 -resize 50%). Fixed cache... it was not recognizing the -crop name. Now accepts raw TeX too. Begin the block with $[tex.
(1.4c) Rewrote support for $PassToHtmlEditor=1. We need to do a successful match, otherwise other Rules will process our latex area. We also want to pass back the raw markup.
(1.4b) Will not fire if this is creating HTML to pass to an HTML editor like fckeditor in fckeditor-bfc.pl.
(1.4a) Nicer links for figures.
(1.4) First draft of links to latex includegraphics figures.
(1.3) Now includes a plugin for showing latex in search results. Requires mysearchresults.pl.

(1.2d)
* Reverted fix for raw latex quoting. For now, it will quote all raw latex on comment page. (We're not anticipating a lot of such latex.)

(1.2c)

* Now you can \includegraphics{pic.pdf} as written (we secretly add the ../ so as to look in $LatexDir where you really downloaded it.
* Fixed silly bug where the security quoting of raw latex comments was quoting all previous comments.
* Fixed silly bug where math & displaymath weren't being produced as tight PNGs.

(1.2)
By default, we produce png cropped with a little link next to it "show pdf". 
We allow full as an option for either png or pdf to be full pages. 
We won't allow crop as an option any more.

(1.1) 
Now always generate using pdftex. 
We can now accept \includegraphics with pdftex friendly formats.
We can produce pngcrop and pdfcrop.

