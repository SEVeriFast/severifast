#!/bin/bash

# give access to kvm, sev
sudo ${SCRIPT_DIR}/cfg_groups.sh

# set up attestation server
sudo ${ROOT_DIR}/scripts/setup-attestation-server.sh

# enable huge pages for sev-snp
echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/shmem_enabled > /dev/null
