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

#********************************************************************
# Expected globals:
# $ZOWE_JAVA_HOME
# $ZOWE_ROOT_DIR
# $ZOWE_EXPLORER_HOST
# $ZOWE_IPADDRESS
# $ZOWE_APIM_CATALOG_PORT
# $ZOWE_APIM_DISCOVERY_PORT
# $ZOWE_APIM_GATEWAY_PORT
# $ZOWE_APIM_EXTERNAL_CERTIFICATE
# $ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS
# $ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES
# $ZOWE_APIM_VERIFY_CERTIFICATES

echo "<zowe-api-mediation-configure.sh>" >> $LOG_FILE

cd $ZOWE_ROOT_DIR"/api-mediation"

# Set a+rx for API Mediation JARs
chmod a+rx *.jar 

# Make the apiml-auth plugin readable by everyone
chmod a+rx apiml-auth
chmod a+rx apiml-auth/lib
chmod -R a+r apiml-auth

# Create the static api definitions folder
STATIC_DEF_CONFIG=$ZOWE_ROOT_DIR"/api-mediation/api-defs"
mkdir -p $STATIC_DEF_CONFIG

echo "About to set JAVA_HOME to $ZOWE_JAVA_HOME in APIML script templates" >> $LOG_FILE

cd scripts/
# Add JAVA_HOME to both script templates
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*HOSTNAME\*\*/'$ZOWE_EXPLORER_HOST'/g' \
    -e 's/\*\*IPADDRESS\*\*/'$ZOWE_IPADDRESS'/g' \
    -e 's/\*\*VERIFY_CERTIFICATES\*\*/'$ZOWE_APIM_VERIFY_CERTIFICATES'/g' \
    -e 's/\*\*ZOSMF_KEYRING\*\*/'$ZOWE_ZOSMF_KEYRING'/g' \
    -e 's/\*\*ZOSMF_USER\*\*/'$ZOWE_ZOSMF_USERID'/g' \
    -e "s|\*\*EXTERNAL_CERTIFICATE\*\*|$ZOWE_APIM_EXTERNAL_CERTIFICATE|g" \
    -e "s|\*\*EXTERNAL_CERTIFICATE_ALIAS\*\*|$ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS|g" \
    -e "s|\*\*EXTERNAL_CERTIFICATE_AUTHORITIES\*\*|$ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES|g" \
    -e "s|\*\*ZOWE_ROOT_DIR\*\*|$ZOWE_ROOT_DIR|g" \
    setup-apiml-certificates-template.sh > setup-apiml-certificates.sh

# Make configured script executable
chmod a+x setup-apiml-certificates.sh

# Inject parameters into API Mediation startup scripts, which contains command-line parameters as configuration
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*HOSTNAME\*\*/'$ZOWE_EXPLORER_HOST'/g' \
    -e 's/\*\*IPADDRESS\*\*/'$ZOWE_IPADDRESS'/g' \
    -e 's/\*\*DISCOVERY_PORT\*\*/'$ZOWE_APIM_DISCOVERY_PORT'/g' \
    -e 's/\*\*CATALOG_PORT\*\*/'$ZOWE_APIM_CATALOG_PORT'/g' \
    -e 's/\*\*GATEWAY_PORT\*\*/'$ZOWE_APIM_GATEWAY_PORT'/g' \
    -e 's/\*\*VERIFY_CERTIFICATES\*\*/'$ZOWE_APIM_VERIFY_CERTIFICATES'/g' \
    api-mediation-start-catalog-template.sh > api-mediation-start-catalog.sh

# Inject parameters into API Mediation startup, which contains command-line parameters as configuration
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*HOSTNAME\*\*/'$ZOWE_EXPLORER_HOST'/g' \
    -e 's/\*\*IPADDRESS\*\*/'$ZOWE_IPADDRESS'/g' \
    -e 's/\*\*DISCOVERY_PORT\*\*/'$ZOWE_APIM_DISCOVERY_PORT'/g' \
    -e 's/\*\*CATALOG_PORT\*\*/'$ZOWE_APIM_CATALOG_PORT'/g' \
    -e 's/\*\*GATEWAY_PORT\*\*/'$ZOWE_APIM_GATEWAY_PORT'/g' \
    -e 's/\*\*VERIFY_CERTIFICATES\*\*/'$ZOWE_APIM_VERIFY_CERTIFICATES'/g' \
    api-mediation-start-gateway-template.sh > api-mediation-start-gateway.sh

# Inject parameters into API Mediation startup, which contains command-line parameters as configuration
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*HOSTNAME\*\*/'$ZOWE_EXPLORER_HOST'/g' \
    -e 's/\*\*IPADDRESS\*\*/'$ZOWE_IPADDRESS'/g' \
    -e 's/\*\*DISCOVERY_PORT\*\*/'$ZOWE_APIM_DISCOVERY_PORT'/g' \
    -e 's/\*\*CATALOG_PORT\*\*/'$ZOWE_APIM_CATALOG_PORT'/g' \
    -e 's/\*\*GATEWAY_PORT\*\*/'$ZOWE_APIM_GATEWAY_PORT'/g' \
    -e 's|\*\*STATIC_DEF_CONFIG\*\*|'$STATIC_DEF_CONFIG'|g' \
    -e 's/\*\*VERIFY_CERTIFICATES\*\*/'$ZOWE_APIM_VERIFY_CERTIFICATES'/g' \
    api-mediation-start-discovery-template.sh > api-mediation-start-discovery.sh

# Make the scripts executable
chmod a+rx *.sh

cd ..

# Execute the APIML certificate generation - no user input required
echo "  Setting up Zowe API Mediation Layer certificates..."
./scripts/setup-apiml-certificates.sh >> $LOG_FILE
echo "  Certificate setup done."

# Get the zos version
ZOSMF_VERSION=""
ZOSMF_DOC_URL=""
# Hack - if opercmd fails default to latest OS
ZOS_RELEASE=`${ZOWE_ROOT_DIR}/scripts/internal/opercmd 'd iplinfo'|grep RELEASE` || ZOS_RELEASE="RELEASE z/OS 02.03.00"
ZOS_VRM=`echo $ZOS_RELEASE | sed 's+.*RELEASE z/OS \(........\).*+\1+'`

if [[ $ZOS_VRM == "02.03.00" ]]
then    
    ZOSMF_VERSION=2.3.0
    ZOSMF_DOC_URL="https://www.ibm.com/support/knowledgecenter/en/SSLTBW_2.3.0/com.ibm.zos.v2r3.izua700/IZUHPINFO_RESTServices.htm"
elif [[ $ZOS_VRM == "02.02.00" ]]
then    
    ZOSMF_VERSION=2.2.0
    ZOSMF_DOC_URL="https://www.ibm.com/support/knowledgecenter/en/SSLTBW_2.2.0/com.ibm.zos.v2r2.izua700/IZUHPINFO_RESTServices.htm"
fi

# Add static definition for zosmf	
cat <<EOF >$TEMP_DIR/zosmf.yml
# Static definition for z/OSMF
#
# Once configured you can access z/OSMF via the API gateway:
# http --verify=no GET https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_PORT/api/v1/zosmf/info 'X-CSRF-ZOSMF-HEADER;'
#	
services:
    - serviceId: zosmf
      title: IBM z/OSMF
      description: IBM z/OS Management Facility REST API service
      catalogUiTileId: zosmf
      instanceBaseUrls:
        - https://$ZOWE_EXPLORER_HOST:$ZOWE_ZOSMF_PORT/zosmf/
      homePageRelativeUrl:  # Home page is at the same URL
      routedServices:
        - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
          serviceRelativeUrl:
      apiInfo:
        - apiId: com.ibm.zosmf
          gatewayUrl: api/v1
          version: $ZOSMF_VERSION
          documentationUrl: $ZOSMF_DOC_URL

catalogUiTiles:
    zosmf:
        title: z/OSMF services
        description: IBM z/OS Management Facility REST services
EOF
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/zosmf.yml > $STATIC_DEF_CONFIG/zosmf.yml	

# Add static definition for MVS datasets
cat <<EOF >$TEMP_DIR/datasets.yml
#
services:
  - serviceId: datasets
    title: IBM z/OS Datasets
    description: IBM z/OS Datasets REST API service
    catalogUiTileId: datasetsAndUnixFiles
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_DATASETS_PORT/
    homePageRelativeUrl:  # Home page is at the same URL
    routedServices:
      - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
        serviceRelativeUrl: api/v1/datasets
    apiInfo:
      - apiId: org.zowe.data.sets
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_DATASETS_PORT/swagger-ui.html
  - serviceId: unixfiles
    title: IBM z/OS Unix Files
    description: IBM z/OS Unix Files REST API service
    catalogUiTileId: datasetsAndUnixFiles
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_DATASETS_PORT/
    homePageRelativeUrl:  # Home page is at the same URL
    routedServices:
      - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
        serviceRelativeUrl: api/v1/unixfiles 
    apiInfo:
      - apiId: org.zowe.unix.files
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_DATASETS_PORT/swagger-ui.html
  - serviceId: explorer-mvs
    title: IBM z/OS MVS Explorer UI
    description: IBM z/OS MVS Explorer UI service
    catalogUiTileId:
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_MVS_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-mvs
catalogUiTiles:
  datasetsAndUnixFiles:
    title: z/OS Datasets and Unix Files services
    description: IBM z/OS Datasets and Unix Files REST services
EOF
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/datasets.yml > $STATIC_DEF_CONFIG/datasets.yml	

# Add static definition for Jobs
cat <<EOF >$TEMP_DIR/jobs.yml
#
services:
  - serviceId: jobs
    title: IBM z/OS Jobs
    description: IBM z/OS Jobs REST API service
    catalogUiTileId: jobs
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_JOBS_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: api/v1
        serviceRelativeUrl: api/v1/jobs
    apiInfo:
      - apiId: com.ibm.jobs
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_JOBS_PORT/swagger-ui.html
  - serviceId: explorer-jes
    title: IBM z/OS Jobs UI
    description: IBM z/OS Jobs UI service
    catalogUiTileId:
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_JES_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-jes
catalogUiTiles:
  jobs:
    title: z/OS Jobs services
    description: IBM z/OS Jobs REST services
EOF
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/jobs.yml > $STATIC_DEF_CONFIG/jobs.yml	

# Add static definition for USS
cat <<EOF >$TEMP_DIR/uss.yml
#
services:
  - serviceId: explorer-uss
    title: IBM Unix System Services
    description: IBM z/OS Unix System services UI
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_USS_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-uss
EOF
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/uss.yml > $STATIC_DEF_CONFIG/uss.yml	

chmod -R 777 $STATIC_DEF_CONFIG

chmod 755 $ZOWE_ROOT_DIR/api-mediation/scripts

echo "</zowe-api-mediation-configure.sh>" >> $LOG_FILE
