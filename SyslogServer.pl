#!/usr/bin/perl 
#	This creates an open syslog socket ready for writing
#       Data is logged and logs rotated
## -----------------------------------------------------------------
# Author:               Harry Podciborski
# -----------------------------------------------------------------
# Basic Syslog server example for Windows & Linux
###################################################################
# PP Options for packing
#  pp  -l LIBEAY32__.dll -l zlib1__.dll -o logger64.exe mpl_logger.pl
###################################################################
use strict;
use Net::Syslogd;					## Syslog module
use Log::Log4perl qw(:easy);		## Rotate Write to Logs
use Log::Dispatch::FileRotate;		## Rotate Llogs
use Fcntl ':flock';	## one instance of this program can run at a time;

my $PROG = "SYSLog Server";
my $VERSION = "1.2";

my $conf_log = "./logging.conf";    
sub get_log_filename() {			### referenced back from the configuration file, this is required.
    return "./log/syslog.log";
}
############################################################
Log::Log4perl::init($conf_log);		## read config file
my $log = Log::Log4perl->get_logger('hp_syslog');		## definition within config file

$SIG{CHLD} = sub { $log->logdie("$PROG:$VERSION was interupted and $$ killed, likely by a user the session running the program");};
$SIG{KILL} = sub { $log->logdie("$PROG:$VERSION was interupted and $$ killed, likely by a user the session running the program");};
$SIG{INT} = sub {  $log->logdie("$PROG:$VERSION was interupted and $$ killed, likely by a user the session running the program");};
$SIG{TERM} = sub { $log->logdie("$PROG:$VERSION was terminated $$ and killed within the OS");};
$SIG{HUP} = sub {  $log->logdie("$PROG:$VERSION was HUPED and killed within the $$ OS");};

### Check to make sure there is only one instance ###
open SELF, "< $0" or die;
unless ( flock SELF, LOCK_EX | LOCK_NB ) {
    $log->logdie("You cannot run two instances of this program, a process is still running");
}


my ($SYSLOG_PORT,$SYSLOG_HOST,$SYSLOG_TIMEOUT);

$SYSLOG_PORT='5101';              ## Default SYslog Port - may conflict in Linux
$SYSLOG_HOST='localhost';         ## Localhost or Hostname
$SYSLOG_TIMEOUT='10';    		  ## Timeout in seconds for socket
##################################################################

$log->warn("$PROG:$VERSION: started process.. $$ on port $SYSLOG_PORT"); 
my $syslogd = new Net::Syslogd(LocalPort=>"$SYSLOG_PORT",LocalAddr=>"$SYSLOG_HOST",timeout=>"$SYSLOG_TIMEOUT")
  or $log->logdie("Error creating Syslogd listener: ".Net::Syslogd->error);
 
## depending on the settings in the conf file, will depend on what is printed into the logs
## all messages will arrive here but no all are processed - edit as need be
## ORDER=  trace,debug,info,warn,error,critical
## no error handling or exceptions..!
while (1) {			## maintain logging
    my $message = $syslogd->get_message();
    if (!defined($message)) {
        #printf "$0: %s\n", Net::Syslogd->error;
        $log->log($ERROR,"Syslog Error: ".Net::Syslogd->error);
    } elsif ($message == 0) {
        next;
    }
    
    if (!defined($message->process_message())) {
        $log->warn("Error in SYSlog, no process_message".Net::Syslogd->error);
    } else {
        my $sev = $message->severity;
        my $msg = $message->message;

        if($sev eq "Warning") {
            if($log->is_warn()) { 
                $log->log($WARN,"$msg");
            }
        } elsif($sev eq "Error") {
            if($log->is_error()) { 
                $log->log($ERROR,"$msg"); 
            }              
        } elsif($sev eq "Debug") {
            if($log->is_debug()) { 
                $log->log($DEBUG,"$msg");
            }
        } elsif($sev eq "Informational") {
            if($log->is_info()) { 
                $log->log($INFO,"$msg");
            }
        } elsif($sev eq "Notice") {
            if($log->is_trace()) { 
                $log->log($TRACE,"$msg");
            }
        } elsif($sev eq "Critical") {
            if($log->is_fatal()) { 
                $log->log($FATAL,"$msg");
            }
        } elsif($sev eq "Emergency") {  ### can be used if needed
            ## IGNORE
        } else {
            ### ignore
        }                            
    }
}