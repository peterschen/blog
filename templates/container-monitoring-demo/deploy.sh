#!/usr/bin/env sh
set -e

usage() {
    echo "Helper to deploy the environment."
    echo ""
    echo "$0"
    echo "\t-h --help"
    echo "\t-g --resourceGroup=$RESOURCEGROUP"
    echo "\t-e --environmentName=$ENVIRONMENTNAME"
	echo "\t-u --adminUsername=$ADMINUSERNAME"
	echo "\t-k --adminSshKey=$ADMINSSHKEY"
	echo "\t-i --servicePrincipalId=$SERVICEPRINCIPALID"
	echo "\t-s --servicePrincipalSecret=$SERVICEPRINCIPALSECRET"
    echo ""
}

deployInfrastructure() {
    local deploymentName=$1
    local resourceGroup=$2
    local environmentName=$3
    local adminUsername=$4
    local adminSshKey=$5
    local servicePrincipalId=$6
    local servicePrincipalSecret=$7

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
    "ServicePrincipalClientId": {
        "value": "${servicePrincipalId}"
    },
    "ServicePrincipalClientSecret": {
        "value": "${servicePrincipalSecret}"
    }
}
EOM
)

    echo "Creating resource group"
    az group create \
        --name $resourceGroup \
        --location westeurope 1> /dev/null

	echo "Running resource group deployment"
    az group deployment create \
        --resource-group $resourceGroup \
        --name $deploymentName \
        --template-file azuredeploy.json \
        --parameters "$parameters" 1> /dev/null
}

getSsh()
{
    local resourceGroup=$1
    local name="$2"

    export FQDNACS=$(az acs show -g $resourceGroup -n $name --query masterProfile.fqdn -o tsv)
    export SSH="ssh -A labadmin@${FQDNACS} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
}

deployMonitoringAcs() {
    local resourceGroup=$1
    local name="$2"
    local nameAcs="$name-acs"
    
    getSsh $resourceGroup $nameAcs
    
    serviceId=$($SSH docker service ls --filter "name=omsagent" -q)

    if [ "$serviceId" = "" ]; then
        resourceId=$(az resource list -g $resourceGroup -n $name --resource-type "Microsoft.OperationalInsights/workspaces" --query [].id -o tsv)
        workspaceId=$(az resource show --ids $resourceId --query properties.customerId -o tsv)
        workspaceKey=$(az resource invoke-action --action sharedKeys --ids $resourceId | sed 's/\\r\\n//g' | sed 's/\\\"/"/g' | sed 's/"{/{/' | sed 's/}"/}/' | jq -r .primarySharedKey)

        echo "Creating secrets"
        $SSH "echo $workspaceId | docker secret create workspaceId -"
        $SSH "echo $workspaceKey | docker secret create workspaceKey -"

        echo "Creating OMS agent service"
        $SSH \
            "docker service create \
                --name omsagent \
                --mode global \
                --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
                --secret source=workspaceId,target=WSID \
                --secret source=workspaceKey,target=KEY \
                -p 25225:25225 \
                -p 25224:25224/udp \
                --restart-condition=on-failure \
                microsoft/oms"
    else
        echo "OMS agent service is already created"
    fi
}

deployApplicationAcs() {
    resourceGroup=$1
    name="$2-acs"

    getSsh $resourceGroup $name

    echo "Deploying Minecraft stack"
    scp minecraft-swarm.yaml labadmin@$FQDNACS:/tmp/minecraft.yaml
    $SSH "docker stack deploy -c /tmp/minecraft.yaml minecraft"
}

deployApplicationAks() {
    resourceGroup=$1
    name="$2-aks"

	echo "Configuring Kubernetes credentials for CLI use"
	az aks get-credentials \
		--resource-group $resourceGroup \
		--name $name

	echo "Deploy application to AKS"
	kubectl apply -f minecraft.yaml
}

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

if [ "$SERVICEPRINCIPALID" = "" ] || [ "$SERVICEPRINCIPALSECRET" = "" ]; then
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
    $SERVICEPRINCIPALID \
    $SERVICEPRINCIPALSECRET

deployMonitoringAcs \
	$RESOURCEGROUP \
	$ENVIRONMENTNAME

deployApplicationAcs \
	$RESOURCEGROUP \
	$ENVIRONMENTNAME

# deployApplicationAks \
#	$RESOURCEGROUP \
#	$ENVIRONMENTNAME