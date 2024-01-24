#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
. ${SCRIPT_DIR}/common

ROOTFS=${ROOT_DIR}/images/rootfs.ext4
LOG_FILE=/tmp/qemu.log
TRACE_EVENTS=/tmp/events
OVMF=${BIN_DIR}/AmdSev-1MB.fd
SEV=""
NET_DEV="tap0"
INIT="/bin/fc_init"

setup () {
    if [ "${SNP}" == "1" ]; then
        NOAPIC="noapic noapictimer"
    fi

    if [ "${CONSOLE}" == "1" ]; then
        CMDLINE="reboot=k panic=-1 acpi=off ${NOAPIC} reboot=k panic=-1 earlyprintk=ttyS0 swiotlb=512 console=ttyS0 root=/dev/vda ro rdinit=${INIT}"
    else
        CMDLINE="reboot=k panic=-1 ${NOAPIC} swiotlb=512 nomodules 8250.nr_uarts=0 i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd root=/dev/vda ro rdinit=${INIT}"
    fi
}

run_qemu() {
    if [ "${SNP}" = "1" ]; then
        TYPE="-drive if=pflash,format=raw,unit=0,file=${OVMF},readonly=on\
            -machine confidential-guest-support=sev0\
            -object sev-snp-guest,id=sev0,cbitpos=51,reduced-phys-bits=1,kernel-hashes=on\
            -object memory-backend-memfd-private,id=ram1,size=256M,share=true\
            -machine memory-backend=ram1,kvm-type=protected"
    elif [ "${ES}" = "1" ]; then
        TYPE="-drive if=pflash,format=raw,unit=0,file=${OVMF},readonly=on\
            -machine confidential-guest-support=sev0\
            -object sev-guest,id=sev0,policy=0x5,cbitpos=51,reduced-phys-bits=1,kernel-hashes=on"
    elif [ "${SEV}" = "1" ]; then
        TYPE="-drive if=pflash,format=raw,unit=0,file=${OVMF},readonly=on\
            -machine confidential-guest-support=sev0\
            -object sev-guest,id=sev0,policy=0x1,cbitpos=51,reduced-phys-bits=1,kernel-hashes=on"
    fi


    INITRD_CONF=
    if [ -f "${INITRD}" ]; then
        INITRD_CONF="-initrd ${INITRD}"
    fi

    echo "kvm_sev_launch_update_data" > ${TRACE_EVENTS}
    echo "kvm_sev_hash_kernel_start" >> ${TRACE_EVENTS}
    echo "kvm_sev_hash_kernel_done" >> ${TRACE_EVENTS}
    echo "kvm_sev_hash_initrd_start" >> ${TRACE_EVENTS}
    echo "kvm_sev_hash_initrd_done" >> ${TRACE_EVENTS}
    echo "kvm_sev_snp_measure_regions_start" >> ${TRACE_EVENTS}
    echo "kvm_sev_snp_measure_regions_done" >> ${TRACE_EVENTS}
    echo "kvm_sev_launch_finish" >> ${TRACE_EVENTS}
    echo "kvm_sev_launch_measurement" >> ${TRACE_EVENTS}

    if ! [ "$NO_NET" == "1" ]; then
        NET_DEV_CONF="-netdev tap,id=mynet0,ifname=${NET_DEV},script=no,downscript=no\
                    -device virtio-net-pci,netdev=mynet0"
    fi

    ${QEMU_BUILD} \
        -D ${LOG_FILE}\
        -monitor file:${LOG_FILE}\
        -kernel ${KERNEL}\
        ${INITRD_CONF}\
        -append "${CMDLINE}"\
        -enable-kvm\
        -smp 1\
        -m 256M\
        -machine q35,vmport=off\
        -cpu EPYC-v4\
        -drive file=${ROOTFS},if=none,id=disk0,format=raw,readonly=on\
        -device virtio-blk,id=scsi,disable-legacy=on,iommu_platform=true,drive=disk0\
        ${NET_DEV_CONF}\
        ${TYPE}\
        -trace events=${TRACE_EVENTS}\
        -msg timestamp=on\
        -nographic\
        -no-reboot > /dev/null 2>&1  &

    QEMU_PID=$!
    echo ${QEMU_PID}
    wait ${QEMU_PID}
}

while [ -n "$1" ]; do
	case "$1" in
    -kernel) 
        KERNEL=$2
        shift
        ;;
    -initrd)
        INITRD=$2
        shift
        ;;
    -snp)
        SNP="1"
        ;;
    -es)
        ES="1"
        ;;
    -sev)
        SEV="1"
        ;;
    -vm-num)
        VM_NUM=$2
        NET_DEV="tap$2"
        LOG_FILE="/tmp/qemu$2.log"
        shift
        ;;
    -attest)
	ATTEST="1"
        INIT="/bin/myinit"
        ;;
    -console)
        CONSOLE="1"
        ;;
    -no-net)
        NO_NET="1"
        ;;
    esac
    shift
done

if [ ! -f "${KERNEL}" ]; then
    echo "Bad kernel path"
    exit 1
fi

setup
run_qemu
