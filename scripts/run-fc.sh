#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
. ${SCRIPT_DIR}/common

ROOTFS=${ROOT_DIR}/images/rootfs.ext4
# default 256MB
MEM_SIZE=256
KERNEL_HASHER=${ROOT_DIR}/kernel-hasher/target/release/kernel-hasher
HASHES_DIR=${ROOT_DIR}/hashes
FC_CONFIG_BASE=${ROOT_DIR}/fc-config/vm_config_base.json
FC_CONFIG=${ROOT_DIR}/fc-config/vm_config.json
FC_LOG=/tmp/fc-log.file
HUGEPAGES="    \"hugepages\": true"
NET_DEV="tap0"
POLCIY=1

setup_cmdline() {
    # set up kernel command line

    if [ -f "${INITRD}" ]; then
	# set init for ramfs
        INIT="rdinit=/bin/fc_init"
    else
	# set init for rootfs
        INIT="init=/bin/fc_init"
    fi

    if [ "${ATTEST}" == "1" ]; then
	# set init for doing attestation
        INIT="rdinit=/bin/myinit"
    fi

    if [ "${SNP}" == "1" ]; then
        NOAPIC="noapic noapictimer"
    fi

    # console for debug
    if [ "${CONSOLE}" == "1" ]; then
        CMDLINE="reboot=k panic=-1 ${NOAPIC} nosmp swiotlb=512 acpi=off console=ttyS0 root=/dev/vda i8042.noaux i8042.nopnp i8042.dumbkbd i8042.nomux ${INIT}"
    else
        CMDLINE="reboot=k panic=-1 ${NOAPIC} nosmp swiotlb=512 pci=off acpi=off nomodules 8250.nr_uarts=0 i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd root=/dev/vda ${INIT}"
    fi
}

hash_components() {
    KERNEL_HASHES="${HASHES_DIR}/$(basename $KERNEL).hash"

    #Hash the kernel if not already hashed
    if [ ! -f "${KERNEL_HASHES}" ]; then
        echo "Generating hashes for $(basename ${KERNEL})"
        ${KERNEL_HASHER} ${KERNEL} > ${KERNEL_HASHES}
        echo "Hashes stored in ${KERNEL_HASHES}"
    fi

    # Hash the initrd if we are using one
    if [ -f "${INITRD}" ]; then
        INITRD_HASH_PATH="./hashes/$(basename $INITRD).hash"

        if [ ! -f "${INITRD_HASH_PATH}" ]; then
            echo "Generating hash for $(basename ${INITRD})"
            sha256sum $INITRD | awk '{print $1}' | xxd -r -p > $INITRD_HASH_PATH
            echo "Hash stored in ${INITRD_HASH}"
        fi
    fi
}

configure_sev() {
    if [ "$SNP" == "1"  ]; then
        # check for uncompressed kernel
	if file $KERNEL | grep bzImage > /dev/null ; then
            FIRMWARE="./bin/snp-fw.bin"
        else
            FIRMWARE="./bin/snp-direct-boot-fw.bin"
        fi
        SNP_CONF="\"snp\": true,"
    else
        if file $KERNEL | grep bzImage > /dev/null ; then
            FIRMWARE="./bin/sev-es-fw.bin"
        else
            FIRMWARE="./bin/sev-es-direct-boot-fw.bin"
        fi
        SNP_CONF="\"snp\": false,"
    fi

    # get correct certs for policy
    if [[ ${ES} == "1" || ${SNP} == "1"  ]]; then
	LAUNCH_BLOB="./certs/guest/launch/sev-es/launch_blob.bin"
        GODH_CERT="./certs/guest/launch/sev-es/godh.cert"
    else
        POLICY=1
        LAUNCH_BLOB="./certs/guest/launch/sev/launch_blob.bin"
        GODH_CERT="./certs/guest/launch/sev/godh.cert"
    fi
}

choose_firmware() {
    if [[ ${SEV} == "1" || ${ES} == "1" || ${SNP} == "1" ]]; then
        if [ -f "${FIRMWARE_PATH}" ]; then
	    FIRMWARE=$FIRMWARE_PATH
        fi
    fi
}

build_vm_cfg() {
    if [[ ${SEV} == "1" || ${ES} == "1" || ${SNP} == "1" ]]; then
        if [ -f "${INITRD}" ]; then
            INITRD_HASH_CONF="\"initrd_hash_path\": \"${INITRD_HASH_PATH}\","
        fi

        SEV_CONF=$(echo "  \"sev-config\": {"\
	     "\"firmware_path\": \"${FIRMWARE}\","\
             "${SNP_CONF}"\
	     "\"kernel_hash_path\": \"${KERNEL_HASHES}\","\
	     "${INITRD_HASH_CONF}"\
	     "\"policy\": ${POLICY},"\
	     "\"session_path\": \"${LAUNCH_BLOB}\","\
	     "\"dh_cert\": \"${GODH_CERT}\""\
	     "},")
    else
        SEV_CONF="  \"sev-config\": null,"
    fi


    if ! [ "$NO_NET" == "1" ]; then
	NET_DEV_CONF=$(echo " \"network-interfaces\": ["\
			    "{"\
			    "\"iface_id\": \"eth0\","\
			    "\"guest_mac\": \"AA:FC:00:00:00:01\","\
			    "\"host_dev_name\": \"${NET_DEV}\""\
			    "}],")
    else
	NET_DEV_CONF="\"network-interfaces\": [],"
    fi	

    #edit vm config file with new params
    KERNEL_CONF="    \"kernel_image_path\": \"${KERNEL}\","
    if [ -f "${INITRD}" ]; then
        INITRD_CONF="    \"initrd_path\": \"${INITRD}\""
    else
        INITRD_CONF="    \"initrd_path\": null"
    fi

    ROOTFS_CONF="      \"path_on_host\": \"${ROOTFS}\","
    BOOT_ARGS_CONF="    \"boot_args\": \"$CMDLINE\","
    MEM_CONF="    \"mem_size_mib\": ${MEM_SIZE},"
    # copy base config and replace args
    cat ${FC_CONFIG_BASE} | 
    sed "s|.*kernel_image_path.*|${KERNEL_CONF}|" |
    sed "s|.*path_on_host.*|${ROOTFS_CONF}|" |
    sed "s|.*initrd_path.*|${INITRD_CONF}|" |
    sed "s|.*boot_args.*|${BOOT_ARGS_CONF}|" |
    sed "s|.*mem_size_mib.*|${MEM_CONF}|" |
    sed "s|.*hugepages.*|${HUGEPAGES}|" |
    sed "s|.*network-interfaces.*|${NET_DEV_CONF}|" |
    sed "s|.*sev-config.*|${SEV_CONF}|" > ${FC_CONFIG}
}


setup () {
    mkdir -p ${HASHES_DIR}
    
    # check if kernel file exists
    if [ ! -f "${KERNEL}" ]; then
        echo "Bad kernel path"
        exit 1
    fi

    setup_cmdline
    hash_components
    configure_sev
    choose_firmware    
    build_vm_cfg
}

run_fc () {
    rm -rf ${FC_LOG}
    touch ${FC_LOG}

    ${FC_BUILD} --no-api\
        --config-file ${FC_CONFIG}\
        --log-path ${FC_LOG}\
        --level Info\
        --boot-timer\
        --no-seccomp
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
	POLICY=5
        ;;
    -es)
        ES="1"
	POLICY=5
        ;;
    -sev)
        SEV="1"
	POLICY=1
        ;;
    -attest)
        ATTEST="1"
        ;;
    -console)
        CONSOLE="1"
        ;;
    -mem)
        MEM_SIZE=$2
        shift
        ;;
    -fw)
        FIRMWARE_PATH=$2
        shift
        ;;
    -num)
        FC_LOG=/tmp/fc-log-$2.file
        FC_CONFIG=./fc-config/vm_config-$2.json
        shift
        ;;
    -debug)
        FC=${FC_PATH_DEBUG}
        BUILD_FLAGS=""
        ;;
    -no-net)
        NO_NET="1"
        ;;
    esac
    shift
done

setup
run_fc

