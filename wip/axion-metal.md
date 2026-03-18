# GCE

## Find regions / check availability

```shell
export PROJECT=axion-hackaton-3298-sandbox

gcloud compute machine-types list \
  --project $PROJECT \
  --filter "name ~ '^c4a.+-metal$'"
```

## Create VPC and subnet

```shell
export PROJECT=axion-hackaton-3298-sandbox
export REGION=us-central1
export ZONE=us-central1-b
export RANGE=10.0.1.0/24

gcloud compute networks create $PROJECT \
    --project $PROJECT \
    --region $REGION \
    --subnet-mode custom

gcloud compute networks subnets create $ZONE \
    --project $PROJECT \
    --region $REGION \
    --network $PROJECT \
    --range $RANGE \
    --enable-private-ip-google-access \
    --enable-flow-logs \
    --logging-metadata include-all
```

## Create firewall rules

```shell
export PROJECT=axion-hackaton-3298-sandbox
export REGION=us-central1
export RANGE=10.0.1.0/24

gcloud compute firewall-rules create allow-ssh \
    --project $PROJECT \
    --network $PROJECT \
    --priority 1000 \
    --direction INGRESS \
    --allow tcp:22 \
    --source-ranges 0.0.0.0/0 \
    --enable-logging \
    --logging-metadata include-all

gcloud compute firewall-rules create allow-http \
    --project $PROJECT \
    --network $PROJECT \
    --priority 1000 \
    --direction INGRESS \
    --allow tcp:8080 \
    --source-ranges 0.0.0.0/0 \
    --enable-logging \
    --logging-metadata include-all

gcloud compute firewall-rules create allow-all-internal \
    --project $PROJECT \
    --network $PROJECT \
    --priority 5000 \
    --direction INGRESS \
    --action ALLOW \
    --rules all \
    --source-ranges $RANGE \
    --enable-logging \
    --logging-metadata include-all

gcloud compute firewall-rules create deny-ingress \
    --project $PROJECT \
    --network $PROJECT \
    --priority 15000 \
    --direction INGRESS \
    --action DENY \
    --rules all \
    --enable-logging \
    --logging-metadata include-all
```

## Create instance

```shell
export PROJECT=axion-hackaton-3298-sandbox
export ZONE=us-central1-b
export INSTANCE=cuttlefish-0

gcloud compute instances create $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --machine-type c4a-highmem-96-metal \
    --network-interface=nic-type=IDPF,stack-type=IPV4_ONLY,network=$PROJECT,subnet=$ZONE \
    --tags=iap-ssh,iap-http \
    --create-disk boot=yes,type=hyperdisk-balanced,image-project=debian-cloud,image-family=debian-13-arm64,provisioned-iops=3000,provisioned-throughput=140,size=100 \
    --maintenance-policy TERMINATE \
    --metadata enable-oslogin=TRUE,serial-port-enable=TRUE \
    --shielded-secure-boot \
    --scopes https://www.googleapis.com/auth/androidbuild.internal,https://www.googleapis.com/auth/cloud-platform
```

## Enable serial console for instance

```shell
export PROJECT=axion-hackaton-3298-sandbox
export ZONE=us-central1-b
export INSTANCE=cuttlefish-0

gcloud compute instances add-metadata $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --metadata serial-port-enable=TRUE
```

## Connect to serial console

```shell
export PROJECT=axion-hackaton-3298-sandbox
export ZONE=us-central1-b
export INSTANCE=cuttlefish-0

gcloud compute connect-to-serial-port $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --port 1
```

## SSH into instance

```shell
export PROJECT=axion-hackaton-3298-sandbox
export ZONE=us-central1-b
export INSTANCE=cuttlefish-0

gcloud compute ssh $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --tunnel-through-iap
```

## Establish IAP tunnel to Cloud Orchestrator

```shell
export PROJECT=axion-hackaton-3298-sandbox
export ZONE=us-central1-b
export INSTANCE=cuttlefish-0

gcloud compute start-iap-tunnel $INSTANCE 8080 \
    --project $PROJECT \
    --zone $ZONE \
    --local-host-port localhost:58081
```

## Delete instance

```shell
export PROJECT=axion-hackaton-3298-sandbox
export ZONE=us-central1-b
export INSTANCE=cuttlefish-0

gcloud compute instances delete $INSTANCE \
    --project $PROJECT \
    --zone $ZONE \
    --quiet
```

# Cloud Android

## Install Docker

```shell
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker's apt repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to Docker group
sudo usermod -aG docker $USER
```

## Install cvdr

```shell
# Add Cuttlefish's repository GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://us-apt.pkg.dev/doc/repo-signing-key.gpg -o /etc/apt/keyrings/android-cuttlefish-artifacts.asc
sudo chmod a+r /etc/apt/keyrings/android-cuttlefish-artifacts.asc

## Add Cuttlefish's apt repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/android-cuttlefish-artifacts.asc] \
    https://us-apt.pkg.dev/projects/android-cuttlefish-artifacts android-cuttlefish-nightly main" | \
    sudo tee /etc/apt/sources.list.d/android-cuttlefish-artifacts.list > /dev/null

# Install cvdr
sudo apt update
sudo apt install cuttlefish-cvdremote

# Update cvdr configuraton
cvdr --help > /dev/null
wget -O $(cd ~; echo $PWD)/.config/cvdr/cvdr.toml \
    https://raw.githubusercontent.com/google/cloud-android-orchestration/refs/heads/main/scripts/on-premises/single-server/cvdr.toml
```

## Install and start adb

```shell
sudo apt install adb
adb start-server
```

## Start Cloud Orchestrator

```shell
# Download configuration for local server
wget -O $(cd ~; echo $PWD)/conf.toml \
    https://raw.githubusercontent.com/google/cloud-android-orchestration/refs/heads/main/scripts/on-premises/single-server/conf.toml

docker pull us-docker.pkg.dev/android-cuttlefish-artifacts/cuttlefish-orchestration/cuttlefish-cloud-orchestrator
docker run \
    --name cloud-orchestrator \
    --restart unless-stopped \
    -d \
    -p 8080:8080 \
    -e CONFIG_FILE="/conf.toml" \
    -v $(cd ~; echo $PWD)/conf.toml:/conf.toml \
    -v /var/run/docker.sock:/var/run/docker.sock \
    us-docker.pkg.dev/android-cuttlefish-artifacts/cuttlefish-orchestration/cuttlefish-cloud-orchestrator:latest
```

## Download Android binaries

```shell
# https://ci.android.com/builds/submitted/14818820/aosp_cf_arm64_only_phone-userdebug/latest/aosp_cf_arm64_only_phone-img-14818820.zip
URI=''
wget "$URI" -O $(cd ~; echo $PWD)/aosp_cf_arm64_only_phone-img.zip

# https://ci.android.com/builds/submitted/14818820/aosp_cf_arm64_only_phone-userdebug/latest/cvd-host_package.tar.gz
URI=''
wget "$URI" -O $(cd ~; echo $PWD)/cvd-host_package.tar.gz
```

```shell
export BUCKET="axion-hackaton-3298"
gcloud storage cp gs://$BUCKET/aosp_cf_arm64_auto.zip ~/
gcloud storage cp gs://$BUCKET/cvd-host_package.tar.gz ~/
```

## Create cvd

```shell
cvdr create \
    --local_images_zip_src=$(cd ~; echo $PWD)/aosp_cf_arm64_only_phone.zip \
    --local_cvd_host_pkg_src=$(cd ~; echo $PWD)/cvd-host_package.tar.gz

# Pull orchestration image before launching cvd
docker pull us-docker.pkg.dev/android-cuttlefish-artifacts/cuttlefish-orchestration/cuttlefish-orchestration:latest

HOST=$(cvdr host create)
cvdr create \
    --host=$HOST \
    --local_images_zip_src=$(cd ~; echo $PWD)/aosp_cf_arm64_auto.zip \
    --local_cvd_host_pkg_src=$(cd ~; echo $PWD)/cvd-host_package.tar.gz

# HOST=$(cvdr host create)

# cvdr create \
#     --host=$HOST \
#     --branch aosp-android-latest-release \
#     --build_target=aosp_cf_arm64_only_phone-userdebug
```

# Links 

* https://docs.google.com/document/d/1BFP1KmfhZagKfZGIjiOTcDrtUDH6OjCi3C2gZvjGKgg/edit?tab=t.0
* https://docs.google.com/presentation/d/1wNPN36DGErf7DJx9UJ79rIHiN6Tmoxixjxx-Gem8UcY/edit?slide=id.g25a7a9aa5e8_0_451#slide=id.g25a7a9aa5e8_0_451
* https://github.com/google/cloud-android-orchestration/blob/main/docs/cvdr.md
* https://ci.android.com/builds/branches/aosp-android-latest-release/grid?legacy=1
* https://github.com/googlecloudplatform/horizon-sdv


# Assessment

## Part 1

gcloud compute networks list \
    --project XXX \
    --output json

gcloud compute networks subnets list \
    --project XXX \
    --region XXX \
    --output json

## Part 2

gcloud compute instances list \
    --project XXX \
    --zone XXX \
    --output json

- Machine type: c4a-highmem-96-metal
- Metadata
    - enable-oslogin
    - serial-port-enable

## Part 3

dpkg -l docker-ce
docker ps 

sudo docker ps --format=json // check for us-docker.pkg.dev/android-cuttlefish-artifacts/cuttlefish-orchestration/cuttlefish-cloud-orchestrator image