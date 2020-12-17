#!/usr/bin/perl

use JSON::XS;
use Data::Dumper;

use strict;

my $username = "null",
my $password = "null",

my $cdcDictionary = qx(cat tape-values.json);
my $cdcDictionaryHash = decode_json($cdcDictionary);


my @icd10File = qx(cat ./allvalid2011-idc10-dictionary);
my $idc10Hash;
foreach my $line(@icd10File){
	next if $line =~ "Deleted ";
	$line =~ s/\r|\n//g;
	$line =~ s/\s+$//;
	chomp($line);
	#print $line."\n";
	my @dictLine = split(/\s+/, $line, 3);
	my $dictLine;
	$dictLine[2] =~ s/"//g;
   $dictLine[1] =~ s/\.//g;
	$idc10Hash->{$dictLine[1]} = $dictLine[2];
}
print Dumper($idc10Hash->{J969});


#print Dumper($cdcDictionaryHash);

my $filename = $ARGV[0];
my $docid=0;
open(FH, '<', $filename) or die $!;
my $docid = 0;

while(<FH>){
   my $mortalityRecord;
   chomp($_);
   $_ =~ s/\r|\n//g;
   $_ = " ".$_;
   #print $_."\n";
   my @linePositions = split(//, $_);
   my $linePositions;
   #unshift @linePositions, '';
   #print Dumper(@linePositions);
#exit;
   foreach my $tapeLocation (sort keys %{ $cdcDictionaryHash->{Tape}->{Location} }) {
      next if $cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{es_field_name} eq "RESERVED";
      my($locationStart, $locationEnd) = split(/-/, $tapeLocation);
      $locationEnd = $locationStart if !$locationEnd;
     
      my $arrayCounter = $locationStart;
      my $rawValue;
      if($locationEnd == $locationStart){
         $rawValue = $linePositions[$arrayCounter]
      }else{
      do{
            $rawValue .= $linePositions[$arrayCounter];
            #print "Array Sample:".$linePositions[$arrayCounter]."\n";
            ++$arrayCounter;
         }while $arrayCounter < $locationEnd +1;
      }
      next if !$rawValue || $rawValue =~ /^ *$/;
       print "-----------------------------------------------\n";
      print "Data Line:".$_,"\n";
      print "Tape Locations:".$tapeLocation."\n";
      print "Raw Value:".$rawValue."\n";
      print "Definition:".$cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{definition}."\n";
      print "ES Field:".$cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{es_field_name}."\n";
      my $useValue = $rawValue;
      $useValue = $cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{values}->{$rawValue} if exists $cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{values}->{$rawValue};
      print "Value:".$useValue."\n";
      my $rawStart;
      my $startCounter = 0;
      foreach my $positionElement(@linePositions){
         $rawStart .= $positionElement;
         ++$startCounter;
         if($startCounter == $locationStart){
            $rawStart .= "start -->";
         }

      }
      print "Raw Start:".$rawStart."\n";
      print "Summary:".$cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{summary}."\n";
      if($cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{definition} =~ 'Axis Condition' && $cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{definition} !~ "Number of"){
         my $cleanCode = $rawValue;
         $cleanCode = substr($rawValue, 2) if $rawValue =~ /^\d/;
         $cleanCode =~ s/^\s+|\s+$//g;
         print "Clean Code:".$cleanCode."\n";

         print "Condition Decode:".$idc10Hash->{$cleanCode}."\n";
         $useValue = $idc10Hash->{$cleanCode};
      }
      print "-----------------------------------------------\n";
      $mortalityRecord->{$cdcDictionaryHash->{Tape}->{Location}->{$tapeLocation}->{es_field_name}} = $useValue;

   }
   print Dumper($mortalityRecord);
   my $sendJSON = encode_json($mortalityRecord);
print "---------------------\n";
print $sendJSON."\n";
print "---------------------\n";

my $curlIt = <<EOF;

curl -u$username:$password -X PUT "http://192.168.2.229:9200/mortality99/_doc/$docid?pretty" -H 'Content-Type: application/json' -d'
$sendJSON
'
EOF
print "Send This Curl:".$curlIt."\n";
my $doIt = qx($curlIt);
print "Output:".$doIt."\n";
++$docid;
}




