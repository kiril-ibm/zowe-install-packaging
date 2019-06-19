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

#
# Your JCL must invoke it like this:
#
# //        EXEC PGM=BPXBATSL,REGION=0M,TIME=NOLIMIT,
# //  PARM='PGM /bin/sh &SRVRPATH/scripts/internal/run-zowe.sh'
#
#

# New Cupids work - once we have PARMLIB/properties files removed properly this won't be needed anymore
ROOT_DIR={{root_dir}} # the install directory of zowe
USER_DIR=~/zowe-user-dir # the workspace location for this instance. TODO Should we add this as a new to the yaml, or default it?
FILES_API_PORT={{files_api_port}} # the port the files api service will use
JOBS_API_PORT={{jobs_api_port}} # the port the files api service will use
STC_NAME={{stc_name}}

# details to be read from higher level entry that instance PARMLIB/prop file?
KEY_ALIAS={{key_alias}}
KEYSTORE={{keystore}}
KEYSTORE_PASSWORD={{keystore_password}}
ZOSMF_PORT={{zosmf_port}}
ZOSMF_IP_ADDRESS={{zosmf_ip_address}}
JAVA_HOME={{java_home}}

STARTED_COMPONENTS=files-api,jobs-api #TODO this is WIP - component ids not finalised at the moment

if [[ ! -f $NODE_HOME/"./bin/node" ]]
then
export NODE_HOME={{node_home}}
fi
cd `dirname $0`/../../zlux-app-server/bin && ./nodeCluster.sh --allowInvalidTLSProxy=true &
`dirname $0`/../../api-mediation/scripts/api-mediation-start-discovery.sh
`dirname $0`/../../api-mediation/scripts/api-mediation-start-catalog.sh
`dirname $0`/../../api-mediation/scripts/api-mediation-start-gateway.sh
`dirname $0`/../../jes_explorer/scripts/start-explorer-jes-ui-server.sh
`dirname $0`/../../mvs_explorer/scripts/start-explorer-mvs-ui-server.sh
`dirname $0`/../../uss_explorer/scripts/start-explorer-uss-ui-server.sh
 
# TODO zip #445 For each - Validate component properties

mkdir -p ${USER_DIR}

#Backup previous directory if it exists
if [[ -f ${USER_DIR}"/active_configuration.cfg" ]]
then
PREVIOUS_DATE=$(cat ${USER_DIR}/active_configuration.cfg | grep CREATION_DATE | cut -d'=' -f2)
mv ${USER_DIR}/active_configuration.cfg ${USER_DIR}/backup_configuration.${PREVIOUS_DATE}.cfg
# Backup previous
fi

NOW=$(date +"%y.%m.%d.%H.%M.%S")
#TODO - inject VERSION variable at build time?
# Create a new active_configuration.cfg properties file with all the parsed parmlib properties stored in it,
cat <<EOF >${USER_DIR}/active_configuration.cfg
VERSION=1.4
CREATION_DATE=${NOW}
ROOT_DIR=${ROOT_DIR}
USER_DIR=${USER_DIR}
FILES_API_PORT=${FILES_API_PORT}
JOBS_API_PORT=${JOBS_API_PORT}
STC_NAME=${STC_NAME}
KEY_ALIAS=${KEY_ALIAS}
KEYSTORE=${KEYSTORE}
KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}
ZOSMF_PORT=${ZOSMF_PORT}
ZOSMF_IP_ADDRESS=${ZOSMF_IP_ADDRESS}
JAVA_HOME=${JAVA_HOME}
STARTED_COMPONENTS=f${STARTED_COMPONENTS}
EOF

# Copy manifest into user_dir so we know the version for support enquiries/migration
cp ${ROOT_DIR}/manifest.json ${USER_DIR}

for i in $(echo $STARTED_COMPONENTS | sed "s/,/ /g")
do
  . ${ROOT_DIR}/components/${i}/bin/start.sh
done