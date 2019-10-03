#!/usr/bin/perl
# csv2gpx.pl by Gordon Croft
# Copyright (c) 2018 Gordon Croft
#

use Modern::Perl '2014';
use autodie;
use Text::CSV qw(csv);
use Geo::Gpx;
use IO::Prompter;
use utf8;
use Unicode::Normalize;
use Carp;
my $file;
my $out_file;

if ( $#ARGV == 1 ) {
	$file     = shift;
	$out_file = shift;
}
else {
	$file = prompt q{Please enter file name to convert from CSV to GPX :},
	  -complete => 'filenames';
	$out_file = prompt q{Please enter the output file name :},
	  -complete => 'filenames';
}
my $csv = Text::CSV->new(
	{
		binary           => 1,
		allow_whitespace => 1,
	}
) or carp( "Cannot use CSV: " . Text::CSV->error_diag() );
my $gpx = Geo::Gpx->new();
my $stuff = csv( in => "$file" );
foreach my $it (@$stuff) {
	my $name = fix_it( @$it[2] );
	my $desc = fix_it( @$it[3] );
	$name = $name . " (NOP)" if $desc =~ /NOP/;    # for Walmart
	my $wpt = {
		lat  => @$it[0],
		lon  => @$it[1],
		name => $name,
		desc => $desc,
	};
	$gpx->add_waypoint($wpt);
}
my $xml = $gpx->xml('1.0');
open my $output_fh, '>:encoding(UTF-8)', "$out_file"
  or carp "Can't open $out_file $!";
say $output_fh $xml;
close $output_fh;

sub fix_it {
	my ($temp) = @_;
	return unless $temp;
	$temp =~ tr/\x00-\x09//d;
	$temp =~ tr/\x0b-\x1f//d;
	$temp =~ s/[\n|\r]/ /g;
	$temp =~ s/</&lt;/g;
	$temp =~ s/>/&gt;/g;
	$temp =~ s/`/'/g;
	$temp =~ s/\x92/'/g;
	$temp =~ s/ *, +/,/;
	$temp =~ s/\s+$//g;
	$temp =~ s/&amp,/&amp; /g;
	$temp =~ s/&nbsp;map/ /g;
	$temp =~ s/&amp;bsp;map//g;
	$temp =~ s/\s+/ /g;
	$temp =~ s/^,//;
	$temp =~ s/&nbsp;/ /g;
	$temp = NFKD($temp);
	$temp =~ s/\p{NonspacingMark}//g;
	return $temp;
}
