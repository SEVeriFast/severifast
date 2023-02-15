#!/bin/bash

SCRIPT_DIR="$(dirname $0)"
KERNELS_DIR="${SCRIPT_DIR}/../kernels"
SRC_TREE_DIR="${SCRIPT_DIR}/../src"
LINUX_SRC_DIR="${SRC_TREE_DIR}/linux"
LINUX_SRC_URL="https://github.com/severifast/linux"
CONFIGS_DIR="${SCRIPT_DIR}/../kernel-configs"
    
build_kernels()
{
    ! [ -d ${LINUX_SRC_DIR} ] && {
	git clone --single-branch --branch tracepoints ${LINUX_SRC_URL} ${LINUX_SRC_DIR}
    }

    ! [ -d ${KERNELS_DIR} ] && {
	mkdir ${KERNELS_DIR}
	
	for config in $(ls ${CONFIGS_DIR}); do
	    echo $config

	    cp ${CONFIGS_DIR}/${config}\
	       ${LINUX_SRC_DIR}/.config

	    make -C ${LINUX_SRC_DIR} olddefconfig
	    make -C ${LINUX_SRC_DIR}\
		 -j$(getconf _NPROCESSORS_ONLN) bzImage

	    cp ${LINUX_SRC_DIR}/arch/x86/boot/bzImage\
	       ${KERNELS_DIR}/bzImage-${config%.*}-lz4

	    cp ${LINUX_SRC_DIR}/arch/x86/boot/compressed/vmlinux.bin ${KERNELS_DIR}/vmlinux-${config%.*}

	done
    }
    	     
}

# build_qemu
# build_ovmf
build_kernels
