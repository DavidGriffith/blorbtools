#!/usr/bin/perl
# ---------------------------------------------------------------------------
#  perlBlorb: a perl script for creating Blorb files
#  (c) Graham Nelson 1998
# ---------------------------------------------------------------------------

$temp_prefix     = 'ram:';   # Prefix for location of temporary directory
$file_sep        = '.';      # Character used to separate directories in
                             # pathnames (on most systems this will be /)

$blurb_filename  = '$.Adventure.Blorb.BLURB';
$output_filename = '>$.Adventure.Blorb.blorbfile';

$version = "perlBlorb 1.03";

($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime(time);

$blorbdate = sprintf("%02d%02d%02d at %02d:%02d.%02d",
                 $year, $month + 1, $mday, $hour, $min, $sec);

$temp_dir = sprintf("%sB_%02d%02d%02d", $temp_prefix, $hour, $min, $sec);

print STDOUT "! $version [executing on $blorbdate]\n";
print STDOUT "! The blorb spell (safely protect a small object ";
print STDOUT "as though in a strong box).\n";

$blurb_line = 0;

$chunk_count = 0;
$important_count = 0;
$total_size = 0;
$max_resource_num = 0;
$scalables = 0;
$repeaters = 0;
$next_pnum = 1;
$next_snum = 3;

$r_stdx = 600; $r_stdy = 400;
$r_minx = 0; $r_maxx = 0;
$r_miny = 0; $r_maxy = 0;
$resolution_on = 0;

# ---------------------------------------------------------------------------

sub ensure_tempdir
{   if (opendir(TDIR, $temp_dir))
    {   closedir(TDIR);
    }
    else
    {   if (mkdir($temp_dir, 0) == 0)
        { die("Fatal error: unable to create working directory $temp_dir");
        }
    }
}

sub remove_tempdir
{   if (opendir(TDIR, $temp_dir))
    {   @allfiles = grep !/^\./, readdir TDIR;
        closedir(TDIR);

        foreach $file (@allfiles)
        {   $fullfile = sprintf("%s%s%s", $temp_dir, $file_sep, $file);
            unlink $fullfile;
        }

        rmdir($temp_dir);
    }
}

# ---------------------------------------------------------------------------

sub error
{   local $m = $_[0];
    print STDERR "$blurb_filename, line $blurb_line: Error: $m\n";
}

sub fatal
{   local $m = $_[0];
    remove_tempdir();
    die "$blurb_filename, line $blurb_line: Fatal error: $m\n";
}

# ---------------------------------------------------------------------------

sub four_word
{   local $n = $_[0];
    print CHUNK sprintf("%c%c%c%c", ($n / 0x1000000),
                                    ($n / 0x10000)%0x100,
                                    ($n / 0x100)%0x100,
                                    ($n)%0x100);
}

sub two_word
{   local $n = $_[0];
    print CHUNK sprintf("%c%c", ($n / 0x100),
                                  ($n)%0x100);
}

sub one_byte
{   local $n = $_[0];
    print CHUNK sprintf("%c", $n);
}

sub begin_chunk
{   local $id = $_[0];
    local $cnum = $_[1];
    local $chunk_filename = $_[2];
    $chunk_opened = 0;

    if ($cnum > $max_resource_num) { $max_resource_num = $cnum; }

    if ($chunk_filename eq "")
    {   $chunk_filename = sprintf('%s%s%d',
            $temp_dir, $file_sep, $chunk_count);

        open(CHUNK, sprintf(">%s",$chunk_filename))
            or fatal("unable to create temporary file $chunk_filename");
        binmode CHUNK;
        $chunk_opened = 1;
    }

    $chunk_filename_array[$chunk_count] = $chunk_filename;

    $chunk_important_array[$chunk_count] = 0;
    if (($id eq "Pict") || ($id eq "Snd1") || ($id eq "Snd2")
        || ($id eq "Snd3") || ($id eq "Exec"))
    {   $chunk_important_array[$chunk_count] = 1;
        $important_count = $important_count + 1;        
    }

    $chunk_id_array[$chunk_count] = $id;
    $chunk_number_array[$chunk_count] = $cnum;
    $chunk_offset_array[$chunk_count] = $total_size;
}

sub end_chunk
{   local $size, $blen, $buffer;

    if (chunk_opened == 1)
    {   close(CHUNK);
    }

    $chunk_filename = $chunk_filename_array[$chunk_count];

    open(CHUNK, $chunk_filename)
        or fatal("unable to open $chunk_filename for size counting");
    binmode(CHUNK);

    for ($size = 0, $blen = 1; $blen > 0; )
    {   $blen = read(CHUNK, $buffer, 1024);
        $size = $size + $blen;
    }
    close(CHUNK);

    if ($chunk_id_array[$chunk_count] ne "Snd1")
    {   $size = $size + 8;
    }

    $chunk_size_array[$chunk_count] = $size;

    if ($size % 2 == 1) { $size = $size + 1; }

    $total_size = $total_size + $size;

    $chunk_count = $chunk_count + 1;
}

sub author_chunk
{   local $t = $_[0];
    begin_chunk("AUTH", 0, "");
    print CHUNK $t;
    end_chunk();
}

sub copyright_chunk
{   local $t = $_[0];
    begin_chunk("(c) ", 0, "");
    print CHUNK $t;
    end_chunk();
}

sub release_chunk
{   local $t = $_[0];
    begin_chunk("RelN", 0, "");
    two_word($t);
    end_chunk();
}

sub palette_simple_chunk
{   local $t = $_[0];
    begin_chunk("Plte", 0, "");
    one_byte($t);
    end_chunk();
}

sub picture_chunk
{   local $n = $_[0];
    local $f = $_[1];
    begin_chunk("Pict", $n, $f);
    end_chunk();
}

sub sound1_chunk
{   local $n = $_[0];
    local $f = $_[1];
    begin_chunk("Snd1", $n, $f);
    end_chunk();
}

sub sound2_chunk
{   local $n = $_[0];
    local $f = $_[1];
    begin_chunk("Snd2", $n, $f);
    end_chunk();
}

sub sound3_chunk
{   local $n = $_[0];
    local $f = $_[1];
    begin_chunk("Snd3", $n, $f);
    end_chunk();
}

sub executable_chunk
{   local $f = $_[0];
    begin_chunk("Exec", 0, $f);
    end_chunk();
}

# ---------------------------------------------------------------------------

sub identify
{   print STDOUT "Constant $_[0] = $_[1];\n";
}

sub interpret
{   local $command = $_[0];
    if ($command =~ /^\s*\!/)
    {   # This is a comment line
        return;
    }
    if ($command =~ /^\s*$/m)
    {   # This is a blank line
        return;
    }
    if ($command =~ /^\s*copyright\s+"(.*)"/)
    {   copyright_chunk($1);
        return;
    }
    if ($command =~ /^\s*release\s+(\d*)/)
    {   release_chunk($1);
        return;
    }
    if ($command =~ /^\s*resolution\s+(\d*)x(\d*)\s*(.*)$/m)
    {   $r_stdx = $1; $r_stdy = $2;
        $r_minx = 0; $r_maxx = 0;
        $r_miny = 0; $r_maxy = 0;

        $resolution_on = 1;

        $rest = $3;
        if ($rest =~ /^\s*min\s+(\d*)x(\d*)\s*$/m)
        {   $r_minx = $1;
            $r_miny = $2;
            return;
        }
        if ($rest =~ /^\s*max\s+(\d*)x(\d*)\s*$/m)
        {   $r_maxx = $1;
            $r_maxy = $2;
            return;
        }
        if ($rest =~ /^\s*min\s+(\d*)x(\d*)\s*max\s+(\d*)x(\d*)\s*$/m)
        {   $r_minx = $1;
            $r_miny = $2;
            $r_maxx = $3;
            $r_maxy = $4;
            return;
        }
        if ($rest =~ /^\s*$/m)
        {   return;
        }
    }
    if ($command =~ /^\s*palette\s+(\d*)\s*bit/)
    {   if (($1 == 16) || ($1 == 32))
        {   palette_simple_chunk($1);
            return;
        }
        error("palette can only be 16 or 32 bit");
        return;
    }
    if ($command =~ /^\s*palette\s*\{(.*)$/m)
    {   $rest = $1;
        begin_chunk("Plte", 0, "");
        while (not($rest =~ /^\s*\}/))
        {   if ($rest =~ /^\s*$/m)
            {   $rest = <BLURB> or fatal("end of blurb file in 'palette'");
                $blurb_line = $blurb_line + 1;
            }
            else
            {   if ($rest =~
            /^\s*([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})\s*(.*)$/m)
                {   $rest = $4;
                    one_byte(hex($1));
                    one_byte(hex($2));
                    one_byte(hex($3));
                }
                else
                {   $rest =~ /^\s*(\S+)\s*(.*)$/m;
                    error("palette entry not six hex digits: $1");
                    $rest = $2;
                }
            }
        }
        end_chunk();
        return;
    }
    if ($command =~ /^\s*storyfile\s+"(.*)"\s+include\s*$/m)
    {   executable_chunk($1);
        return;
    }
    if ($command =~ /^\s*storyfile\s+"(.*)"/)
    {   open(IDFILE, $1) or fatal("unable to open story file $1");
        binmode(IDFILE);
        begin_chunk("IFhd", 0, "");
        $version = unpack("C", getc(IDFILE));
        print STDOUT "! Identifying v$version story file $1\n";

        read IDFILE, $buffer, 1;
        one_byte(unpack("C",getc(IDFILE)));
        one_byte(unpack("C",getc(IDFILE)));
        read IDFILE, $buffer, 14;
        one_byte(unpack("C",getc(IDFILE)));
        one_byte(unpack("C",getc(IDFILE)));
        one_byte(unpack("C",getc(IDFILE)));
        one_byte(unpack("C",getc(IDFILE)));
        one_byte(unpack("C",getc(IDFILE)));
        one_byte(unpack("C",getc(IDFILE)));
        read IDFILE, $buffer, 4;
        one_byte(unpack("C",getc(IDFILE)));
        one_byte(unpack("C",getc(IDFILE)));
        one_byte(0);
        one_byte(0);
        one_byte(0);
        end_chunk();
        close(IDFILE);
        return;
    }
    if ($command =~ /^\s*picture\s+([a-zA-Z_0-9]*)\s*"(.*)"\s*(.*)$/m)
    {   $pnumt = $1; $pfile = $2; $rest = $3;

        if ($pnumt =~ /^\d+$/m)
        {   $pnum = $pnumt;
            if ($pnum < $next_pnum)
            {   error("picture number must be >= $next_pnum to avoid clash");
            }
            else
            {   $next_pnum = $pnum + 1;
            }
        }
        else
        {   $pnum = $next_pnum;
            $next_pnum = $next_pnum + 1;
            if ($pnumt ne "")
            {   identify("PICTURE_$pnumt", $pnum);
            }
        }

        picture_chunk($pnum, $pfile);

        if ($rest =~ /^\s*$/m)
        {   return;
        }

        $scalables = $scalables + 1;
        $resolution_on = 1;

        $p_picno[$scalables] = $pnum;
        $p_stdp[$scalables] = 1; $p_stdq[$scalables] = 1;
        $p_minp[$scalables] = -1; $p_maxp[$scalables] = -1;
        $p_minq[$scalables] = -1; $p_maxq[$scalables] = -1;

        if ($rest =~ /^\s*scale\s+(\d*)\/(\d*)\s*$/m)
        {   $p_stdp[$scalables] = $1;
            $p_stdq[$scalables] = $2;
            return;
        }
        if ($rest =~ /^\s*scale\s+max\s*(\d*)\/(\d*)\s*$/m)
        {   $p_maxp[$scalables] = $1;
            $p_maxq[$scalables] = $2;
            return;
        }
        if ($rest =~ /^\s*scale\s+min\s*(\d*)\/(\d*)\s*$/m)
        {   $p_minp[$scalables] = $1;
            $p_minq[$scalables] = $2;
            return;
        }
        if ($rest =~
            /^\s*scale\s+min\s*(\d*)\/(\d*)\s+max\s*(\d*)\/(\d*)\s*$/m)
        {   $p_minp[$scalables] = $1;
            $p_minq[$scalables] = $2;
            $p_maxp[$scalables] = $3;
            $p_maxq[$scalables] = $4;
            return;
        }

        if ($rest =~ /^\s*scale\s*(\d*)\/(\d*)\s*max\s*(\d*)\/(\d*)\s*$/m)
        {   $p_stdp[$scalables] = $1;
            $p_stdq[$scalables] = $2;
            $p_maxp[$scalables] = $3;
            $p_maxq[$scalables] = $4;
            return;
        }
        if ($rest =~ /^\s*scale\s*(\d*)\/(\d*)\s*min\s*(\d*)\/(\d*)\s*$/m)
        {   $p_stdp[$scalables] = $1;
            $p_stdq[$scalables] = $2;
            $p_minp[$scalables] = $3;
            $p_minq[$scalables] = $4;
            return;
        }
        if ($rest =~
  /^\s*scale\s*(\d*)\/(\d*)\s*min\s*(\d*)\/(\d*)\s+max\s*(\d*)\/(\d*)\s*$/m)
        {   $p_stdp[$scalables] = $1;
            $p_stdq[$scalables] = $2;
            $p_minp[$scalables] = $3;
            $p_minq[$scalables] = $4;
            $p_maxp[$scalables] = $5;
            $p_maxq[$scalables] = $6;
            return;
        }
    }

    if ($command =~ /^\s*sound\s+([a-zA-Z_0-9]*)\s*"(.*)"\s*(.*)$/m)
    {   $snumt = $1;
        $fxfile = $2;
        $repeats = $3;

        if ($snumt =~ /^\d+$/m)
        {   $snum = $snumt;
            if ($snum < $next_snum)
            {   error("sound number must be >= $next_snum to avoid clash");
            }
            else
            {   $next_snum = $snum + 1;
            }
        }
        else
        {   $snum = $next_snum;
            $next_snum = $next_snum + 1;
            if ($snumt ne "")
            {   identify("SOUND_$snumt", $snum);
            }
        }

        if ($repeats eq "music")
        {   sound2_chunk($snum, $fxfile);
            return;
        }
        if ($repeats eq "song")
        {   sound3_chunk($snum, $fxfile);
            return;
        }

        sound1_chunk($snum, $fxfile);
        if ($repeats =~ /^repeat\s+forever\s*$/m)
        {   $looped_fx[$repeaters] = $snum;
            $looped_num[$repeaters] = 0;
            $repeaters = $repeaters + 1;
            return;
        }

        if ($repeats =~ /^repeat\s+(\d*)\s*$/m)
        {   $looped_fx[$repeaters] = $snum;
            $looped_num[$repeaters] = $1;
            $repeaters = $repeaters + 1;
            return;
        }

        if ($repeats eq "") { return; }
    }

    $command =~ m/^\s*(\S+)\s*(.*)$/m;

    if (($1 eq "copyright") || ($1 eq "palette") || ($1 eq "picture")
        || ($1 eq "release") || ($1 eq "resolution") || ($1 eq "sound")
        || ($1 eq "storyfile"))
    {   error("incorrect syntax for $1 command");
        return;
    }

    error("no such blurb command: $1");
}

# ---------------------------------------------------------------------------

ensure_tempdir();

author_chunk("$version on $blorbdate");

open (BLURB, $blurb_filename)
    or fatal("can't open blurb file $blurb_filename");

while ($c = <BLURB>)
{   $blurb_line = $blurb_line + 1;
    interpret($c);
}

close BLURB;

if ($resolution_on == 1)
{   
    begin_chunk("Reso", 0, "");
    four_word($r_stdx);
    four_word($r_stdy);
    four_word($r_minx);
    four_word($r_miny);
    four_word($r_maxx);
    four_word($r_maxy);

    for ($x=1; $x<=$scalables; $x=$x+1)
    {   four_word($p_picno[$x]);
        four_word($p_stdp[$x]);
        four_word($p_stdq[$x]);

        if ($p_minp[$x] == -1)
        {   $p_minp[$x] = $p_stdp[$x]; $p_minq[$x] = $p_stdq[$x]; }

        if ($p_maxp[$x] == -1)
        {   $p_maxp[$x] = $p_stdp[$x]; $p_maxq[$x] = $p_stdq[$x]; }

        four_word($p_minp[$x]);
        four_word($p_minq[$x]);
        four_word($p_maxp[$x]);
        four_word($p_maxq[$x]);    
    }
    end_chunk();
}

if ($repeaters > 0)
{   begin_chunk("Loop", 0, "");
    for ($x=0; $x<$repeaters; $x = $x + 1)
    {   four_word($looped_fx[$x]);
        four_word($looped_num[$x]);        
    }
    end_chunk();
}

# ---------------------------------------------------------------------------

# Calculate the IFF file size

$past_idx_offset = 12 + 12 + 12*$important_count;
$iff_size = $past_idx_offset + $total_size;

# Now construct the IFF file from the chunks

open(CHUNK, $output_filename)
    or fatal("unable to open $output_filename for output");
binmode(CHUNK);

print CHUNK "FORM";
four_word($iff_size - 8);
print CHUNK "IFRS";

print CHUNK "RIdx";
four_word(4 + $important_count*12);
four_word($important_count);

for ($x = 0; $x < $chunk_count; $x = $x + 1)
{   if ($chunk_important_array[$x] == 1)
    {   $type = $chunk_id_array[$x];
        if (($type eq "Snd1") || ($type eq "Snd2") || ($type eq "Snd3"))
        {   $type = "Snd ";
        }
        print CHUNK $type;
        four_word($chunk_number_array[$x]);
        four_word($past_idx_offset + $chunk_offset_array[$x]);
    }
}

for ($x = 0; $x <= $max_resource_num; $x = $x + 1)
{   $picture_numbering[$x] = -1;
    $sound_numbering[$x] = -1;
}

$pcount = 0; $scount = 0;
for ($x = 0; $x < $chunk_count; $x = $x + 1)
{   $type = $chunk_id_array[$x];
    if ($type eq "Pict")
    {   $type = "PNG ";
        $picture_numbering[$chunk_number_array[$x]] = $x;
        $pcount = $pcount + 1;
    }
    if ($type eq "Snd1")
    {   $type = "AIFF";
        $sound_numbering[$chunk_number_array[$x]] = $x;
        $scount = $scount + 1;
    }
    if ($type eq "Snd2")
    {   $type = "MOD ";
        $sound_numbering[$chunk_number_array[$x]] = $x;
        $scount = $scount + 1;
    }
    if ($type eq "Snd3")
    {   $type = "SONG";
        $sound_numbering[$chunk_number_array[$x]] = $x;
        $scount = $scount + 1;
    }
    if ($type eq "Exec")
    {   $type = "ZCOD";
    }

    if ($type ne "AIFF")
    {   print CHUNK $type;
        four_word(($chunk_size_array[$x]) - 8);
    }

    $chunk_filename = $chunk_filename_array[$x];
    open(CHUNKSUB, $chunk_filename)
        or fatal("unable to read data from $chunk_filename");
    binmode(CHUNKSUB);
    
    while(read CHUNKSUB, $portion, 16384)
    {   print CHUNK $portion;
    }
    close(CHUNKSUB);

    if (($chunk_size_array[$x] % 2) == 1)
    {   printf CHUNK sprintf("%c", 0);
    }
}

close(CHUNK);

print STDOUT "! Completed: size $iff_size bytes ";
print STDOUT "($pcount pictures, $scount sounds)\n";

remove_tempdir();

# ---------------------------------------------------------------------------
