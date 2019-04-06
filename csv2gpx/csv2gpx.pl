#!/usr/bin/perl
# file_test.pl by Gordon Croft
# Copyright (c) 2019 Gordon Croft
#

use Modern::Perl '2014';
use English qw( -no_match_vars );
use Carp;
use Tk;
use Text::CSV;
use Geo::Gpx;
use utf8;
use Unicode::Normalize;
use Carp;
use Encode::Guess;
my %hash;
my $hashref = \%hash;
my $mw      = MainWindow->new;
my $lab1    = $mw->Label(
	-font        => 'Helvetica 12',
	-justify     => 'left',
	-wraplength  => 350,
	-borderwidth => 20,
	-background  => 'Cornsilk',
	-text =>
"Enter a file name in the entry box or click on the \"Browse\" buttons to select a file name using the file selection dialog."
)->pack;

foreach my $i (qw(open save)) {
	my $f   = $mw->Frame;
	my $lab = $f->Label(
		-text        => "Select a file to $i: ",
		-anchor      => 'e',
		-borderwidth => 5,
		-background  => 'NavajoWhite'
	);
	$hash{"$i"} = '';
	my $ent = $f->Entry( -width => 20, -textvariable => \$hashref->{$i} );
	my $but = $f->Button(
		-text    => "Browse ...",
		-command => sub { fileDialog( $mw, $ent, $i ) }
	);
	$lab->pack( -side => 'left' );
	$ent->pack( -side => 'left', -expand => 'yes', -fill => 'x' );
	$but->pack( -side => 'left' );
	$f->pack( -fill => 'x', -padx => '1c', -pady => 3 );
}
my $go_bt = $mw->Button( -text => 'Done', -command => \&do_it )->pack;
my $cbf = $mw->Frame->pack( -fill => 'x', -padx => '1c', -pady => 3 );
my $fd = 0;
$cbf->Checkbutton(
	-text     => 'Check Button',
	-variable => \$fd,
)->pack( -side => 'left' );
MainLoop;

sub fileDialog {
	my $w         = shift;
	my $ent       = shift;
	my $operation = shift;
	my @types;
	my $file;

	#   Type names		Extension(s)	Mac File Type(s)
	#
	#---------------------------------------------------------
	@types = ( [ "CSV files", '.csv' ], [ "All files", '*' ] );
	if ( $operation eq 'open' ) {
		$file = $w->getOpenFile( -filetypes => \@types );
	}
	else {
		$file = $w->getSaveFile(
			-filetypes   => \@types,
			-initialfile => 'Untitled'
		);
	}
	if ( defined $file and $file ne '' ) {
		$ent->delete( 0, 'end' );
		$ent->insert( 0, $file );
		$ent->xview('end');
	}
}

sub _removeCachedFileDialogs {
	my $mw     = $mw->MainWindow;
	my $remove = sub {
		my $t = shift;
		return if ( !UNIVERSAL::isa( $t, "Tk::Toplevel" ) );
		delete $t->{'tk_getOpenFile'};
		delete $t->{'tk_getSaveFile'};
	};
	$remove->($mw);
	$mw->Walk($remove);
}

sub do_it {
	my $file     = $hashref->{open};
	my $out_file = $hashref->{save};
	return unless length( $file && $out_file ) > 0;
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
}

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
