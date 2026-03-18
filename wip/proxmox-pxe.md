export PROJECT=proxmox-giraffe-7523
export REGION=europe-west4
export NETWORK=proxmox

gcloud compute networks create $NETWORK \
    --project $PROJECT \
    --subnet-mode custom

gcloud compute networks subnets create $REGION \
    --project $PROJECT \
    --region $REGION \
    --network $NETWORK \
    --range 10.0.1.0/24 \
    --stack-type IPV4_ONLY \
    --enable-private-ip-google-access \
    --enable-flow-logs \
    --logging-aggregation-interval interval-5-sec \
    --logging-flow-sampling 0.5 \
    --logging-metadata include-all

export PROJECT=proxmox-giraffe-7523
export REGION=europe-west4
export NETWORK=proxmox

gcloud compute routers create $REGION-nat \
    --project $PROJECT \
    --region $REGION \
    --network $NETWORK

gcloud compute routers nats create $REGION \
    --project $PROJECT \
    --region $REGION \
    --router $REGION-nat \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips

export PROJECT=proxmox-giraffe-7523
export ZONE=europe-west4-a
export DISK=proxmox-installer

gcloud compute disks create $DISK \
    --project $PROJECT \
    --zone $ZONE \
    --image-project ipxe-images \
    --image-family ipxe \
    --type hyperdisk-balanced \
    --size 10 \
    --provisioned-iops 3000 \
    --provisioned-throughput 140 \

export PROJECT=proxmox-giraffe-7523
export ZONE=europe-west4-a
export INSTANCE=proxmox-installer
; export METADATA=$(cat << EOT
; #!ipxe
; set base http://tinycorelinux.net/16.x/x86/release/distribution_files
; kernel \${base}/vmlinuz64 initrd=rootfs.gz initrd=modules64.gz
; initrd \${base}/rootfs.gz
; initrd \${base}/modules64.gz
; boot
; EOT
; )

export BUCKET=cbp-proxmox
export SERVICE_ACCOUNT=$(gcloud projects describe $PROJECT --format "value(projectNumber)")-compute@developer.gserviceaccount.com

export URL_LINUX=$(gcloud storage sign-url gs://$BUCKET/pxe/linux26 \
    --region $REGION \
    --duration 10m \
    --format "value(signed_url)")

export URL_INITRD=$(gcloud storage sign-url gs://$BUCKET/pxe/initrd.img \
    --region $REGION \
    --duration 10m \
    --format "value(signed_url)")

export METADATA=$(cat << EOT
#!ipxe
initrd $URL_INITRD
kernel $URL_LINUX initrd=initrd.img roxmox-start-auto-installer
boot Ü
EOT
)

export METADATA=$(cat << EOT
#!ipxe
kernel $URL_LINUX proxmox-start-auto-installer
boot
EOT
)

gcloud compute instances create $INSTANCE-dummy \
    --project $PROJECT \
    --zone $ZONE \
    --machine-type c4-standard-8 \
    --network-interface=nic-type=gvnic,stack-type=IPV4_ONLY,network=$NETWORK,subnet=$REGION,no-address \
    --tags=iap-ssh,iap-pve \
    --disk boot=yes,name=dummy,device-name=proxmox-installer \
    --create-disk type=hyperdisk-balanced,provisioned-iops=3000,provisioned-throughput=140,size=10,name=proxmox,device-name=proxmox \
    --no-restart-on-failure \
    --maintenance-policy=TERMINATE \
    --provisioning-model=SPOT \
    --instance-termination-action=STOP \
    --scopes https://www.googleapis.com/auth/cloud-platform

; --disk boot=yes,name=$INSTANCE,device-name=$INSTANCE \

gcloud compute instances create $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --machine-type c4-standard-8 \
    --network-interface=nic-type=gvnic,stack-type=IPV4_ONLY,network=$NETWORK,subnet=$REGION,no-address \
    --tags=iap-ssh,iap-pve \
    --create-disk boot=yes,name=$INSTANCE,device-name=$INSTANCE,image-project=cbpetersen-shared,image-family=ipxe-uefi-x86-64,type=hyperdisk-balanced,size=10,provisioned-iops=3000,provisioned-throughput=140 \
    --create-disk name=proxmox,device-name=proxmox,type=hyperdisk-balanced,size=10,provisioned-iops=3000,provisioned-throughput=140 \
    --no-restart-on-failure \
    --maintenance-policy=TERMINATE \
    --provisioning-model=SPOT \
    --instance-termination-action=STOP \
    --scopes https://www.googleapis.com/auth/cloud-platform \
    --metadata serial-port-enable=true,ipxeboot="$METADATA"
    ; --shielded-secure-boot \
    ; --shielded-vtpm \
    ; --shielded-integrity-monitoring

gcloud compute instances add-metadata $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --metadata serial-port-enable=true,ipxeboot="$METADATA"

gcloud compute instances start $INSTANCE \
    --project $PROJECT \
    --zone $ZONE

gcloud compute instances stop $INSTANCE \
    --project $PROJECT \
    --zone $ZONE

gcloud compute instances reset $INSTANCE \
    --project $PROJECT \
    --zone $ZONE

gcloud compute instances delete $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --quiet