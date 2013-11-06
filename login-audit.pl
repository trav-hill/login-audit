#!/usr/bin/perl -w
#
#Read input /var/log/secure & determine UserID: logged into how many servers, how many times
#
#Written by Travis Hill
use strict;                          ### Invoking pragmas/modules & Initializing variables 
use Getopt::Long;
sub usage ();
my %count;
my $serverlist  = "";
my $clusterlist = "";
my $display     = "";
my $grouplist   = "";
my $jldshstart  = "jldsh -e";
my $jldshparms  = "";
my $jldshscript = "-s '/export/home/travis.hill/scripts/loginaudit2.pl' |";
 
GetOptions(
    'servers|s=s' => \$serverlist,     #list of servers to be ran against
    'group|g=s'   => \$grouplist,      #cluster.PROD group to be ran against
    'display|d=s' => \$display,        #display format
    'cluster|c=s' => \$clusterlist,    #clusterfile to be run against
    'help|h|?'    => sub { usage() }
) or usage();
if ( $display eq "" ) {
    $display = "usd";
}
if ( $display !~ /usd|uds|sdu|sud|dsu|dus/ ) {
    print "Invalid display type...\n";
    usage();
}
if ( ( $serverlist eq "" ) && ( $grouplist eq "" ) && ( $clusterlist eq "" ) )
{
    $serverlist = "xxxxxxxxxxxx";
}
########### parse the secure log
if ( ( $clusterlist ne "" ) && ( $grouplist ne "" ) ) {
    $jldshparms = "c $clusterlist -g $grouplist ";
}
elsif ( $clusterlist ne "" ) {
    $jldshparms = "c $clusterlist ";
}
elsif ( $grouplist ne "" ) {
    $jldshparms = "g $grouplist ";
}
else {
    $jldshparms = "w $serverlist ";
}
my $jldshstmt = "$jldshstart" . "$jldshparms" . "$jldshscript";
print "Please wait while I gather the data...\n";
open( SECURELOG, $jldshstmt );
LINE: while (<SECURELOG>) {
    if ((/^\s+$/) || (/filehandle/)) {
        next LINE;
    }
    if (/^ERROR/) {
        print "Invalid server(s), jldsh failed\n";
        exit;
    }
    chomp;
    my ( $dshJunk,$logline ) = split (/\:\s/,$_,2);
    if ( $logline eq "") {
        next LINE;
    }
    my ( $userID, $node, $month, $day, $logins )
        = split( /\s+/, $logline, 6 );
    if ( $userID eq "" ) {
        next LINE;
}
    $userID = ( lc $userID );
    my $uldate = "$month $day";
    if ( $display eq "usd" ) {
        $count{$userID}{$node}{$uldate} = $logins;
    }
    elsif ( $display eq "dsu" ) {
        $count{$uldate}{$node}{$userID} = $logins;
    }
    elsif ( $display eq "uds" ) {
        $count{$userID}{$uldate}{$node} = $logins;
    }
    elsif ( $display eq "dus" ) {
        $count{$uldate}{$userID}{$node} = $logins;
    }
    elsif ( $display eq "sud" ) {
        $count{$node}{$userID}{$uldate} = $logins;
    }
    else {
        $count{$node}{$uldate}{$userID} = $logins;
    }
}
########### check for, then generate output
unless ( keys %count ) {
    print "No users logged in ???, check usage\n";
    exit;
}
 
sub sortdate {
   my $result;
   my %months = (
      Jan => 1,
      Feb => 2,
      Mar => 3,
      Apr => 4,
      May => 5,
      Jun => 6,
      Jul => 7,
      Aug => 8,
      Sep => 9,
      Oct => 10,
      Nov => 11,
      Dec => 12 );
 
   my ($a_month, $a_day) = split (/\s+/, $a, 2);
   my ($b_month, $b_day) = split (/\s+/, $b, 2);

   if ($months{$a_month} == $months{$b_month}) {
      $result =  ($a_day <=> $b_day) ;
   }
   else {
      $result = ( $months{$a_month} <=> $months{$b_month} );
   }
   return $result;
}
 

if ( $display eq "usd" ) {
    foreach my $user ( sort keys ( %count )) {
        foreach my $server ( sort keys %{ $count{$user} } ) {
            foreach my $ldate ( sort sortdate %{ $count{$user}{$server} } ) {
                print
                    "$user logged into $server on  $ldate, $count{$user}{$server}{$ldate} times\n";
            }
        }
    }
}
elsif ( $display eq "uds" ) {
    foreach my $user ( sort keys (%count) ) {
        foreach my $ldate ( sort keys %{ $count{$user} } ) {
            foreach my $server ( sort sortdate keys  %{ $count{$user}{$ldate} } ) {
                print
                    "$user on $ldate, logged into $server $count{$user}{$ldate}{$server} times\n";
            }
        }
    }
}
elsif ( $display eq "dsu" ) {
    foreach my $ldate ( sort sortdate keys ( %count )) {
        foreach my $server ( sort keys %{ $count{$ldate} } ) {
            foreach my $user ( sort keys %{ $count{$ldate}{$server} } ) {
                print
                    "On $ldate, on $server, $user logged in $count{$ldate}{$server}{$user} times\n";
            }
        }
    }
 
}
elsif ( $display eq "dus" ) {
    foreach my $ldate ( sort sortdate keys ( %count )) {
        foreach my $user ( sort keys %{ $count{$ldate} } ) {
            foreach my $server ( sort keys %{ $count{$ldate}{$user} } ) {
                print
                    "On $ldate, $user logged into $server $count{$ldate}{$user}{$server} times\n";
            }
        }
    }
}
elsif ( $display eq "sdu" ) {
    foreach my $node ( sort keys %count ) {
        foreach my $ldate ( sort sortdate keys  %{ $count{$node} } ) {
            foreach my $user ( sort keys %{ $count{$node}{$ldate} } ) {
                print
                    "On $node, on $ldate, $user logged in $count{$node}{$ldate}{$user} times\n";
            }
        }
    }
}
elsif ( $display eq "sud" ) {
    foreach my $node ( sort keys %count ) {
        foreach my $user ( sort keys %{ $count{$node} } ) {
            foreach my $ldate ( sort sortdate keys  %{ $count{$node}{$user} } ) {
                print
                    "On $node, $user on $ldate logged in $count{$node}{$user}{$ldate} times\n";
            }
        }
    }
}
############################################
sub usage () {
 
    print "\n\n";
    print <<EOF;
    usage: LoginAudit.pl [-d -s -c -g -h]
 
    Pipe (|) the output from 'cat /var/log/secure' to this script to
    determine who logged onto a server(s) and how many times per server
    Note: you can check multiple Linux servers by using the jldsh
    command
 
    Options
 
    -d or --display <display>
        Output display format; 'usd' for by UserId, server, date (default); possible
        options are: usd, uds, dus, dsu, sud, or sdu.

   -s or --servers <serverlist>
        List of servers to run loginaudit against;
        *Defaults to s0013bdc,s0013cdc if no clusterfile, group, or servers are
        passed as arguments, this parm will be bypassed if there is a group and/or
        clusterfile arguement(s)
 
    -g or --group <grouplist>
        Group(s) or lump(s) in cluster.PROD file to run loginaudit.pl against
 
    -c or --clusterlist <clusterlist>
        clusterfile to run loginaudit.pl against
 
    -h or --help or ? <Help>
        Option to display the execution options for the
        login audit (LoginAudit.pl)
 
EOF
    exit;
}
##################################################
# loginaudit2.pl (referenced above) 
##################################################
#!/usr/bin/perl -w
#
#Read input /var/log/secure & determine UserID: logged into how many servers, how many times
#
use strict;
use Getopt::Long;
#my $date=0;
my $servOS;
my $HELP='';
my $userlog;
sub usage ();
GetOptions(
#    'date|d=i' => \$date,     #number of days ago
    'help|h|?' => sub { usage() } )
    or usage();
 
########### set date
#use POSIX qw(strftime);
#my $epdate = (time() - (86400 * $date));
#my $daymon = strftime( "%b %e", localtime($epdate));
#my $year   = strftime( "%Y",    localtime($epdate));
########### set hashes
my %count;
my $xdomain;
my $date;
my $server;
my $userID;
#my %total;
########### determine OS
$servOS =(`uname`);
chomp $servOS;
if ($servOS ne "Linux") {
  $userlog = "/var/log/auth";
} else {
  $userlog = "/var/log/secure";
}
########### parse the secure log
open (SECURELOG, $userlog);
LINE:  while (<SECURELOG>) {
#  if (/^\s+$/)  {
#    next LINE;
    if (/user\:\s\<\S*\>/)  {
      chomp;
      my ($month,$day,$time,$node,$logline) = split (/\s+/,$_,5);
      my ($junk,$userIDex) = split (/user\:\s+\</,$logline,2);
      my ($userIDex2,$junk2) = split (/\>/,$userIDex,2);
      my ($userID,$junk3) = split (/\@/,$userIDex2,2);
      $date = "$month $day";
      $server = $node;
      $userID = (lc $userID);
      $count{$userID}{$date}++;
    }
#  }
}
########### check for, then generate output
#unless (keys %count) {
#  print "No users logged in $daymon, $year\n";
#  exit;
#}
foreach my $user ( sort keys %count ) {
  foreach my $day (sort keys %{$count{$user}} )  {
    print "$user $server $day $count{$user}{$day}\n";
  }
}
############################################
sub usage () {
 
  print "\n\n";
  print <<EOF;
    usage: LoginAudit.pl [-d -h]
 
    Pipe (|) the output from 'cat /var/log/secure' to this script to
    determine who logged onto a server(s) and how many times per server
    Note: you can check multiple Linux servers by using the jldsh
    command
 
    Options
 
    -d or --date <date>
        Number of days in the past to search for logins
 
    -h or --help or ? <Help>
        Option to display the execution options for the
        login audit (LoginAudit.pl)
 
EOF
exit
}
