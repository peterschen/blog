#!/usr/bin/env bash

set -u

EXIT_SCRIPTERROR=1
EXIT_IAPERROR=2
MAX_RETRIES=5

POSITIONAL_ARGS=()

INSTANCE_NAME=
INSTANCE_PORT=
CHAIN_COMMAND=
ZONE=

# Default to what Cloud Shell provides
PROJECT=$GOOGLE_CLOUD_PROJECT

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--project)
      PROJECT="$2"
      shift
      shift
      ;;
    -z|--zone)
      ZONE="$2"
      shift
      shift
      ;;
    --)
      shift;
      break
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit $EXIT_SCRIPTERROR
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

printHelp()
{
  echo "Usage: $0 INSTANCE_NAME INSTANCE_PORT [-p|--project PROJECT] [-z|--zone ZONE] -- CHAIN_COMMAND"
  echo ""
  echo "Parameters can also be set using environmental variables:"
  echo "  INSTANCE_NAME"
  echo "  INSTANCE_PORT"
  echo "  PROJECT"
  echo "  ZONE"
  echo "  CHAIN_COMMAND"
  echo ""
  echo "In the CHAIN_COMMAND use %SERVER% to specificy the target server which will be automatically"
  echo "replaced with the correct hostname and port when the IAP tunnel has been established"
}

runIap()
{
  instanceName=$1
  instancePort=$2
  project=$3
  zone=$4
  tout=$5
  tpid=$6

  gcloud compute start-iap-tunnel $instanceName $instancePort --project=$project --zone=$zone &> $tout &
  echo $! > $tpid
}

runChainCommand()
{
  port=$2
  command=$(echo "$1" | sed "s/%SERVER%/localhost:$port/")

  echo "Executing '$command'"
  echo ""

  $command
}

# Check if we have enough positional arguments
if [ ${#POSITIONAL_ARGS[@]} -ne 2 ]; then
  printHelp
  exit $EXIT_SCRIPTERROR
fi

# Assign positional parameters
INSTANCE_NAME="${POSITIONAL_ARGS[0]}"
INSTANCE_PORT="${POSITIONAL_ARGS[1]}"
CHAIN_COMMAND="$@"

if [[ -z "$INSTANCE_NAME" || -z "$INSTANCE_PORT"  || -z "$CHAIN_COMMAND" ]]; then
  printHelp
  exit $EXIT_SCRIPTERROR
fi

echo "PROJECT       = ${PROJECT}"
echo "ZONE          = ${ZONE}"
echo "INSTANCE_NAME = ${INSTANCE_NAME}"
echo "INSTANCE_PORT = ${INSTANCE_PORT}"
echo "CHAIN_COMMAND = ${CHAIN_COMMAND}"

trap 'kill $(cat $tpid); rm -f $tout $tpid' EXIT
tout=$(mktemp)
tpid=$(mktemp)

# Start IAP
runIap "$INSTANCE_NAME" "$INSTANCE_PORT" "$PROJECT" "$ZONE" $tout $tpid
echo "IAP_PID       = $(cat $tpid)"

retries=0
localPort=""
error=

while [ $retries -lt $MAX_RETRIES ]; do
  # Wait for output to be available
  sleep 1

  if [ -s $tout ]; then
    # Extract local port from output
    if [ "$localPort" = "" ]; then
      localPort=$(grep -o '\[[0-9]\+\]' $tout | sed "s/\[//" | sed "s/\]//")
    fi

    # Check if an error has been logged
    hasError=$(grep -o 'ERROR' $tout)
    if [ "$hasError" = "ERROR" ]; then
      error=$(cat $tout)
      break;
    fi
  fi

  retries=$((retries+1))
done

if [[ ! -z "$localPort" && -z "$error" ]]; then
  echo "LOCAL_PORT    = $localPort"
  echo ""

  runChainCommand "$CHAIN_COMMAND" $localPort
else
  echo "$error";
  exit $EXIT_IAPERROR;
fi
