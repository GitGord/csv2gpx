#!/usr/bin/perl
# csv2gpx.pl by Gordon Croft
# Copyright (c) 2018 Gordon Croft
#

use Modern::Perl '2014';
use autodie;
use Text::CSV;
use Geo::Gpx;
use IO::Prompter;
use utf8;
use Unicode::Normalize;
use Carp;
use Encode::Guess;
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
open my $file_fh, '<', "$file"
  or carp "Can't open $file $!";
my @all = <$file_fh>;
close $file_fh;
my $gpx = Geo::Gpx->new();

foreach my $it (@all) {
	$it = big_guess($it);
	$it =~ s/&amp,/&amp; /g;    # fix up a stupid line before we parse it
	$csv->parse($it);
	my @columns = $csv->fields();
	my $name    = $columns[2];
	my $desc    = join( ' ', splice @columns, 3 )
	  ; #removes elements 3 to the end from array_ref and joins them with a space
	$name = $name . " (NOP)" if $desc =~ /NOP/;    # for Walmart
	$name = fix_it($name);
	$desc = fix_it($desc);
	my $wpt = {
		lat  => $columns[0],
		lon  => $columns[1],
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
	$temp =~ s/&nbsp;/ /g;
	$temp =~ s/\\xE9/\x{00E9}/g;
	$temp =~ s/\\xE8/\x{00E8}/g;
	$temp =~ s/\\xF4/\x{00F4}/g;
	$temp = NFKD($temp);
	$temp =~ s/\p{NonspacingMark}//g;
	return $temp;
}

sub big_guess {
	my ($guess) = @_;
	my $decoder = guess_encoding( $guess, 'utf8' );
	$decoder = guess_encoding( $guess, 'iso-8859-1' ) unless ref $decoder;
	die "Decoding failed $decoder" unless ref $decoder;
	$guess = $decoder->decode($guess);
	return $guess;
}
