#!/bin/bash

. ./scripts/common

build_guest_kernels()
{
    ! [ -d ${LINUX_SRC_DIR} ] && {
	git clone --single-branch --branch\
	    snp-lazy-pvalidate-handlers ${LINUX_SRC_URL} ${LINUX_SRC_DIR}
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

	    pushd ${LINUX_SRC_DIR}
	    ./scripts/config --disable CONFIG_KERNEL_LZ4
	    ./scripts/config --enable CONFIG_KERNEL_GZIP
	    make -C ${LINUX_SRC_DIR} olddefconfig
	    make -C ${LINUX_SRC_DIR}\
		 -j$(getconf _NPROCESSORS_ONLN) bzImage
	    popd
	    cp ${BZIMAGE_BUILD}\
	       ${KERNELS_DIR}/bzImage-${config%.*}-gzip

	done
    }
}

build_qemu()
{
    ! [ -d ${QEMU_SRC_DIR} ] && {
	git clone --single-branch --branch\
	    snp ${QEMU_SRC_URL} ${QEMU_SRC_DIR}
    }

    ! [ -f ${QEMU_BUILD} ] && {
	pushd ${QEMU_SRC_DIR}
	./configure --target-list=x86_64-softmmu
	make -j$(getconf _NPROCESSORS_ONLN)
	popd
    }
}

build_firecracker()
{
    ! [ -d ${FC_SRC_DIR} ] && {
	git clone ${FC_SRC_URL} ${FC_SRC_DIR}
    }

    ! [ -f ${FC_BUILD} ] && {
	echo "Building Firecracker"
	source "$HOME/.cargo/env"
	pushd ${FC_SRC_DIR}
	git checkout sev-snp-devel
	./tools/devtool -y build --release
	popd
    }
}

build_ovmf() {
    ! [ -d ${OVMF_SRC_DIR} ] && {
	git clone --single-branch -b snp-timestamps ${OVMF_SRC_URL} ${OVMF_SRC_DIR}
    }

    ! [ -f ${OVMF_BUILD} ] && {
	pushd ${OVMF_SRC_DIR}
	git checkout snp-timestamps
	git submodule update --init --recursive
	make -C ./BaseTools -j $(nproc)
	. ./edksetup.sh --reconfig
	touch ./OvmfPkg/AmdSev/Grub/grub.efi
	build -q -n $(nproc) -a X64 -t GCC5 -p OvmfPkg/AmdSev/AmdSevX64.dsc -b RELEASE -v
	cp ${OVMF_BUILD} ${BIN_DIR}/AmdSev-1MB.fd
	popd
    }
}

build_fw() {
    mkdir -p ${BIN_DIR}
    
    ! [ -d ${FW_SRC_DIR} ] && {
	git clone ${FW_SRC_URL} ${FW_SRC_DIR}
    }
    
    ! [ -f ${FW_BUILD} ] && {
	source "$HOME/.cargo/env"
	pushd ${FW_SRC_DIR}
	git checkout sev-snp
	cargo b
	cp ./sev-fw.bin ${BIN_DIR}/snp-fw.bin
	popd
    }

    ! [ -f ${FW_BUILD_DIRECT_BOOT} ] && {
	source "$HOME/.cargo/env"
	pushd ${FW_SRC_DIR}
	git checkout sev-snp-direct-boot
	cargo b
	cp ./sev-fw.bin ${BIN_DIR}/snp-direct-boot-fw.bin
	popd
    }
}

mkdir -p ${SRC_TREE_DIR}

build_guest_kernels
build_qemu
build_firecracker
build_ovmf
build_fw
