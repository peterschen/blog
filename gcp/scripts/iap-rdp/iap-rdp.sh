#!/usr/bin/env bash

set -u

EXIT_SCRIPTERROR=1
EXIT_IAPERROR=2
MAX_RETRIES=5

POSITIONAL_ARGS=()

INSTANCE_NAME=
INSTANCE_PORT=
RDP_COMMAND=
ZONE=

while [[ $# -gt 0 ]]; do
  case $1 in
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
  echo "Usage: $0 INSTANCE_NAME [INSTANCE_PORT;default=3389] [--zone ZONE] -- RDP_COMMAND"
  echo ""
  echo "Parameters can also be set using environmental variables:"
  echo "  INSTANCE_NAME"
  echo "  INSTANCE_PORT"
  echo "  RDP_COMMAND"
  echo "  ZONE"
  echo ""
  echo "In the RDP_COMMAND use %SERVER% to specificy the target server which will be automatically"
  echo "replaced with the correct hostname and port when the IAP tunnel has been established"
}

runIap()
{
  instanceName=$1
  instancePort=$2
  zone=$3
  tout=$4

  gcloud compute start-iap-tunnel $instanceName $instancePort --zone=$zone &> $tout
}

runRdp()
{
  port=$2
  command=$(echo "$1" | sed "s/%SERVER%/localhost:$port/")

  echo "Executing '$command'"
  echo ""

  $command
}

# Assign positional parameters
INSTANCE_NAME="${POSITIONAL_ARGS[0]}"
INSTANCE_PORT="${POSITIONAL_ARGS[1]}"
RDP_COMMAND="$@"

if [[ -z $INSTANCE_PORT ]]; then
  INSTANCE_PORT=3389
fi

if [[ -z "$INSTANCE_NAME" || -z "$RDP_COMMAND" ]]; then
  printHelp
  exit $EXIT_SCRIPTERROR
fi

echo "INSTANCE_NAME = ${INSTANCE_NAME}"
echo "INSTANCE_PORT = ${INSTANCE_PORT}"
echo "RDP_COMMAND   = ${RDP_COMMAND}"
echo "ZONE          = ${ZONE}"

trap 'rm -f $tout' EXIT
tout=$(mktemp)

{ runIap "$INSTANCE_NAME" "$INSTANCE_PORT" "$ZONE" $tout; } &

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
  runRdp "$RDP_COMMAND" $localPort
else
  echo "$error";
  exit $EXIT_IAPERROR;
fi
