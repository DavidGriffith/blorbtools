#!/usr/bin/perl -w

#  scanBlorb: a perl script for scanning Blorb files
#  (c) Graham Nelson 1998 (original script)
#  (c) Richard Poole 2004 (modifications)

use strict;
use Getopt::Long;

require 5.6.0;

my $buffer;
my $dump_images;
my %images;

GetOptions("dump-images" => \$dump_images);
my $input_filename = $ARGV[0];

my $version = "scanBlorb 2.0";

my ($sec,$min,$hour,$mday,$month,$year) = (localtime(time))[0, 1, 2, 3, 4, 5];

my $blorbdate = sprintf("%04d/%02d/%02d at %02d:%02d.%02d",
                 $year + 1900, $month + 1, $mday, $hour, $min, $sec);

print STDOUT "$version [executing on $blorbdate]\n\n";

open (BLORB, $input_filename) or die "Can't load $input_filename.";
binmode(BLORB);

read BLORB, $buffer, 12;

my ($groupid, $length, $type) = unpack("NNN", $buffer);

$groupid == 0x464F524D or die "Not a valid FORM file!\n";
$type == 0x49465253 or die "Not a Blorb file!\n";

print "File length is apparently $length bytes\n";

my ($size, $pos);

for($pos = 12; $pos < $length; $pos += $size + ($size % 2) + 8) {
	my $chunkdata;

	read(BLORB, $buffer, 8) == 8
		or die("Incomplete chunk header at $pos\n");

	$size = (unpack("NN", $buffer))[1]; # second word of header
	my $type = substr($buffer, 0, 4);
	printf "%06x: $type chunk with $size bytes of data\n", $pos;

	read(BLORB, $chunkdata, $size) == $size
		or die("Incomplete chunk at $pos\n");
	if($size % 2) { read(BLORB, $buffer, 1); }

	# optional chunks
	if ($type eq "(c) " or $type eq "AUTH" or $type eq "ANNO") {
		print "$type: $chunkdata\n";
	}

	# zcode executable: look into its magic insides
	if ($type eq "ZCOD") {
		my ($version, $release) = (unpack("CCn", $chunkdata))[0,2];
	    my $serialcode = substr($chunkdata, 0x12, 6);
	    print "\t$release.$serialcode (version $version)\n";
	}

	# glulx executable: look into its magic insides
	if($type eq "GLUL") {
		my ($major, $minor, $minimus) = (unpack("xxxxnCC", $chunkdata))[0,1,2];
		print "\tGlulx version $major.$minor.$minimus\n";
	}

	# game identifier chunk: probably only if no executable chunk
	if ($type eq "IFhd") {   
	    my $release = unpack("n", substr($chunkdata,0,3));
	    my $serialcode = substr($chunkdata, 2, 6);
	    print "\t$release.$serialcode\n";
	}

	# release number chunk: zcode games only
	if ($type eq "RelN") {
		my $relnum = unpack("n", $chunkdata);
	    print "\tRelease number $relnum\n";
	}

	# image chunk
	if($type eq "PNG " or $type eq "JPEG") {
		next unless $dump_images;
		my $errstr = sprintf("No resource information for image at %0x06x\n", $pos);
		my $filename = $images{$pos} . ($type eq "PNG " ? ".png" : ".jpg")
			or warn($errstr), next;
		open IMAGEFH, ">$filename"
			or warn "Failed to open handle for $filename: $!\n", next;
		binmode IMAGEFH;
		local $\ = undef;
		print IMAGEFH $chunkdata;
		close IMAGEFH
			or warn "Failed to close handle for $filename: $!\n", next;
	}

	# resource index chunk: always present
	if ($type eq "RIdx") {
		print "\tResources index:\n";

		my $numres = unpack("N", $chunkdata);
		substr($chunkdata, 0, 4) = "";
		while($numres--) {
			my($usage, $number, $start) =
				unpack("a4 NN NN", substr($chunkdata, 0, 12, ""));
			printf("\t\t%06x: %s %d\n", $start, $usage, $number);
			$images{$start} = $number if $usage eq "Pict";
		}
	}
}

close(BLORB);

