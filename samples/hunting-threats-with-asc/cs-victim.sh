#!/usr/bin/env sh
export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install -y auditd
useradd  -g users -m -p $(openssl passwd -1 password) -s /bin/bash admin
useradd  -g users -m -p $(openssl passwd -1 princess) -s /bin/bash office
useradd  -g users -m -p $(openssl passwd -1 abc123) -s /bin/bash John
useradd  -g users -m -p $(openssl passwd -1 iloveyou) -s /bin/bash Jane
useradd  -g users -m -p $(openssl passwd -1 qwerty) -s /bin/bash Susan