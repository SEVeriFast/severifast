#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
. ${SCRIPT_DIR}/common

sudo cp ${SEV_GUEST_SRC_DIR}/sev-guest-parse-report /bin/
sudo cp ${SEV_TOOL_SRC_DIR}/src/sevtool /bin
sudo cp ${BIN_DIR}/perf /bin

pushd ${HOST_KERNEL_BUILD_DIR}
echo "Installing host kernel"
sudo dpkg -i linux-headers*
sudo dpkg -i linux-image-6.1.0-rc4-snp-host_*
sudo dpkg -i linux-libc*
popd
