#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
. ${SCRIPT_DIR}/common

build_guest_kernels()
{
    ! [ -d ${LINUX_SRC_DIR} ] && {
	git clone --depth 1 ${LINUX_SRC_URL} ${LINUX_SRC_DIR}
	pushd ${LINUX_SRC_DIR}
	git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
	git fetch --depth 1
	popd
    }

    ! [ -d ${KERNELS_DIR} ] && {
	mkdir ${KERNELS_DIR}
	
	for config in $(ls ${CONFIGS_DIR}); do
	    echo $config

	    cp ${CONFIGS_DIR}/${config}\
	       ${LINUX_SRC_DIR}/.config

	    pushd ${LINUX_SRC_DIR}
	    git checkout snp-lazy-pvalidate-handlers
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

build_host_kernel()
{
    ! [ -d ${LINUX_SRC_DIR} ] && {
	git clone --depth 1 ${LINUX_SRC_URL} ${LINUX_SRC_DIR}
	pushd ${LINUX_SRC_DIR}
	git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
	git fetch --depth 1
	popd
    }

    ! [ -f ${HOST_KERNEL_BUILD_DIR}/linux-image-6.1.0-rc4-snp-host_* ] && {
	pushd ${LINUX_SRC_DIR}
	git checkout nx-hugepages-fix
	popd
	
	echo "Building host kernel"
	mkdir -p ${HOST_KERNEL_BUILD_DIR}
	mkdir -p ${HOST_KERNEL_BUILD_DIR}/src
	pushd ${HOST_KERNEL_BUILD_DIR}
	make -C ${LINUX_SRC_DIR} mrproper
	make -C ${LINUX_SRC_DIR} O=${HOST_KERNEL_BUILD_DIR}/src defconfig
	pushd ${HOST_KERNEL_BUILD_DIR}/src
	cp /boot/config-$(uname -r) .config
	scripts/config --disable SYSTEM_TRUSTED_KEYS
	scripts/config --disable SYSTEM_REVOCATION_KEYS
	make olddefconfig
	make -j $(nproc)
	make -j $(nproc) bindeb-pkg LOCALVERSION=-snp-host DEB_DESTDIR=${HOST_KERNEL_BUILD_DIR}
	popd
	
	echo "Installing host kernel"
	sudo dpkg -i linux-headers*
	sudo dpkg -i linux-image-6.1.0-rc4-snp-host_*
	sudo dpkg -i linux-libc*
	popd

	pushd ${LINUX_SRC_DIR}/tools/perf
	make -j $(nproc)
	cp ./perf ${BIN_DIR}/
	popd
    }
}

build_qemu()
{
    ! [ -d ${QEMU_SRC_DIR} ] && {
	git clone --single-branch --branch\
	    snp ${QEMU_SRC_URL} ${QEMU_SRC_DIR}
    }

    ! [ -f ${QEMU_BUILD} ] && {
	echo "Building QEMU"
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
	echo "Building OVMF"
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
	echo "Building SEV-SNP firmware"
	source "$HOME/.cargo/env"
	pushd ${FW_SRC_DIR}
	git checkout sev-snp
	cargo b
	cp ./sev-fw.bin ${BIN_DIR}/snp-fw.bin
	popd
    }

    ! [ -f ${FW_BUILD_DIRECT_BOOT} ] && {
	echo "Building SEV-SNP direct boot firmware"
	source "$HOME/.cargo/env"
	pushd ${FW_SRC_DIR}
	git checkout sev-snp-direct-boot
	cargo b
	cp ./sev-fw.bin ${BIN_DIR}/snp-direct-boot-fw.bin
	popd
    }

    ! [ -f ${ES_FW_BUILD} ] && {
	echo "Building SEV-ES firmware"
	source "$HOME/.cargo/env"
	pushd ${FW_SRC_DIR}
	git checkout sev-es-rework
	cargo b
	cp ./sev-fw.bin ${BIN_DIR}/sev-es-fw.bin
	popd
    }

    ! [ -f ${ES_FW_BUILD_DIRECT_BOOT} ] && {
	echo "Building SEV-ES direct boot firmware"
	source "$HOME/.cargo/env"
	pushd ${FW_SRC_DIR}
	git checkout sev-es-direct-boot
	cargo b
	cp ./sev-fw.bin ${BIN_DIR}/sev-es-direct-boot-fw.bin
	popd
    }
}

build_kernel_hasher() {
    ! [ -f ${KERNEL_HASHER} ] && {
	echo "Building kernel hasher"
	source "$HOME/.cargo/env"
	pushd ${KERNEL_HASHER_DIR}
	cargo build --release
	popd
    }
}

build_sev_tool() {
    ! [ -d ${SEV_TOOL_SRC_DIR} ] && {
	git clone ${SEV_TOOL_SRC_URL} ${SEV_TOOL_SRC_DIR}
    }
    
    ! [ -f /bin/sevtool ] && {
	echo "Building sev-tool"
	pushd ${SEV_TOOL_SRC_DIR}
	autoreconf -vif && ./configure && make
	sudo cp ./src/sevtool /bin/
	popd
    }
}

build_sev_guest() {
    ! [ -d ${SEV_GUEST_SRC_DIR} ] && {
	git clone ${SEV_GUEST_SRC_URL} ${SEV_GUEST_SRC_DIR}
    }
    
    ! [ -f /bin/sev-guest-parse-report ] && {
	echo "Building sev-guest"
	pushd ${SEV_GUEST_SRC_DIR}
	make -j $(nproc)
	sudo cp ${SEV_GUEST_SRC_DIR}/sev-guest-parse-report /bin/
	popd
    }
}

build_snp_host() {
    ! [ -d ${SNP_HOST_SRC_DIR} ] && {
	git clone ${SNP_HOST_SRC_URL} ${SNP_HOST_SRC_DIR}
    }
    
    ! [ -f ${BIN_DIR}/snphost ] && {
	echo "Building snp-host"
	pushd ${SNP_HOST_SRC_DIR}
        cargo build --release
	sudo cp ${SNP_HOST_SRC_DIR}/target/release/snphost ${BIN_DIR}
	popd
    } 
}

while [ -n "$1" ]; do
    case "$1" in
	-host) 
            HOST=1
            shift
            ;;
    esac
    shift
done

mkdir -p ${SRC_TREE_DIR}

if [ "${HOST}" = "1" ]; then
   build_host_kernel
fi

build_guest_kernels
build_qemu
build_firecracker
build_ovmf
build_fw
build_kernel_hasher
build_sev_tool
build_sev_guest
build_snp_host

${ROOT_DIR}/scripts/gen-certs.sh
${ROOT_DIR}/scripts/setup-attestation-server.sh
