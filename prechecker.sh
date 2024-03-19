#!/bin/bash
# pc.sh
#
# This script is a helpful pre-checker of the requirements of a server BEFORE
# you attempt to install HSOne or PTAV Server to it.
#
# Run this before installing!
#
# Output is helpfully tee'd into a logfile.
#
# ================================================================================
#
# NOTICE:
# THIS SCRIPT IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND.
#
# ================================================================================
#
#   AUTHOR: Mike Davison
#     DATE: 31st October 2023
# REVISION: 1.3
#
# CHANGE LOG:
# DATE      WHO?  WHAT?
# ========  ====  ================================================================
# 12/04/23  MD    Initial version
# 24/08/23  MD    Added check_software routine to check installed packages.
#                 Updated script to cope with a CentOS install.
# 31/10/23  MD    Added timedatectl NTP checking for rhel/centos.
#                 Added counts of checks and summary output.
#
##################################################################################


########################################################
# Set constants
########################################################
datetime=`date +"%Y%m%d%H%M%S"`
logfile='./checker_'$datetime'.txt'
pname=$0
check_count=0
checked_count=0
pass_count=0
fail_count=0
warn_count=0


########################################################
# Functions
########################################################
Check()
{
 echo "---------------------------------------------------------------" | tee -a $logfile
 echo Check $* | tee -a $logfile
 checktext=$*
 result=""
 check_count=`expr $check_count + 1`
}

########################################################
checked()
{
 echo "Checked" | tee -a $logfile
 checked_count=`expr $checked_count + 1`
}

########################################################
pass()
{
 echo "Passed" | tee -a $logfile
 pass_count=`expr $pass_count + 1`
}

########################################################
fail()
{
 echo "FAILED" | tee -a $logfile
 fail_count=`expr $fail_count + 1`
}

########################################################
print_result()
{
[[ -z $result ]] && result="     "
 #echo -n "RESULT:" $result " .... "
 output="RESULT: $result"
 printf '%-55s %s' "$output" | tee -a $logfile
}

########################################################
abort()
{
 echo "CANNOT CONTINUE"
 exit
}

########################################################
message()
{
 output="NOTICE: $*"
 printf '%-55s %s' "$output" | tee -a $logfile
 echo "WARNING" | tee -a $logfile
 warn_count=`expr $warn_count + 1`
}

########################################################
check_directory()
{
 dir=$1; min_space=$2
 ########################################################
 Check at least $min_space Gb space in $dir
 ########################################################
 result=`df --block-size=G $dir|egrep -v ^File|sed 's/G//g'|awk '{print $4}'`
 result=`printf "%.0f\n" $result`
 df -h $dir | tee -a $logfile
 print_result
 [[ $result -ge $min_space ]] && pass || fail
}

########################################################
check_software()
{
########################################################
Check $1 is installed:
########################################################
#echo "yum list installed $1*| egrep -i ^$1" | tee -a $logfile
yum list installed $1*| egrep -i ^$1 | tee -a $logfile
rc=$?
print_result
[[ $rc -eq 0 ]] && pass || fail
}


#-------------------------------------------------------
# Start of main code
#-------------------------------------------------------
echo "===============================================================" | tee -a $logfile
grep "^# REVISION" $pname | tee -a $logfile
echo "Checks starting" | tee -a $logfile

########################################################
Check what is the OS? RHEL or CentOS?
########################################################
result=`cat /etc/os-release | egrep ^ID=|sed 's/"/ /g'|awk '{print $2}'`
print_result
[[ $result = "rhel" || $result = "centos" ]] && pass || fail
os_type=$result

########################################################
Check what is the OS release?
########################################################
result=`cat /etc/os-release | egrep ^VERSION_ID|sed -e 's/\./ /g' -e 's/"/ /g'|awk '{print $2}'`
print_result
[[ $result -ge 7 ]] && pass || fail

########################################################
Check is there enough memory?
########################################################
result=`free -g | egrep ^Mem:|awk '{print $2}'`
print_result
[[ $result -ge 8 ]] && pass || fail

########################################################
Check Sufficent CPUs?
########################################################
result=`lscpu | egrep ^"CPU\(s\)"|awk '{print $2}'`
print_result
[[ $result -ge 4 ]] && pass || fail

########################################################
[[ -d /var/tmp ]] && check_directory /var/tmp 5
[[ -d /tmp ]] && check_directory /tmp 5

########################################################
Check if we have pre-built /opt/helpsystems?
########################################################
if [ -d /opt/helpsystems ]
   then result="Yes";print_result;checked
        ########################################################
        check_directory /opt/helpsystems 5
   else result="No";print_result;checked
        ########################################################
        check_directory /opt 5
fi

########################################################
Check is the hostname and domain set?
########################################################
result=`hostname -f`
print_result;checked

########################################################
Check NTP is configured and running
########################################################
timedatectl status| tee -a $logfile
[[ $os_type = 'rhel' ]] && result=`timedatectl show -p NTP|awk -F= '{print $2}'`
[[ $os_type = 'centos' ]] && result=`timedatectl | egrep "NTP enabled"|awk '{print $3}'`
print_result
[[ $result = 'yes' ]] && pass || fail

########################################################
Check FIPS mode is disabled
########################################################
#result=`fips-mode-setup --check|egrep ^FIPS|awk '{print $4}'`
result=`cat /proc/sys/crypto/fips_enabled`
print_result
#[[ "$result" = "disabled." ]] && pass || fail
[[ $result -eq 0 ]] && pass || fail

########################################################
Check SELinux is disabled
########################################################
result=`sestatus|egrep "^SELinux status"|awk '{print $3}'`
print_result
if [ $result = disabled ]
   then pass
   else fail
        sestatus | tee -a $logfile
fi

########################################################
Check local firewall state
########################################################
result=`firewall-cmd --state`
rc=$?
# [[ $rc -eq 0 ]] && print_result;pass || result=$rc;print_result;checked

if [ $rc -eq 0 ]
   then print_result
        pass
        ########################################################
        Check port 3050 TCP open for inbound traffic
        ########################################################
        result=`firewall-cmd --list-all | egrep 'ports:'|egrep '3050'`
        rc=$?
        print_result
        [[ $rc -eq 0 ]] && pass || fail

        ########################################################
        Check port 3030 TCP open for inbound traffic
        ########################################################
        result=`firewall-cmd --list-all | egrep 'ports:'|egrep '3030'`
        rc=$?
        print_result
        [[ $rc -eq 0 ]] && pass || fail
   else result=$rc
        print_result
        checked
fi


########################################################
Check /etc/environment file exists?
########################################################
if [ -f /etc/environment ]
   then result="Yes";print_result;checked
        ########################################################
        Check are you using a proxy?
        ########################################################
        result=`cat /etc/environment | egrep -i proxy|wc -l`
        [[ $result -gt 0 ]] && result="Yes" || result="No"
        print_result;checked
   else result="No";print_result;checked
fi

########################################################
Check nslookup executable:
########################################################
nslookup=1
result=`whereis nslookup | awk '{print $2}'`
print_result
#[[ $result = /usr/bin/nslookup ]] && pass || nslookup=0;fail
if [ "$result" = "/usr/bin/nslookup" ]
   then pass
   else nslookup=0
        fail
fi
check_software bind-utils

########################################################
#Run nslookup commands if nslookup is available
########################################################
if [ $nslookup -ne 0 ]
then
        ########################################################
        Check DNS lookup to update.nai.com:
        ########################################################
        nslookup update.nai.com | tee -a $logfile
        rc=$?
        print_result
        [[ $rc -eq 0 ]] && pass || fail

        ########################################################
        Check DNS lookup to S3.amazonaws:
        ########################################################
        nslookup s3.amazonaws.com | tee -a $logfile
        rc=$?
        print_result
        [[ $rc -eq 0 ]] && pass || fail

        ########################################################
        Check DNS lookup to Helpsystems:
        ########################################################
        nslookup download.helpsystems.com | tee -a $logfile
        rc=$?
        print_result
        [[ $rc -eq 0 ]] && pass || fail

        ########################################################
        Check DNS lookup to Helpsystems:
        ########################################################
        nslookup helpsystems.com | tee -a $logfile
        rc=$?
        print_result
        [[ $rc -eq 0 ]] && pass || fail
   else message nslookup checks bypassed.
fi

########################################################
Check nmap executable:
#######################################################
result=`whereis nmap | awk '{print $2}'`
print_result
[[ $result = /usr/bin/nmap ]] && pass || fail
check_software nmap

########################################################
Check openssl executable:
########################################################
result=`whereis openssl | awk '{print $2}'`
print_result
[[ $result = /usr/bin/openssl ]] && pass || fail
check_software openssl

########################################################
Check tar executable:
########################################################
result=`whereis tar | awk '{print $2}'`
print_result
[[ $result = /usr/bin/tar ]] && pass || fail
check_software tar

########################################################
Check wget executable:
########################################################
result=`whereis wget | awk '{print $2}'`
print_result
[[ $result = /usr/bin/wget ]] && pass || fail
check_software wget

########################################################
# Check urw fonts installed
########################################################
[[ $os_type = "centos" ]] && check_software urw-fonts

########################################################
Check Java executable:
########################################################
java=1
result=`whereis java | awk '{print $2}'`
print_result
#[[ "$result" = "/usr/bin/java" ]] && pass || java=0;fail
if [ "$result" = "/usr/bin/java" ]
   then pass
   else java=0
        fail
fi

if [ $java -ne 0 ]
   then
        ########################################################
        Check Java Version:
        ########################################################
        java -version 2>&1 | tee -a $logfile
        print_result;checked

        ########################################################
        Check What Java packages are installed:
        ########################################################
        #check_software java
        yum list installed | egrep -i ^java | tee -a $logfile
        rc=$?
        print_result
        [[ $rc -eq 0 ]] && pass || fail
   else message Java checks bypassed
fi

echo "---------------------------------------------------------------" | tee -a $logfile
echo "Checks completed" | tee -a $logfile
echo " " | tee -a $logfile
printf "%9s %2u\n" Checked: $checked_count  | tee -a $logfile
printf "%9s %2u\n" Passed: $pass_count  | tee -a $logfile
printf "%9s %2u\n" FAIL: $fail_count  | tee -a $logfile
printf "%12s \n" ==  | tee -a $logfile
printf "%9s %2u\n" Total: $check_count  | tee -a $logfile
printf "%9s %2u\n" Warning: $warn_count  | tee -a $logfile
echo " " | tee -a $logfile
echo " logfile created at: $logfile"
echo "===============================================================" | tee -a $logfile
exit

