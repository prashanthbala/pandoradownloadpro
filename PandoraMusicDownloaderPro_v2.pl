#!/usr/bin/perl
use LWP::Simple;  
use Getopt::Long;
use warnings;
use strict;
local $| = 1; #to print immediately instead of waiting for the buffer

my $marker;

print "Enter Pandora Account Name : ";
my $accnt = <STDIN>;
chomp($accnt);

if($accnt!~ /^\w+$/ )
{
   die ( " \n Account Name Invalid \n The Account name is found by looking at your pandora profile page \n www.pandora.com/people/<your_account> \n" );
}

my %hash;

my $songPatrn = "trackTitle=";
my $artstPatrn = "title=\"Artist details\">";

my $text="";


$text = get ("http://feeds.pandora.com/feeds/people/$accnt/favorites.xml");
$marker="<p class=\"headline\">";

if ($text =~ /.*?${marker}.*?<p>We couldn't find a user named.*?/gs )
{
   die ( "\n Your Pandora username does not exist on the Pandora server \n");   
}
elsif ($text =~ /.*?${marker}.*?<p>This profile has been marked "private" by the owner and may not be viewed\.  If this is your\s*profile, you will need.*?/gs )
{
   die (" \n Cannot Access Pandora Server, ensure your Pandora profile is set as publicly viewable before using this script\n ");
}
#getting names of bookmarked songs
while ($text =~ /.*?$songPatrn"(.*?)".*?$artstPatrn(.*?)</gs )
{
   my $song=$1;
   my $artist=$2;  
   
   #modification 4 :  Correcting some Pandora naming convention mismatch errors &amp for another artist and &eacute for trailing 'e'
   $artist =~ s/&eacute;/e/g;
   $artist =~ s/&amp; //g;
   $song =~ s/&amp; //g;
   #end of modification
   
   $hash{$song}=$artist;  
}

$marker="<a class=\"nobold\" title=\"Listen to this station\"";
$text = get ("http://www.pandora.com/favorites/profile_tablerows_station.vm?webname=".$accnt);

#getting names of songs from each station
while ($text =~ /.*?${marker}.*?title="Go to this station page" href="\/stations\/(.*?)"/gs ) #$1 gets the token of the station for use in next url
{
   my $stationPage = get ("http://www.pandora.com/favorites/station_tablerows_thumb_up.vm?token=".$1."&sort_col=thumbsUpName&sort_order=true"); #url to get list of all songs thumbed up and seeded in the station
   my $temp=$marker;
   $marker="<span class=\"sample_link\"";
   
   while ($stationPage =~ /.*?${marker}.*?${songPatrn}"(.*?)".*?${artstPatrn}(.*?)</gs )
   {
      my $song=$1;
      my $artist=$2;
      
      #modification 4 :  Correcting some Pandora naming convention mismatch errors &amp for another artist and &eacute for trailing 'e'
      $artist =~ s/&eacute;/e/g;
      $artist =~ s/&amp; //g;
      $song =~ s/&amp; //g;
      #end of modification
      
      $hash{$song}=$artist;
   }
   
   $marker=$temp;
}

#print %hash;
my $numSongs=keys %hash;
print "\nTotal of $numSongs songs (ingnoring duplicates) have been found \n";





print "Enter a name for the file that contains the list of songs : ";
my $filName=<STDIN>;
chomp($filName);


if (-e $filName.".txt")
{
   print "Are you sure you want to overwrite ? [y/n] ";
   my $yn=<STDIN>;
   chomp($yn);
   $yn=lc $yn;
   
   die ("\n Exiting since file cannot be overwritten, list of songs dump : %hash \n") if ($yn ne "y");
}

open OUTFILE,">$filName.txt" or die(" \n File could not be opened \n");
my $key;
foreach $key (keys %hash)
{
   print OUTFILE "$key by $hash{$key}\n";
}   
close OUTFILE;





print "Enter a Directory name to store all the new songs : ";
my $dir=<STDIN>;
chomp($dir);

if( -d "./$dir" )
{
   print "Directory exists, overwrite? [y/n] ";
   my $yn= lc ( <STDIN> ) ;
   chomp ($yn);
   
   ( $yn eq "y" ) || die ("Directory exists and cannot overwrite");
}
else
{
   mkdir $dir || die ("Could not make directory");
}

chdir "./$dir" || die ("directory path invalid");




my @unableToDownSongs;

foreach $key (keys %hash)
{
   #Modification for updating file systen instead of downloading whole collection again (for continued usage)
   if (-e "$key - $hash{$key}.mp3")
   {
      next;
   }
   #end of modification
   
   my $page=0;
   my $gotSong=0;
   
   my $alreadyTriedwithRem=0;
   
   my $artist;
   my $song;

   while (!($gotSong))
   {
      $page++;
      
      if (!($alreadyTriedwithRem))
      {
         $artist=$hash{$key};
         $song=$key;
      }
      
      my $isModified=0;
      
      #modification 2 another level of processing to remove non-word character from the url
      if ( $song =~ s/[^a-zA-Z0-9_ ]//g | $artist =~ s/[^a-zA-Z0-9_ ]//g )
      {
         $isModified=1;
      }
      #end of modification 2
      
      if ($alreadyTriedwithRem)
      {
         $isModified=1; #we need this to be 1 since we have already done the processing b4 (logic necessity)
      }
      
      $song=~s/\s+/-/g;
      $artist=~s/\s+/-/g;
         
      $text=get ( "http://www.mp3-downloads.net/search/mp3/$page/$artist-$song.html" );
      die ("\n No response from the server \n ") if ($text eq "");
      
      $_=$text;
      #print "\n Operating Page : http://www.mp3-downloads.net/search/mp3/$page/$artist-$song.html \n";
      
      while ( !($gotSong) && ( /.*?<div class="listen" align="center">.*?<b>Listen<\/b><\/a><br \/>.*?a href="(.*?)"/gs) )
      {
         #print "\n Trying to download song $song from the link $1 \n";
         my $status = getstore( $1, "$key - $hash{$key}.mp3" );
         if (is_success($status))
         {
            $gotSong=1;
            print ".";
         }
      }
      
      if (/<center><h1>You may be intrested in one of the following:<\/h1><\/center>/s)
      {
         if(!($isModified) || $alreadyTriedwithRem)
         {
           (@unableToDownSongs)=(@unableToDownSongs,"$key by $hash{$key}\n");
           $gotSong=1;
         }
         else
         {
            $artist=$hash{$key};
            $song=$key;
            
            #Since song could not be obtained with modifiers, reprocessing w/o modifiers to ensure file could not be downloaded
            $song =~ s/\(.*?\)//g ; #remove stuff in brackets
            $song =~ s/\s+/ /g; #remove extra whitespace
            $song =~ s/^\s+//; #remove leading and trailing whitespace
            $song =~ s/\s+$//;
            
            
            $artist =~ s/\(.*?\)//g ; #remove stuff in brackets
            $artist =~ s/\s+/ /g; #remove extra whitespace
            $artist =~ s/^\s+//; #remove leading and trailing whitespace
            $artist =~ s/\s+$//;
            
            $page=0;
            $alreadyTriedwithRem=1;
         }
      }
   }
}

print "\n\n";

my $numargs=@unableToDownSongs;

if($numargs>0)
{
   print "The following songs could not be downloaded : \n";
   print @unableToDownSongs;
}
