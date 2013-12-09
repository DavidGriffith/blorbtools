#!/usr/bin/perl

#  scanBlorb: a perl script for scanning Blorb files
#  (c) Graham Nelson 1998

#$input_filename = '$.Adventure.Blorb.blorbfile';
$input_filename = $ARGV[0];
chomp($input_filename);

$version = "scanBlorb 1.0";

($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime(time);

$blorbdate = sprintf("%02d%02d%02d at %02d:%02d.%02d",
                 $year, $month + 1, $mday, $hour, $min, $sec);

print STDOUT "$version [executing on $blorbdate]\n\n";

open (BLORB, $input_filename) or die "Can't load $input_filename.";
binmode(BLORB);

read BLORB, $buffer, 12;

($w1, $w2, $w3) = unpack("NNN", $buffer);

if ($w1 != 0x464F524D) { print "Not a valid FORM file\n"; }
if ($w3 != 0x49465253) { print "Doesn't carry the Blorb magic word\n"; }

printf STDOUT ("File length claimed to be %06x = $w2 bytes\n", $w2);

$posn = 12;

while ($posn < $w2)
{   # Read in a chunk

    $headlength = read BLORB, $buffer, 8;

    if ($headlength != 8)
    {   printf STDOUT ("Error: incomplete chunk header at %06x\n", $posn);
        $posn = $w2;        
    }
    else
    {   ($junk, $size) = unpack("NN", $buffer);
        $type = substr($buffer, 0, 4);
        printf STDOUT ("%08x: %s chunk with %06x = %d bytes of data\n",
            $posn, $type, $size, $size);

        $chopflag = 0;
        if ($size % 2 == 1) { $size = $size + 1; $chopflag = 1; }

        $bodylength = read BLORB, $chunkdata, $size;
        if ($bodylength != $size)
        {   printf STDOUT ("Error: incomplete chunk at %08x\n", $posn);
            $posn = $w2;
        }
        else
        {   $posn = $posn + $size + 8;
            if ($chopflag == 1) { chop($chunkdata); }

            if ($type eq "(c) ")
            {   print STDOUT "          $chunkdata\n";
            }
            if ($type eq "AUTH")
            {   print STDOUT "          $chunkdata\n";
            }
            if ($type eq "ZCOD")
            {   ($version, $ignore, $release) = unpack("CCn", $chunkdata);
                $serialcode = substr($chunkdata, 0x12, 6);
                print STDOUT
                    "          $release.$serialcode (version $version)\n";
            }
            if ($type eq "IFhd")
            {   
                $release = unpack("n", substr($chunkdata,0,3));
                $serialcode = substr($chunkdata, 2, 6);
                print STDOUT
                    "          $release.$serialcode\n";
            }
            if ($type eq "RelN")
            {   $relnum = unpack("n", $chunkdata);
                print STDOUT "          Release number $relnum\n";
            }
            if ($type eq "RIdx")
            {   print STDOUT "          Resources index:\n";

                $numres = unpack("N", $chunkdata);
                for ($x = 0; $x < $numres; $x = $x + 1)
                {   $indexentry = substr($chunkdata, 4 + $x*12, 12);
                    $usagestring = substr($indexentry, 0, 4);
                    ($usage, $number, $start) = unpack("NNN", $indexentry);
                    printf STDOUT ("          %06x: %s %d\n",
                         $start, $usagestring, $number);
                }
            }
        }
    }
}

close(BLORB);

