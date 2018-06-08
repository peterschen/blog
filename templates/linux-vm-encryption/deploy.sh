#!/usr/bin/env sh
set -e

APPS="az ssh"

usage() {
    echo "Helper to deploy the sample."
    echo "This script requires the following programs to be present: az, ssh"
    echo ""
    echo "$0"
    echo "\t-h --help"
    echo "\t-g --resourceGroup=$RESOURCEGROUP"
    echo "\t-e --environmentName=$ENVIRONMENTNAME"
	echo "\t-u --adminUsername=$ADMINUSERNAME"
	echo "\t-k --adminSshKey=$ADMINSSHKEY"
    echo "\t-t --tenantId=$TENANTID"
	echo "\t-i --servicePrincipalId=$SERVICEPRINCIPALID"
	echo "\t-s --servicePrincipalSecret=$SERVICEPRINCIPALSECRET"
    echo ""
}

checkPrereq() {
    for app in ${APPS}; do
        set +e
        path=$(which $app)
        set -e

        if [ -z $path ]; then
            echo "Could not find: $app"
            echo ""
            usage
            exit
        fi
    done
}

deployInfrastructure() {
    local deploymentName=$1
    local resourceGroup=$2
    local environmentName=$3
    local adminUsername=$4
    local adminSshKey=$5
    local tenantId=$6
    local servicePrincipalId=$7
    local servicePrincipalSecret=$8

    local servicePrincipalObjectId=$(az ad sp show --id $servicePrincipalId --query objectId -o tsv)

    parameters=$(cat << EOM
{
    "EnvironmentName": {
        "value": "${environmentName}"
    },
    "AdminUsername": {
        "value": "${adminUsername}"
    },
    "AdminSshKey": {
        "value": "ssh-rsa ${adminSshKey}"
    },
    "TenantId": {
        "value": "${tenantId}"
    },
    "ServicePrincipalObjectId": {
        "value": "${servicePrincipalObjectId}"
    },
    "ServicePrincipalClientId": {
        "value": "${servicePrincipalId}"
    },
    "ServicePrincipalClientSecret": {
        "value": "${servicePrincipalSecret}"
    }
}
EOM
)

    az group create \
        --name $resourceGroup \
        --location westeurope 1> /dev/null

	echo "Deploying infrastructure"
    az group deployment create \
        --resource-group $resourceGroup \
        --name $deploymentName \
        --template-file azuredeploy.json \
        --parameters "$parameters" 1> /dev/null
}

checkPrereq

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | sed 's/^[^=]*=//g'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        -g | --resourceGroup)
            RESOURCEGROUP=$VALUE
            ;;
        -e | --environmentName)
            ENVIRONMENTNAME=$VALUE
            ;;
		-u | --adminUsername)
            ADMINUSERNAME=$VALUE
            ;;
		-k | --adminSshKey)
            ADMINSSHKEY=$VALUE
            ;;
		-t | --tenantId)
            TENANTID=$VALUE
            ;;
        -i | --servicePrincipalId)
            SERVICEPRINCIPALID=$VALUE
            ;;
		-s | --servicePrincipalSecret)
            SERVICEPRINCIPALSECRET=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

if [ "$RESOURCEGROUP" = "" ] || [ "$ENVIRONMENTNAME" = "" ] || [ "$ADMINUSERNAME" = "" ]; then
	echo "ERROR: missing parameters"
	usage
	exit 1
fi

if [ "$TENANTID" = "" ] || [ "$SERVICEPRINCIPALID" = "" ] || [ "$SERVICEPRINCIPALSECRET" = "" ]; then
	echo "ERROR: missing parameters"
	usage
	exit 1
fi

if [ "$ADMINSSHKEY" = "" ]; then
    ADMINSSHKEY=$(cat ~/.ssh/id_rsa.pub | cut -d' ' -f 2)
fi

deploymentName=`date +'%Y%m%d-%H%M%S'`

deployInfrastructure \
    $deploymentName \
    $RESOURCEGROUP \
    $ENVIRONMENTNAME \
    $ADMINUSERNAME \
    $ADMINSSHKEY \
    $TENANTID \
    $SERVICEPRINCIPALID \
    $SERVICEPRINCIPALSECRET
    