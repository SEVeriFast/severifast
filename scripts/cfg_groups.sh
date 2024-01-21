#!/bin/sh

sudo groupadd docker
sudo groupadd kvm
sudo groupadd sev
sudo chown :docker /var/run/docker.sock
sudo chmod g+rw /var/run/docker.sock
sudo chown www-data:sev /dev/sev
sudo chmod g+rw /dev/sev
sudo chown :kvm /dev/kvm
sudo chmod g+rw /dev/kvm

[ $(stat -c "%G" /var/run/docker.sock) = docker ] && sudo usermod -aG docker ${USER} \
    && echo "Access granted to Docker"
[ $(stat -c "%G" /dev/kvm) = kvm ] && sudo usermod -aG kvm ${USER} \
    && echo "Access granted to KVM"
[ $(stat -c "%G" /dev/sev) = sev ] && sudo usermod -aG sev ${USER} \
    && echo "Access granted to SEV"

sudo systemctl stop docker
sudo systemctl start docker
