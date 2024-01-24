#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
. ${SCRIPT_DIR}/common

# dependencies for building linux
sudo apt update
sudo apt install -y build-essential flex bison libelf-dev libssl-dev lz4 ca-certificates curl gnupg ninja-build pkg-config libglib2.0-dev libpixman-1-dev nginx python-is-python3 mtools nasm iasl nginx fcgiwrap autoconf uuid-dev zip debhelper dh-virtualenv libpfm4-dev libtraceevent-dev python3-matplotlib python3-seaborn
# setup to install docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
# install docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# start docker
sudo systemctl start docker
# install rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

source "$HOME/.cargo/env"
# dependencies for building firmware
cargo install cargo-binutils
rustup component add llvm-tools-preview
