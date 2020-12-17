#!/usr/bin/env sh

set -e

getInstanceMetadata()
{
    KEY=$1
    echo $(curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/$KEY")
}

getVmName()
{
    echo $(getInstanceMetadata name)
}

getZone()
{
    zone=$(getInstanceMetadata zone)
    echo $zone | sed 's/.*\(zones\/\)\(europe-west4-a\).*/\2/'
}

getPatchJobId()
{
    VM=$1
    ZONE=$2

    # Get running patch jobs
    jobs=`gcloud compute os-config patch-jobs list --filter="state:patching" --format="value(ID)"`

    # Iterating all jobs
    for job in $jobs; do
        # Check if this instance is targetted by the patch job
        # and the job is in the RUNNING_PRE_PATCH_STEP
        filter="name:$VM AND zone:$ZONE AND state:RUNNING_PRE_PATCH_STEP"
        instance=`gcloud compute os-config patch-jobs list-instance-details $job --filter="$filter" --format="value(NAME)"`
        if [ "$instance" = "$VM" ]; then
            echo $job
            return;
        fi
    done

    echo -1
}

getDisks()
{
    VM=$1
    ZONE=$2

    echo $(gcloud compute instances describe $VM --zone $ZONE --format="value[delimiter=\n](disks[].source)")
}

newSnapshot()
{
    DISKS=$1
    VM=$2
    JOBID=$3

    gcloud compute disks snapshot --labels patchjob=$JOBID,vm=$VM --user-output-enabled false $DISKS
    echo $?
}

vmName=$(getVmName);
zone=$(getZone);

echo -n "Determining patch job: "
jobId=$(getPatchJobId $vmName $zone)
echo $jobId;

echo -n "Retrieving disks associated with VM: "
disks=$(getDisks $vmName $zone)
echo "$(echo "$disks" | wc -w) disk(s) found"

echo -n "Creating snapshot(s): ";
result=$(newSnapshot $disks $vmName $jobId)

if [ $result -eq 0 ]; then
    echo "done"
else
    echo "failed"
    exit 1
fi
