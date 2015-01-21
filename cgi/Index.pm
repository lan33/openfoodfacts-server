﻿package Blogs::Index;

######################################################################
#
#	Package	Index
#
#	Author:	Stephane Gigandet
#	Date:	06/08/10
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&get_fileid2
					&normalize
					&decode_html
					&decode_html_utf8
					&decode_html_entities
					
					
					&normalize
					
					$memd
					%texts
					
					$debug
					
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use utf8;

use vars @EXPORT_OK ;
use strict;
use utf8;

use Blogs::Store qw/:all/;
use Blogs::Config qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;

use CGI qw/:standard escape unescape/;
use Time::Local;
use Cache::Memcached::Fast;
use Digest::MD5 qw(md5);
use URI::Escape;
use URI::Escape::XS;
use HTML::Defang;
#use Text::Unaccent::PurePerl "unac_string";
use Text::Unaccent "unac_string";
use DateTime;
use Image::Magick;

use Encode qw/from_to decode encode/;
require Encode::Detect;
use HTML::Entities qw(decode_entities);

#use POSIX qw(locale_h);
#use locale;
#setlocale(LC_CTYPE, "fr_FR");   # May need to be changed depending on system
# -> setting a locale makes unac_string fail to unaccent... :-(


# Initialize exported variables

$memd = new Cache::Memcached::Fast {
	'servers' => [ "127.0.0.1:11211" ],
	'utf8' => 1,
};

%texts = ();


opendir DH2, "$data_root/lang" or die "Couldn't open $data_root/lang : $!";
foreach my $langid (readdir(DH2)) {
	next if $langid eq '.';
	next if $langid eq '..';
	# print STDERR "reading texts for lang $langid\n";
	next if ((length($langid) ne 2) and not ($langid eq 'other'));

	if (-e "$data_root/lang/$langid/texts") {
		opendir DH, "$data_root/lang/$langid/texts" or die "Couldn't open the current directory: $!";
		foreach my $textid (readdir(DH)) {
			next if $textid eq '.';
			next if $textid eq '..';
			$textid =~ s/\.html//;
			defined $texts{$textid} or $texts{$textid} = {};
			$texts{$textid}{$langid} = 1;
			# print STDERR "Display : loaded text $langid/$textid\n";
		}
		closedir(DH);
	}
}
closedir(DH2);

# Initialize internal variables
# - using my $variable; is causing problems with mod_perl, it looks
# like inside subroutines below, they retain the first value they were
# called with. (but no "$variable will not stay shared" warning).
# Converting them to global variables.
# - better solution: create a class?

use vars qw(
);

$debug = 1 ;	# Set to a non null value to get debug messages

sub unac_string_stephane($) {
	my $s = shift;

	$s =~ s/à|á|â|ã|ä|å/a/ig;
	$s =~ s/ç/c/ig;
	$s =~ s/è|é|ê|ë/e/ig;
	$s =~ s/ì|í|î|ï/i/ig;
	$s =~ s/ñ/n/ig;
	$s =~ s/ò|ó|ô|õ|ö/o/ig;
	$s =~ s/ù|ú|û|ü/u/ig;
	$s =~ s/ý|ÿ/y/ig;
	$s =~ s/œ|Œ/oe/g;
	$s =~ s/æ|Æ/ae/g;	

	
	return $s;
}

sub normalize($) {

	my $s = shift;
	
	# Remove comments
	$s =~ s/(<|\&lt;)!--(.*?)--(>|\&gt;)//sg;
	$s =~ s/<style(.*?)<\/style>//sg;
	# Remove scripts
	$s =~ s/<script(.*?)<\/script>//isg;	
	
	# Remove open comments
	$s =~ s/(<|\&lt;)!--(.*)//sg;



	# Add line feeds instead of </p> and </div> etc.
	$s =~ s/<\/(p|div|span|blockquote)>/\n\n/ig;
	$s =~ s/<\/(li|ul|ol)>/\n/ig;
	$s =~ s/<br( \/)?>/\n/ig;

	# Remove "<= blabla" on recettessimples.fr
	$s =~ s/<=//g;
	
	# Remove tags
	$s =~ s/<(([^>]|\n)*)>//g;

	$s =~ s/&nbsp;/ /g ;
	$s =~ s/&#160;/ /g ;
	
	$s =~ s/\s+/ /g;

	return $s;
}


sub get_fileid2($)
{
	my $file = shift; # canon_blog or canon_tag

	# !!! commenting line below, because of possible double decoding
	#$file = decode("utf8",$file);
		
	$file = decode("utf8", $file);

	#$file = unac_string('UTF-8',$file);
	$file = unac_string_stephane($file);
	
	$file = lc($file);	

	$file =~ s/[^a-zA-Z0-9-]/-/g;
	$file =~ s/-+/-/g;
	$file =~ s/^-//;
	$file =~ s/-$//;
	
	return $file;	
}


sub decode_html($)
{
	my $string = shift;
	
	my $encoding = "windows-1252";
	if ($string =~ /charset=(.?)utf(-?)8/i) {
		$encoding = "UTF-8";
	}
	else {
		#from_to($string, "windows-1252", "utf8");
	}
	# following doesn't work now that we have use utf8 instead of use bytes;
	#elsif ($string =~ /é|à|è/) {
	#	$encoding = "UTF8";
	#	print STDERR "decode_html : string contains utf8 accents ? \n";
	#}
	my $utf8 = $string;
	if (not utf8::is_utf8($string)) {
		$utf8 = decode($encoding, $string);
	}
	#my $utf8 = decode("UTF8", $string);

	print STDERR "\n\ndecode_html : encoding: $encoding \n\n";
	$utf8 = decode_entities($utf8);	
	
	return $utf8;
}

sub decode_html_utf8($)
{
	my $utf8 = shift;
	
	$utf8 = decode_entities($utf8);	
	
	return $utf8;
}

sub decode_html_entities($)
{
	my $string = shift;
	
	# utf8::is_utf8($string) or $string = decode("UTF8", $string);
	
	utf8::is_utf8($string) or utf8::decode($string);
	
	my $utf8 = decode_entities($string);
	
	if (0 and ($utf8 =~ /Ã/)) { # doesn't work
		# double encoding?
		$utf8 =~ s/Ã©/é/g;
		$utf8 =~ s/Ã´/ô/g;
		$utf8 =~ s/Ã»/û/g;
		$utf8 =~ s/Ã¨/è/g;
		$utf8 =~ s/Ã®/î/g;
		$utf8 =~ s/Ãª/ê/g;
		$utf8 =~ s/Ã /à/g;
	}
		
	return $utf8;
}


1;