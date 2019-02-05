#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################


#TODO - Get the host name working correctly
#TODO - Get the script to try and locate the 64 bit Java 8

# The environment variables
# ZOWE_ZOSMF_PATH    points to the /lib directory of the zOSMF install
# ZOWE_ZOSMF_PORT https port of the zOSMF server
# ZOWE_JAVA_HOME points to Java to be used
# ZOWE_SDSF_PATH points to SDSF location
# ZOWE_EXPLORER_HOST points to the current host name
# NODE_HOME points to the node directory

# This script checks to see whether they are set, and if not tries to locate them, 
# and if they can't be found prompt for them before setting them

echo "<zowe-init.sh>" >> $LOG_FILE


#set-x
export ZOWE_ZOSMF_PATH
export ZOWE_ZOSMF_PORT
export ZOWE_JAVA_HOME
export ZOWE_EXPLORER_HOST
export NODE_HOME

# Purpose: Set Zowe vars, if present in .profile.  We may have changed .profile since we last logged in.  
# Action: Find the lines in .profile that set Zowe env vars, put them in a separate .zowe_profile file, and ‘source’ that instead.
# The .zowe_profile file persists across installs.  If it exists, your .profile will not be scanned for Zowe variables.  
# If you delete it, it will be recreated here from .profile.  

# 1. find existing environment variable settings in .profile
if [[ ! -e ~/.zowe_profile && -e ~/$PROFILE ]]
then
    grep \
    -e ZOWE_ZOSMF_PATH= \
    -e ZOWE_ZOSMF_PORT= \
    -e ZOWE_JAVA_HOME= \
    -e ZOWE_EXPLORER_HOST= \
    -e NODE_HOME= ~/$PROFILE > ~/.zowe_profile
fi
touch ~/.zowe_profile     # ensure it exists
# 2. set those variables (if any) in Zowe install environment
. ~/.zowe_profile 

locateZOSMFBootstrapProperties() {
# $1$2$3$4 together are the full path to an expected bootstrap.properties file used to create a symlink
    if [[ -f $1$2$3$4 ]] 
    then
        echo "  Liberty "$4" found  at "$1$2$3
        ZOWE_ZOSMF_PATH=$1$2$3
        persist "ZOWE_ZOSMF_PATH" $1$2$3
    else 
# on some machines the user may not have permission to look into $3, in which case if $1$2 exists set the variable
# as the symlink permission will be allowed by the IZUUSR user ID that starts the explorer-server
        echo "  Unable to determine whether "$1$2$3$4 "exists"
        echo "  This may be because the current user is not authorized to look into "$1$2
        echo "  The runtime user for the liberty-server needs to have sufficient authority"
        ZOWE_ZOSMF_PATH=$1$2$3
        persist "ZOWE_ZOSMF_PATH" $1$2$3
    fi
}

getZosmfHttpsPort() {
    ZOWE_ZOSMF_PORT=`netstat -b -E IZUSVR1 2>/dev/null|grep .*Listen | awk '{ print $4 }'`
    if [[ "$ZOWE_ZOSMF_PORT" == "" ]]
    then
        echo "    Unable to detect z/OS MF HTTPS port"
        echo "    Please enter the HTTPS port of z/OS MF server on this system"
        read ZOWE_ZOSMF_PORT
    fi
    persist "ZOWE_ZOSMF_PORT" $ZOWE_ZOSMF_PORT
}

promptNodeHome(){
loop=1
while [ $loop -eq 1 ]
do
    if [[ "$NODE_HOME" == "" ]]
    then
        echo "    NODE_HOME was not set "
        echo "    Please enter a path to where node is installed.  This is the a directory that contains /bin/node "
        read NODE_HOME
    fi
    if [[ -f $NODE_HOME/"./bin/node" ]] 
    then
        if [ NODE_HOME_ALREADY_SET = "false" ]
    	then
        	persist "NODE_HOME" $NODE_HOME
        fi
        loop=0
    else
        echo "        No /bin/node found in directory "$NODE_HOME
        echo "        Press Y or y to accept location, or Enter to choose another location"
        read rep
        if [ "$rep" = "Y" ] || [ "$rep" = "y" ]
        then
            persist "NODE_HOME" $NODE_HOME
            loop=0
        else
            NODE_HOME=
        fi
    fi
done
}

javaVersion=-1
locateJavaHome() {
    getJavaVersion $1
    if [ "$javaVersion" -ge "18" ]
        then
            echo "   java version $version found at " $1
            if [ $JAVA_HOME_ALREADY_SET = "false" ]
            then
            	persist "ZOWE_JAVA_HOME" $1
            fi
        else
            if [ "$javaVersion" = "-1" ]
            then
                echo "    No executable file found in $1/bin/java"
            else
                echo "    The version of java at $1 is $version, and must be Java 8, or newer"
            fi
            loop=1
            while [ $loop -eq 1 ]
            do
                echo "    Please enter home directory where Java 8, or newer is installed.  This is the a directory that contains /bin/java"
                read ZOWE_JAVA_HOME
                getJavaVersion $ZOWE_JAVA_HOME
                if [ "$javaVersion" = "-1" ]
                    then
                        echo "        No executable file found in $ZOWE_JAVA_HOME/bin/java"
                        echo "        Press Y or y to accept location, or Enter to choose another location"
                        read rep
                        if [ "$rep" = "Y" ] || [ "$rep" = "y" ]
                            then
                                persist "ZOWE_JAVA_HOME" $ZOWE_JAVA_HOME
                                loop=0
                        fi
                    else
                        if [ "$javaVersion" -lt "18" ]
                            then
                                echo "        The version of java at $ZOWE_JAVA_HOME is $version, and must be Java 8, or newer"
                                echo "        Press Y or y to accept location, or Enter to choose another location"
                                read rep
                                if [ "$rep" = "Y" ] || [ "$rep" = "y" ]
                                    then
                                        persist "ZOWE_JAVA_HOME" $ZOWE_JAVA_HOME
                                        loop=0
                                fi
                            else
                                persist "ZOWE_JAVA_HOME" $ZOWE_JAVA_HOME
                                loop=0
                        fi
                fi
            done
    fi
}

getJavaVersion() {
    java_bin="$1/bin/java"
    if [[ -x $java_bin ]]; then
        version=$("$java_bin" -version 2>&1 | sed -n ';s/.* version "\(.*\)\.\(.*\)\..*"/\1\2/p;')
        javaVersion=$version
    else
        javaVersion=-1
    fi
}

persist() {
#   Append a command to export a Zowe environment variable to the .zowe_profile file.  
#   The .zowe_profile file will be run on subsequent installs, to avoid having to re-discover the Zowe environment variables.  

    echo "** Adding line: export "$1"="$2" to "~/.zowe_profile " **"
    echo "** Adding line: export "$1"="$2" to "~/.zowe_profile " **" >> $LOG_FILE
    grep -v "export $1=" ~/.zowe_profile > ~/.zowe_profile.zowe-tmp && mv ~/.zowe_profile.zowe-tmp ~/.zowe_profile
    echo "export $1="$2 >> ~/.zowe_profile
}

# Run the main shell script logic
echo "Locating Environment Variables..."
if [[ $ZOWE_ZOSMF_PATH == "" ]]
then
    locateZOSMFBootstrapProperties "/var/zosmf/" "configuration" "/servers/zosmfServer/" "bootstrap.properties"
else 
    echo "ZOWE_ZOSMF_PATH value of "$ZOWE_ZOSMF_PATH" will be used"
    echo "  ZOWE_ZOSMF_PATH variable value="$ZOWE_ZOSMF_PATH >> $LOG_FILE
fi

if [[ $ZOWE_ZOSMF_PORT == "" ]]
then
    getZosmfHttpsPort
else 
    echo "ZOWE_ZOSMF_PORT value of "$ZOWE_ZOSMF_PORT" will be used"
    echo "  ZOWE_ZOSMF_PORT variable value="$ZOWE_ZOSMF_PORT >> $LOG_FILE
fi

JAVA_HOME_ALREADY_SET="false"
if [[ $ZOWE_JAVA_HOME == "" ]]
then    
    ZOWE_JAVA_HOME=/usr/lpp/java/J8.0_64
else    
    JAVA_HOME_ALREADY_SET="true"
    echo "  ZOWE_JAVA_HOME value of "$ZOWE_JAVA_HOME" will be validated"
    echo "  ZOWE_JAVA_HOME variable value="$ZOWE_JAVA_HOME >> $LOG_FILE
fi
locateJavaHome $ZOWE_JAVA_HOME

NODE_HOME_ALREADY_SET="false"
if [[ $NODE_HOME != "" ]]
then
    NODE_HOME_ALREADY_SET="true"
    echo "  NODE_HOME value of "$NODE_HOME" will be validated"
    echo "  NODE_HOME environment variable was set="$NODE_HOME >> $LOG_FILE
fi
promptNodeHome

if [[ $ZOWE_EXPLORER_HOST == "" ]]
then
    ZOWE_EXPLORER_HOST=$(hostname -c)
    persist "ZOWE_EXPLORER_HOST" $ZOWE_EXPLORER_HOST
else    
    echo "ZOWE_EXPLORER_HOST value of "$ZOWE_EXPLORER_HOST" will be used"
    echo "  ZOWE_EXPLORER_HOST variable value="$ZOWE_EXPLORER_HOST >> $LOG_FILE
fi

if [[ $ZOWE_IPADDRESS == "" ]]
then
    # host may return aliases, which may result in ZOWE_IPADDRESS has value of "10.1.1.2 EZZ8322I aliases: S0W1"
    # EZZ8321I S0W1.DAL-EBIS.IHOST.COM has addresses 10.1.1.2
    # EZZ8322I aliases: S0W1
    ZOWE_IPADDRESS=$(host ${ZOWE_EXPLORER_HOST} | grep 'has addresses' | sed 's/.*addresses\ //g')
    persist "ZOWE_IPADDRESS" $ZOWE_IPADDRESS
else
    echo "ZOWE_IPADDRESS value of "$ZOWE_IPADDRESS" will be used"
    echo "  ZOWE_IPADDRESS variable value="$ZOWE_IPADDRESS >> $LOG_FILE
fi
echo "</zowe-init.sh>" >> $LOG_FILE
