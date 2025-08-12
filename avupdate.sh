#!/usr/bin/ksh
# avupdate.sh
#
# Powertech Anti-Virus update script for stand-alone systems.
#
# This script sets and maintains the log files from the avupdate command.
#
# ================================================================================
#
# NOTICE:
# THIS SCRIPT IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND.
#
# ================================================================================
#
# PRE-REQUISITE:
# If you want the avupdate logfile emailed in the event of a non-zero return code
# you must ensure that sendmail is running with an approriate SMTP relay
# configured and you have updated /opt/sgav/notify.sh to point to your email
# address.
#
# ================================================================================
#
#   AUTHOR: Mike Davison
#     DATE: 14th January 2021
# REVISION: 1.1
#
# CHANGE LOG:
# DATE      WHO?  WHAT?
# ========  ====  ================================================================
# 14/01/21  MD    Initial version
# 30/11/21  MD    Bug fix for log file cleaning and additional logfile text
# 15/12/21  MD    Changed date format of logfiles to by YYYMMDD
#           MD    Changed to use avscan.conf option avupdate_email to control
#                 when emails are sent
#                 Updated avupdate to tee to console and logfile.
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

##############################
# Log prefix name to search for
##############################
log_prefix="avupdate_*"

##############################
# default config file
##############################
config_file="/opt/sgav/avscan.conf"
[ ! -f $config_file ] && echo "ERROR: Configuration file not found at $config_file" && exit 1

##############################
# Extract log directory
##############################
log_directory=`egrep "^option log_directory" $config_file | awk '{print $3}'`
[ ! -d $log_directory ] && echo "ERROR: avscan.conf logfile directory set, but not found:" $log_directory && exit 1

##############################
# Set the log filename using a unqiue date/time
##############################
log_file=$log_directory"/avupdate_"$datestamp
log_name="avscan_$datestamp.TXT"

##############################
# Extract log file retention
##############################
log_history=`egrep "^option log_history" $config_file | awk '{print $3}'`
[ $log_history -eq 0 -o $log_history -gt 365 ] && echo "ERROR: avscan.conf log history value should be between 1 and 365 ["$log_history"]" && exit 1
log_history="+"$log_history

##############################
# Email when?
##############################
log_error=`egrep "^option avupdate_email" $config_file | awk '{print $3}'`
[ $log_error -lt 0 -o $log_error -gt 1 ] && echo "ERROR: avscan.conf avupdate_email value should be 0 or 1 ["$log_error"]" && exit 1


##################################################
# Comparator:
# Set to -ne to only receive when avupdate errors
# Set to -ge to receive all log files
##################################################
case $log_error in
     0 ) compare="-ge";;
     1 ) compare="-ne";;
esac

################################################################################
# find files in $log_directory that are >= $log_history days old and remove them
################################################################################
echo "Powertech Anti-Virus from Helpsystems" | tee $log_file
echo "=====================================" | tee -a $log_file
echo " INFO: avupdate settings " | tee -a $log_file
echo " " | tee -a $log_file
echo " log_directory:" $log_directory | tee -a $log_file
echo "   log_history:" $log_history | tee -a $log_file
echo " " | tee -a $log_file
echo " Cleaning log files:" | tee -a $log_file
echo "find $log_directory -name $log_prefix -type f -mtime $log_history " | tee -a $log_file
find $log_directory -name $log_prefix -type f -mtime $log_history | while read fn; do
     echo "Cleaning:" $fn | tee -a $log_file
     rm $fn
done
echo " " | tee -a $log_file
echo " INFO: Fetching updates from McAfee" | tee -a $log_file

####################################
# Run avupdate and trap return code
####################################
/opt/sgav/avupdate 2>&1 | tee -a $log_file
rc=$?

################################################
# email or not, based on the comparator
################################################
if [ $rc $compare 0 ]
   then ####################################
        # Set shell variables for notify.sh
        ####################################
        HOSTNAME=`hostname`; export HOSTNAME
        PTAV_NOTIFICATION="avupdate failure"; export PTAV_NOTIFICATION

        ###################################
        # Mail the logfile using notify.sh
        ###################################
        cat $log_file | /opt/sgav/notify.sh
fi

exit $rc

