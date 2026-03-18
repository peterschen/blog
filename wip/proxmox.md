## Create firewall rules

```shell
export PROJECT=proxmox-giraffe-7523
export NETWORK=default

gcloud compute firewall-rules create allow-ssh-iap \
    --project $PROJECT \
    --network $NETWORK \
    --priority 5000 \
    --direction INGRESS \
    --action ALLOW \
    --rules tcp:22 \
    --source-ranges 35.235.240.0/20 \
    --target-tags iap-ssh

gcloud compute firewall-rules create allow-pve-iap \
    --project $PROJECT \
    --network $NETWORK \
    --priority 5000 \
    --direction INGRESS \
    --action ALLOW \
    --rules tcp:8006 \
    --source-ranges 35.235.240.0/20 \
    --target-tags iap-pve
```

## Create temp VM

```shell
# export PROJECT=proxmox-giraffe-7523
# export ZONE=europe-west4-a
# export INSTANCE=facilitator

# gcloud compute instances create $INSTANCE \
#     --project $PROJECT \
#     --zone $ZONE \
#     --machine-type n4-highcpu-4 \
#     --network-interface=stack-type=IPV4_ONLY,subnet=default,no-address \
#     --tags=iap-ssh,iap-pve \
#     --create-disk boot=yes,type=hyperdisk-balanced,image-project=debian-cloud,image-family=debian-13,provisioned-iops=3000,provisioned-throughput=140,size=200 \
#     --create-disk device-name=proxmox,mode=rw,name=proxmox,type=hyperdisk-balanced,provisioned-iops=3000,provisioned-throughput=140,size=50 \
#     --maintenance-policy MIGRATE \
#     --shielded-secure-boot \
#     --shielded-vtpm \
#     --shielded-integrity-monitoring

export PROJECT=proxmox-giraffe-7523
export ZONE=europe-west4-a
export INSTANCE=proxmox-installer

gcloud compute instances create $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --machine-type c4-standard-8 \
    --network-interface=nic-type=gvnic,stack-type=IPV4_ONLY,subnet=default,no-address \
    --tags=iap-ssh,iap-pve \
    --create-disk boot=yes,type=hyperdisk-balanced,image-project=ipxe-images,image-family=ipxe-latest,provisioned-iops=3000,provisioned-throughput=140,size=4,name=proxmox-installer,device-name=proxmox-installer \
    --create-disk type=hyperdisk-balanced,provisioned-iops=3000,provisioned-throughput=140,size=10,name=proxmox,device-name=proxmox \
    --no-restart-on-failure \
    --maintenance-policy=TERMINATE \
    --provisioning-model=SPOT \
    --instance-termination-action=STOP \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring

gcloud compute instances create $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --machine-type c4-standard-288-metal \
    --network-interface=nic-type=IDPF,stack-type=IPV4_ONLY,subnet=default,no-address \
    --tags=iap-ssh,iap-pve \
    --create-disk boot=yes,type=hyperdisk-balanced,image-project=debian-cloud,image-family=debian-13,provisioned-iops=3000,provisioned-throughput=140,size=10,name=proxmox-installer \
    --create-disk type=hyperdisk-balanced,provisioned-iops=3000,provisioned-throughput=140,size=15,name=proxmox \
    --maintenance-policy TERMINATE \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring

gcloud compute instances create $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --machine-type c4-standard-8 \
    --network-interface=nic-type=gvnic,stack-type=IPV4_ONLY,subnet=default,no-address \
    --tags=iap-ssh,iap-pve \
    --create-disk boot=yes,type=hyperdisk-balanced,image-project=debian-cloud,image-family=debian-13,provisioned-iops=3000,provisioned-throughput=140,size=10,name=proxmox-installer,device-name=proxmox-installer \
    --create-disk type=hyperdisk-balanced,provisioned-iops=3000,provisioned-throughput=140,size=15,name=proxmox,device-name=proxmox \
    --no-restart-on-failure \
    --maintenance-policy=TERMINATE \
    --provisioning-model=SPOT \
    --instance-termination-action=STOP \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring
```

## SSH into facilitator instance

```shell
export PROJECT=proxmox-giraffe-7523
export ZONE=europe-west4-a
export INSTANCE=proxmox-installer

gcloud compute ssh $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --tunnel-through-iap
```

### Install PVE manually

```shell
sudo wget https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg -O /usr/share/keyrings/proxmox-archive-keyring.gpg
cat <<EOF | sudo tee /etc/apt/sources.list.d/pve-install-repo.sources > /dev/null
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

sudo apt update
sudo apt full-upgrade

# Install PVE packages
sudo apt install proxmox-ve postfix open-iscsi chrony systemd-boot-tools systemd-boot-efi fdisk
# NOTE: When asked where to install GRUB proceed without installing it to any disk/partition

# Create partitions on second disk
DEVICE=$(sudo readlink -f /dev/disk/by-id/google-proxmox)
cat <<EOF | sudo sfdisk $DEVICE
label: gpt
unit: sectors

${DEVICE}p15 : start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
${DEVICE}p1  : start=1050624, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

# Make sure kernel commandline is set correctly
echo "ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 intel_iommu=off" | sudo tee /etc/kernel/cmdline

# Update /etc/fstab (remove boot mount, update partition ID)
PARTUUID=$(sudo blkid -s PARTUUID -o value /dev/disk/by-id/google-proxmox-part1)
echo "PARTUUID=$PARTUUID / ext4 rw,discard,errors=remount-ro,x-systemd.growfs 0 1" | sudo tee /etc/fstab

# Initialize ESP
DEVICE=$(sudo readlink -f /dev/disk/by-id/google-proxmox)
sudo proxmox-boot-tool format ${DEVICE}p15
sudo udevadm settle -t 3
sudo proxmox-boot-tool init ${DEVICE}p15

# Move bits
sudo dd if=/dev/disk/by-id/google-proxmox-installer-part1 of=/dev/disk/by-id/google-proxmox-part1 bs=4M status=progress
```

## Establish IAP tunnel

```shell
export PROJECT=proxmox-giraffe-7523
export ZONE=europe-west4-a
export INSTANCE=proxmox-installer
export REMOTE_PORT=8006
export LOCAL_PORT=8006

gcloud compute start-iap-tunnel $INSTANCE $REMOTE_PORT \
    --project $PROJECT \
    --zone $ZONE \
    --local-host-port localhost:$LOCAL_PORT
```

## Create image

```shell
export PROJECT=proxmox-giraffe-7523
export REGION=eu
export ZONE=europe-west4-a
export INSTANCE=proxmox-installer
export DISK=proxmox
export IMAGE=proxmox-v$(date '+%Y%m%d')
export FAMILY=proxmox

gcloud compute instances stop $INSTANCE \
    --project $PROJECT \
    --zone $ZONE

gcloud compute images create $IMAGE \
    --project $PROJECT \
    --storage-location $REGION \
    --source-disk $DISK \
    --source-disk-zone $ZONE \
    --family $FAMILY \
    --architecture X86_64 \
    --guest-os-features "UEFI_COMPATIBLE,GVNIC,IDPF"
```

## Find regions / check availability

```shell
export PROJECT=proxmox-giraffe-7523

gcloud compute machine-types list \
  --project $PROJECT \
  --filter "name ~ '-metal$'"
```

## Create instance

```shell
export PROJECT=proxmox-giraffe-7523
export ZONE=europe-west4-a
export INSTANCE=proxmox-01

gcloud compute instances create $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --machine-type c4-standard-288-metal \
    --network-interface=nic-type=IDPF,stack-type=IPV4_ONLY,subnet=default,no-address \
    --tags=iap-ssh,iap-pve \
    --create-disk boot=yes,device-name=os,type=hyperdisk-balanced,image-project=$PROJECT,image-family=proxmox,provisioned-iops=3000,provisioned-throughput=140,size=50 \
    --create-disk name=data-1,device-name=data-1,type=hyperdisk-balanced,provisioned-iops=3000,provisioned-throughput=140,size=500 \
    --metadata serial-port-enable=true \
    --maintenance-policy TERMINATE \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring

# gcloud compute instances create $INSTANCE \
#     --project $PROJECT \
#     --zone $ZONE \
#     --machine-type c4-standard-288-metal \
#     --network-interface=nic-type=IDPF,stack-type=IPV4_ONLY,subnet=default,no-address \
#     --tags=iap-ssh,iap-pve \
#     --disk boot=yes,device-name=os,mode=rw,name=proxmox-01 \
#     --metadata serial-port-enable=true \
#     --maintenance-policy TERMINATE \
#     --shielded-secure-boot \
#     --shielded-vtpm \
#     --shielded-integrity-monitoring
```

## Connect to serial console

```shell
export PROJECT=proxmox-giraffe-7523
export ZONE=europe-west4-a
export INSTANCE=proxmox-01

gcloud compute connect-to-serial-port $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --port 1
```

gcloud compute instances stop $INSTANCE \
    --project $PROJECT \
    --zone $ZONE

gcloud compute instances detach-disk $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --disk $INSTANCE

gcloud compute instances attach-disk facilitator \
    --project $PROJECT \
    --zone $ZONE \
    --disk $INSTANCE \
    --device-name proxmox

gcloud compute instances start facilitator \
    --project $PROJECT \
    --zone $ZONE

gcloud compute ssh facilitator \
    --project $PROJECT \
    --zone $ZONE \
    --tunnel-through-iap

sudo mount /dev/nvme0n2p1 /mnt
sudo mount --rbind /proc /mnt/proc
sudo mount --rbind /dev /mnt/dev
sudo mount --rbind /sys /mnt/sys
sudo mount --rbind /run /mnt/run
sudo chroot /mnt

gcloud compute instances stop facilitator \
    --project $PROJECT \
    --zone $ZONE

gcloud compute instances detach-disk facilitator \
    --project $PROJECT \
    --zone $ZONE \
    --disk $INSTANCE

gcloud compute instances attach-disk $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --disk $INSTANCE \
    --device-name root \
    --boot

gcloud compute instances start $INSTANCE \
    --project $PROJECT \
    --zone $ZONE

gcloud compute ssh $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --tunnel-through-iap

gcloud compute instances create facilitator \
    --project $PROJECT \
    --zone $ZONE \
    --machine-type n4-highcpu-4 \
    --network-interface stack-type=IPV4_ONLY,subnet=default,no-address \
    --tags iap-ssh,iap-pve \
    --create-disk boot=yes,type=hyperdisk-balanced,image-project=debian-cloud,image-family=debian-13,provisioned-iops=3000,provisioned-throughput=140,size=50,name=root \
    --disk device-name=proxmox,mode=rw,name=proxmox-01 \
    --no-restart-on-failure \
    --maintenance-policy=TERMINATE \
    --provisioning-model=SPOT \
    --instance-termination-action=STOP \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring

gcloud compute ssh facilitator \
    --project $PROJECT \
    --zone $ZONE \
    --tunnel-through-iap

sudo mount /dev/nvme0n2p1 /mnt
sudo mount --rbind /proc /mnt/proc
sudo mount --rbind /dev /mnt/dev
sudo mount --rbind /sys /mnt/sys
sudo mount --rbind /run /mnt/run
sudo chroot /mnt

# Old

### Install PVE using installer

```shell
sudo apt-get install lvm2
wget https://enterprise.proxmox.com/iso/proxmox-ve_9.1-1.iso

# Create folders
sudo mkdir /mnt/iso
sudo mkdir /mnt/pve-base
sudo mkdir /mnt/pve-installer
sudo mkdir /mnt/work
sudo mkdir /mnt/merged
sudo mkdir /mnt/temp

sudo mount -o loop,ro proxmox-ve_9.1-1.iso /mnt/iso
sudo mount -o loop,ro /mnt/iso/pve-base.squashfs /mnt/pve-base
sudo mount -o loop,ro /mnt/iso/pve-installer.squashfs /mnt/pve-installer
sudo mount -t overlay overlay -o lowerdir=/mnt/iso:/mnt/pve-base:/mnt/pve-installer,upperdir=/mnt/temp,workdir=/mnt/work /mnt/merged

# Mount special directories for chroot
sudo mount --rbind /proc /mnt/merged/proc
sudo mount --rbind /sys /mnt/merged/sys
sudo mount --rbind /dev /mnt/merged/dev
sudo mount --rbind /run /mnt/merged/run

sudo chroot /mnt/merged

# Create files required by installer (may need to be called twice)
rm -rf /run/proxmox-installer
proxmox-low-level-installer dump-env

# Run installer
proxmox-auto-installer

# Exit chroot
exit

sudo vgscan
sudo vgchange -ay pve

```