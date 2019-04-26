#!/usr/bin/env sh
export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install -y auditd

exists=$(id -u admin > /dev/null 2>&1; echo $?)
if [ $exists -eq 1 ]; then
    useradd  -g users -m -p $(openssl passwd -1 password) -s /bin/bash admin
fi

exists=$(id -u office > /dev/null 2>&1; echo $?)
if [ $exists -eq 1 ]; then
    useradd  -g users -m -p $(openssl passwd -1 princess) -s /bin/bash office
fi

exists=$(id -u John > /dev/null 2>&1; echo $?)
if [ $exists -eq 1 ]; then
    useradd  -g users -m -p $(openssl passwd -1 abc123) -s /bin/bash John
fi

exists=$(id -u Jane > /dev/null 2>&1; echo $?)
if [ $exists -eq 1 ]; then
    useradd  -g users -m -p $(openssl passwd -1 iloveyou) -s /bin/bash Jane
fi

exists=$(id -u Susan > /dev/null 2>&1; echo $?)
if [ $exists -eq 1 ]; then
    useradd  -g users -m -p $(openssl passwd -1 qwerty) -s /bin/bash Susan
fi