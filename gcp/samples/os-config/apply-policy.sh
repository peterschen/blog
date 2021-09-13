#!/usr/bin/env sh

## Script to apply the os-config policy
## Idea and 98.9% of the work by Alex Moore

set +e

usage() { echo "Usage: $0 -z <compute zone> -n <policy name> -p <policy file>" 1>&2; exit 1; }

while getopts ":z:n:p:" opt; do
    case "${opt}" in
        z)
            ZONE=${OPTARG}
            ;;
        n)
            NAME=${OPTARG}
            ;;
        p)
            POLICY=${OPTARG}
            ;;
        :)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

if [ ! "${ZONE}" ] || [ ! "${NAME}" ] || [ ! "${POLICY}" ]; then
  echo "arguments -z, -n and -p must be provided"
  usage
fi

# Check whether the policy already exists
# and create or update accordingly
MODE="create"
gcloud alpha compute os-config os-policy-assignments describe ${NAME} \
   --location=${ZONE} &> /dev/null

if [ $? -eq 0 ]; then
    MODE="update"
fi

# Apply the policy
gcloud alpha compute os-config os-policy-assignments ${MODE} ${NAME} \
    --location=${ZONE} \
    --file=${POLICY} \
    --async
