#!/usr/bin/ksh
# avscan.sh
#
# Powertech Anti-Virus update scan script for stand-alone systems.
#
# This script scans and maintains the log files from the avscan command.
#
# NB: Parameters are passed to avscan without validation.
#
# ================================================================================
#
# NOTICE:
# THIS SCRIPT IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND.
#
# ================================================================================
#
# PRE-REQUISITE:
# If you want the avscan logfile emailed you must ensure that sendmail is running
# with an appropriate SMTP relay configured and you have updated
# /opt/sgav/notify.sh to point to your email address.
#
# ================================================================================
#
#   AUTHOR: Mike Davison
#     DATE: 14th October 2021
# REVISION: 1.2
#   STORED: mdaix732
#
# CHANGE LOG:
# DATE      WHO?  WHAT?
# ========  ====  ================================================================
# 14/10/21  MD    Initial version
# 30/11/21  MD    Bug fix for log file cleaning and additional logfile text
# 20/12/21  MD    Changed log file date format to be YYYYMMDDHHMMSS
# 14/08/25  MD    Check for .conf file in same directory as .sh file so it does 
#                  not have to be in /opt/sgav
#                 Hostname now incorporated into the log file name
#                 Hostname added to body of email
#                 Hostname corrected env. var for email send to PTAV_HOSTNAME
#                 Name changes from HelpSystems to Fortra.
#
##################################################################################

######################
# Uncomment for debug
######################
#set -x

##############################
# Set constants and variables
##############################
datestamp=`date +"%y%m%d%H%M%S"`
tempfile="/tmp/avscan.sh.$datestamp"
templog="/tmp/avscan.sh.log.$datestamp"
options=""
include='-r '
exclude=""
incsplit=""
excsplit=""

##############################
# default config file
##############################
########################################################
# find out which directory the avscan.sh is running it
# We expect the avscan.conf to be in the same directory
########################################################
file=$0
if [[ "$file" != /* ]]; then
    file="$PWD/$file"
fi

###########################################
# Strip filename, keep only directory path
###########################################
dirpath="${file%/*}"
config_file=$dirpath"/"avscan.conf

# config_file="/opt/sgav/avscan.conf"
[ ! -f $config_file ] && echo "ERROR: Configuration file not found at $config_file" && exit 1

hostname=`hostname`
echo $hostname

##############################
# Extract log directory
##############################
log_directory=`egrep "^option log_directory" $config_file | awk '{print $3}'`
[ ! -d $log_directory ] && echo "ERROR: avscan.conf logfile directory set, but not found:" $log_directory && exit 1

##############################
# Set the log filename using a unqiue date/time
##############################
log_name="avscan_"$hostname"_"$datestamp".TXT"
log_file=$log_directory"/"$log_name

##############################
# Extract log file retention
##############################
log_history=`egrep "^option log_history" $config_file | awk '{print $3}'`
[ $log_history -eq 0 -o $log_history -gt 365 ] && echo "ERROR: avscan.conf log history value should be between 1 and 365 ["$log_history"]" && exit 1
log_history="+"$log_history

##############################
# Log prefix name to search for
##############################
log_prefix="avscan_*"

##############################
# Email log content
##############################
log_level=`egrep "^option log_level" $config_file | awk '{print $3}'`
[ $log_level -lt 1 -o $log_level -gt 3 ] && echo "ERROR: avscan.conf log level value should be between 1 and 3 ["$log_level"]" && exit 1

##############################
# Email when?
##############################
log_error=`egrep "^option log_error" $config_file | awk '{print $3}'`
[ $log_error -lt 0 -o $log_error -gt 1 ] && echo "ERROR: avscan.conf log error value should be 0 or 1 ["$log_error"]" && exit 1

##################################################
# Comparator:
# Set to -ne to only receive when avscan errors
# Set to -ge to receive all log files
##################################################
case $log_error in
     0 ) compare="-ge";;
     1 ) compare="-ne";;
esac

##############################
# extract parm 1 and set scan_parms
##############################
parm1=$1
scan_parms=$*
[ "$scan_parms" = "" ] && echo "ERROR: No parameters entered" && exit 1

##############################
# Check for a scan definition
##############################
grepstring="^$parm1"
grep_result=`grep $grepstring $config_file|wc -l`
if [ $grep_result -ge 1 ]
   then echo "$parm1 configuration found."
        grep $grepstring $config_file > $tempfile
        while read scanname type data
           do
              case $type in
                   "opt" ) options=$options" "$data;;
                   "inc" ) include=$include$incsplit$data
                           incsplit=":";;
                   "exc" ) if [ "$exclude" = "" ]
                              then exclude='--exclude '$data
                                   excsplit=":"
                              else exclude=$exclude$excsplit$data
                           fi;;
              esac
           done < $tempfile
#	   if [ "$exclude" != "" ]
#              then exclude=$exclude
#	   fi
scan_parms=$options' '$exclude' '$include
fi

##############################
#remove temp file if it exists
##############################
if [ -f $tempfile ]
   then rm $tempfile
   else echo " INFO: No match on config file for configuration: $parm1";exit 1
fi

####################################
# Write the report header
####################################
echo "Powertech Anti-Virus from Fortra" | tee $log_file
echo "================================" | tee -a $log_file
echo "Scan of: $hostname" | tee -a $log_file
echo " " | tee -a $log_file
echo " INFO: avupdate settings " | tee -a $log_file
echo " " | tee -a $log_file
echo " log_directory:" $log_directory | tee -a $log_file
echo "   log_history:" $log_history | tee -a $log_file
echo " " | tee -a $log_file
################################################################################
# find files in $log_directory that are >= $log_history days old and remove them
################################################################################
echo " INFO: Cleaning old logfiles," $log_history "days old" | tee -a $log_file
echo "find $log_directory -name $log_prefix -type f -mtime $log_history " | tee -a $log_file
find $log_directory -name $log_prefix -type f -mtime $log_history | while read fn; do
     echo "Cleaning:" $fn | tee -a $log_file
     rm $fn
done
echo " " | tee -a $log_file


####################################
# Run avscan and trap return code
####################################
echo " INFO: Starting scan using following command:" | tee -a $log_file
echo " " | tee -a $log_file
echo "       /opt/sgav/avscan" $scan_parms | tee -a $log_file
echo " " | tee -a $log_file
echo " INFO: Scan running, please be patient......."
/opt/sgav/avscan $scan_parms 2>&1 >> $log_file
rc=$?
echo " INFO: Scan complete.  rc=$rc" | tee -a $logfile
echo "=====================================" | tee -a $log_file

################################################
# email or not, based on the comparator
################################################
if [ $rc $compare 0 ]
   then ####################################
        # Set shell variables for notify.sh
        ####################################
        PTAV_HOSTNAME=`hostname`; export PTAV_HOSTNAME
        PTAV_NOTIFICATION="Scan results ($parm1)"; export PTAV_NOTIFICATION

        ###################################
        # Mail the logfile using notify.sh
	# based on the log_level set earlier
        ###################################
	case $log_level in
	1)	PTAV_NOTIFICATION="Scan results ($parm1) - Minimal log"; export PTAV_NOTIFICATION
                head -30 $log_file > $templog
                echo " " >> $templog
		tail -3 $log_file >> $templog
                echo " INFO: Emailing minimal log" | tee -a $logfile
		cat $templog | /opt/sgav/notify.sh ;;

	2)	PTAV_NOTIFICATION="Scan results ($parm1) - Summary log"; export PTAV_NOTIFICATION
                head -30 $log_file > $templog
		cat $log_file | egrep '(ERROR:|VIRUS:|Completed:|quarantined.$)' >> $templog
                echo " INFO: Emailing summary log" | tee -a $logfile
		cat $templog | /opt/sgav/notify.sh ;;

        3)      PTAV_NOTIFICATION="Scan results ($parm1) - Full log"; export PTAV_NOTIFICATION
                # Always send full file as an attachment
                echo " INFO: Emailing full log" | tee -a $logfile
                uuencode $log_file $log_name | /opt/sgav/notify.sh ;;
	esac
fi

####################
# Tidy up tempfiles
####################
[ -f $tempfile ] && rm $tempfile
[ -f $templog ] && rm $templog

exit $rc

