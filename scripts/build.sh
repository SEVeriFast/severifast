#!/bin/bash

. ./scripts/common

build_kernels()
{
    ! [ -d ${LINUX_SRC_DIR} ] && {
	git clone --single-branch --branch\
	    tracepoints ${LINUX_SRC_URL} ${LINUX_SRC_DIR}
    }

    ! [ -d ${KERNELS_DIR} ] && {
	mkdir ${KERNELS_DIR}
	
	for config in $(ls ${CONFIGS_DIR}); do
	    echo $config

	    cp ${CONFIGS_DIR}/${config}\
	       ${LINUX_SRC_DIR}/.config

	    pushd ${LINUX_SRC_DIR}
	    make -C ${LINUX_SRC_DIR} olddefconfig
	    make -C ${LINUX_SRC_DIR}\
		 -j$(getconf _NPROCESSORS_ONLN) bzImage
	    popd

	    cp ${BZIMAGE_BUILD}\
	       ${KERNELS_DIR}/bzImage-${config%.*}-lz4

	    cp ${VMLINUX_BUILD}\
	       ${KERNELS_DIR}/vmlinux-${config%.*}

	done
    }
    	     
}

build_qemu()
{
    ! [ -d ${QEMU_SRC_DIR} ] && {
	git clone --single-branch --branch\
	    tracepoints ${QEMU_SRC_URL} ${QEMU_SRC_DIR}
    }

    ! [ -f ${QEMU_BUILD} ] && {
	pushd ${QEMU_SRC_DIR}
	./configure --target-list=x86_64-softmmu
	make -j$(getconf _NPROCESSORS_ONLN)
	popd
    }
}

build_kernels
build_qemu
