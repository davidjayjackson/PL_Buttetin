#!/usr/bin/perl -w
#use Astro::Time;

%obsconst=&obsconst;
$yymm="1901";

open(Q,"<Jan_2019.CSV");
chomp($head=<Q>);
$head="";
while(<Q>){
  chomp;
  @d=split(/,/,$_);
  $x={
    JD=>$d[0],
    OBS=>$d[4],
    YYMM=>$yymm,
    YEAR=>$d[1],
    MONTH=>$d[2],
    DAY=>$d[3],
    SEE=>$d[5],
    G=>$d[6],
    S=>$d[7],
    W=>$d[8]
  };
  push(@rawdata,$x);
}
close(Q);


open(X,">foo.foo");
#print X "   JD         g    s   c     kc   log(c) log(kc)  w   Obs.      Obs. Name           day   see     UT     g     s     R     ng    sg    ns    ss   Obs.    Remark\n";
print X "   JD         g    s   c     kc   log(c) log(kc)  w   Obs.      Obs. Name           day   see  \n";
foreach $x (@rawdata) {
# The following are existing values... no calculations done yet.
  $obs=$x->{OBS};
  $yymm=$x->{YYMM};
  $c=$x->{LINE};
  $d=$obsconst{$obs};
  $xc=$d->{XC};
  $xw=$d->{XW};
  $name=$d->{NM};
  $name=substr($name,0,20);
  $day=$x->{DAY};
  $seeing=$x->{SEE};
  $ut="1200";
  $g=$x->{G};
  $s=$x->{S};
  $W=$x->{W};
  $ng="";
  $sg="";
  $ns="";
  $ss="";
# $luse=substr($c,0,61);
# $day=substr($luse,1,5);
# $seeing=substr($luse,7,5);
# $ut=substr($luse,13,6);
# $g=substr($luse,19,6);
# $s=substr($luse,25,6);
# $W=substr($luse,31,6);
# $ng=substr($luse,37,6);
# $sg=substr($luse,43,6);
# $ns=substr($luse,49,6);
# $ss=substr($luse,55,6);
  $day=~s/\s+//g;
  $seeing=~s/\s+//g;
  $ut=~s/\s+//g;
  $g=~s/\s+//g;
  $s=~s/\s+//g;
  $W=~s/\s+//g;
  $ng=~s/\s+//g;
  $sg=~s/\s+//g;
  $ns=~s/\s+//g;
  $ss=~s/\s+//g;
  $jd=$x->{JD};

# *Now* we start calculating things...
 # print "OBSIE:$obs\t$jd\t$W\n";
  $count=$s+(10*$g);
  if($count != $W){
    print "oops, W is not the same as count...\n";
#   $W=$count;
  }
  $kcount=int(10000.*($count*$xc)+0.5)/10000.;
  if($kcount <= 0){
     $kcount = 1. ;}
    #print "oops, kcount = 0...\n";}
  #print "kcount:$kcount\tcount:$count\txc:$xc\n";
  if($count > 0) {
    $logcount=log($count)/log(10.);
    $logkcount=log($kcount)/log(10.);
    $logcount=int(10000.*($logcount)+0.5)/10000.;
    $logkcount=int(10000.*($logkcount)+0.5)/10000.;
    $logcount=substr($logcount."0000",0,6);
    $logkcount=substr($logkcount."0000",0,6);
    if($logcount !~ /\./){$logcount="1.0000";}
    if($logkcount !~ /\./){$logkcount="1.0000";}
  } else {
    $logcount="-.----";
    $logkcount="-.----";
  }

  $uth=substr($ut,0,2);
  $utm=substr($ut,2,2);
  $utf=($uth+($utm/60.))/24.;
  $yy=substr($yymm,0,2);
  if($yy < 40){
    $yy+=2000;
  } else {
    $yy+=1900;
  }
  $mm=substr($yymm,2,2);
#  $jd=mjd2jd(cal2mjd($day,$mm,$yy,$utf));
#  $jd-=2400000.;
## NOTE: THE FOLLOWING LINE IS REQUIRED TO MAKE THE "JD" CONSISTENT WITH OLD REPORTS.
## IS THERE A BUG IN THE *OLD* CODE?
# $jd-=1;
  if($jd < 2455000){
    $jd+=734867;
  }
  $jd-=2400000.;

  $c="NO INPUT LINE...";
  #print "OBSIE:$obs\n";
  printf X "%10.4f %4i %4i %4i %7.2f %6s %6s %5.3f %-4s %-20s   |%s\n",$jd,$g,$s,$W,$kcount,$logcount,$logkcount,$xw,$obs,$name,$seeing;
#  printf X "%10.4f %4i %4i %4i %7.2f %6s %6s %5.3f %-4s %-20s   |%s\n",$jd,$g,$s,$W,$kcount,$logcount,$logkcount,$xw,$obs,$name,$c;


}
close(X);
open(X,"<foo.foo");
while(<X>){
  @d=split(/,/,$_);
  $v={ JD=>$d[0], LN=>$_ };
  push(@linefoo,$v);
}
close(X);
@linetoo=sort {$a->{JD}<=>$b->{JD}} @linefoo; #line 136 can't match to old JD -)
#@linetoo=sort {$a->{JD} != $b->{JD}} @linefoo; #line 136 has to be numeric -)
open(X,">aavso.srt");
foreach $v (@linetoo) {
  $l=$v->{LN};
  print X "$l";
}
close(X);
unlink("foo.foo");


sub obsconst {
  open(A,"<obsconst_2017.dat");
  while(<A>){
    chomp;
    $_=~s/[\r\n
]//g;
    $len=length($_);
    $l=$len-24;
    $oc=substr($_,0,4);
    $xc=substr($_,8,5);
    $xw=substr($_,16,5);
    $name=substr($_,24,$l);
    $oc=~s/\s+//g;
    $xc=~s/\s+//g;
    $xw=~s/\s+//g;
    $name=~s/^\s+//;
    $name=~s/\s+$//;
    if($xc eq "") {
      $xc=1.0;
    }
    if($xw eq "") {
      $xw=0.1;
    }
    $x={
      OC=>$oc,
      XC=>$xc,
      XW=>$xw,
      NM=>$name
    };
    $obsdat{$oc}=$x;
  }
  close(A);
  return %obsdat;
}