#!/usr/bin/perl
use Modern::Perl '2014';
use autodie;
use Text::CSV;
use IO::Prompter;
use utf8;
use Unicode::Normalize;
use Carp;
my $file;
my $out_file;
my $pre = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>";
my $header =
    '<gpx xmlns="http://www.topografix.com/GPX/1/1" '
  . 'xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" '
  . 'creator="Gords little hack version .02" version="1.1" '
  . 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
  . 'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 '
  . 'http://www.topografix.com/GPX/1/1/gpx.xsd '
  . 'http://www.garmin.com/xmlschemas/GpxExtensions/v3 '
  . 'http://www8.garmin.com/xmlschemas/GpxExtensions/v3/GpxExtensionsv3.xsd">';

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
open my $output_fh, '>:encoding(utf8)', "$out_file"
  or carp "Can't open $out_file $!";
say $output_fh "$pre\n$header\n";
close $output_fh;
my $csv = Text::CSV->new(
	{
		binary           => 1,
		auto_diag        => 1,
		sep_char         => ',',
		allow_whitespace => 1,
		escape_char      => undef
	}
) or carp( "Cannot use CSV: " . Text::CSV->error_diag() );
open my $file_fh, '<:encoding(Latin1)', "$file"
  or carp "Can't open $file $!";
my @all = <$file_fh>;
close $file_fh;

foreach my $it (@all) {
	$it =~ s/&amp,/&amp; /g;         # fix up a stupid line before we parse it
	$csv->parse($it);
	my @columns = $csv->fields();
	my $lat     = $columns[0];
	my $lon     = $columns[1];
	my $name    = $columns[2];
	my $desc    = join( ' ', splice @columns, 3 )
	  ; #removes elements 3 to the end from array_ref and joins them with a space
	$name = $name . " (NOP)" if $desc =~ /NOP/;    # for Walmart
	$name = fix_it($name);
	$desc = fix_it($desc);
	open $output_fh, '>>:encoding(utf8)', "$out_file"
	  or carp "Can't open $out_file $!";
	say $output_fh "  <wpt lat=\"$lat\" lon=\"$lon\">";
	say $output_fh "    <name>$name</name>";
	say $output_fh "    <desc>$desc</desc>";
	say $output_fh "  </wpt>";
	close $output_fh;
}
open $output_fh, '>>:encoding(utf8)', "$out_file"
  or carp "Can't open $out_file $!";
say $output_fh "</gpx>";
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
	$temp =~ s/&[^amp]/&amp;/g;
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
