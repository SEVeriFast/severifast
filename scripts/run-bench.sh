#!/bin/bash

NUM_RUNS=1

FC_LOG_PATH=/tmp/fc-log.file

# tracepoints
PRE_ENCRYPT_START="Pre-encryption start"
PRE_ENCRYPT_DONE="Pre-encryption done"
SEC_ENTRY_POINT="0x20"
PEI_ENTRY_POINT="0x21"
DXE_ENTRY_POINT="0x22"
BDS_ENTRY_POINT="0x23"
VERIFY_BLOBS_START="0x24"
VERIFY_BLOBS_END="0x25"
OVMF_ENTRY_POINT="0x30"
RUST_ENTRY_POINT="0x31"
BZIMAGE_ENTRY_POINT="0x39"
VMLINUX_ENTRY_POINT="0x40"
LINUX_RUN_INIT="0x41"
ATTESTATION_DONE="0x42"
COPY_START="0x50"
COPY_END="0x51"
HASH_START="0x60"
HASH_END="0x61"
INITRD_COPY_START="0x52"
INITRD_COPY_END="0x53"
INITRD_HASH_START="0x62"
INITRD_HASH_END="0x63"
INITRD_LOAD_START="0x90"
INITRD_LOAD_END="0x91"
QEMU_ES_SNP_FW_ENTRY_POINT="kvm:kvm_vmgexit_msr_protocol_enter: vcpu 0, ghcb_gpa 0020000000000014"
QEMU_ES_SNP_BZIMAGE_ENTRY_POINT="kvm:kvm_vmgexit_msr_protocol_enter: vcpu 0, ghcb_gpa 0030000000000014"
QEMU_ES_SNP_VMLINUX_ENTRY_POINT="kvm:kvm_vmgexit_msr_protocol_enter: vcpu 0, ghcb_gpa 0040000000000014"

SEV=""

convert_to_µs () {
    #milliseconds
    string=$1
    if [ "${string: -3}" == "ms:" ]; then
        string=${string:: -3}
        string=$(expr $string*1000.0 | bc)
    #microseconds
    elif [ "${string: -2}" == "µs:" ]; then
        string=${string:: -3}
    #seconds
    else
        string=${string:: -3}
        string=$(expr $string*1000.0 | bc)
        string=$(expr $string*1000.0 | bc)
    fi

    echo $string
}

convert_all_to_µs () {
    local -n arr=$1
    result=()
    for i in "${!arr[@]}";
    do
	    result=$(echo "${arr[i]}" | sed 's/^0*//')
        arr[$i]="$result"
    done
}

sum_all () {
    local -n start_times=$1
    local -n end_times=$2
    total=0
    for i in "${!start_times[@]}"; do
        start="${start_times[i]}"
        end="${end_times[i]}"
        diff=$(expr $end-$start | bc )
        total=$(expr $total+$diff| bc)
    done
    echo $total
}

setup() {
    if [ ! -f "${KERNEL}" ]; then
        echo "Bad kernel path"
        exit 1
    fi

    if [ -f "${INITRD}" ]; then
        ADD_INITRD_TO_RESULTS_PATH="-$(basename ${INITRD})"
        INITRD="-initrd ${INITRD}"
    else
        if [[ $KERNEL == *"ubuntu"* ]]; then
            INITRD="-initrd ./images/initrd-ubuntu.img"
        elif [[ $KERNEL == *"aws"* ]]; then
            INITRD="-initrd ./images/initrd-aws.img"
        elif [[ $KERNEL == *"lupine"* ]]; then
            INITRD="-initrd ./images/initrd-lupine.img"
        else
            echo "Couldn't find initrd for kernel: $KERNEL"
            exit 1
        fi
    fi


    if [ "${QEMU}" == "1" ]; then
        LOG_STR="pio_write at 0x80 size 1 count 1 val "
        TYPE="QEMU"
        mkdir -p ./data/boot/qemu
        RESULTS_PATH="./data/boot/qemu/$(basename ${KERNEL})${SEV}"
        if [ "$SEV" == "-sev" ]; then
            FIRMWARE_ENTRY_POINT=$LOG_STR$RUST_ENTRY_POINT
            BZIMAGE_ENTRY_POINT=$LOG_STR$BZIMAGE_ENTRY_POINT
            VMLINUX_ENTRY_POINT=$LOG_STR$VMLINUX_ENTRY_POINT
        elif [[ "$SEV" == "-es" || "$SEV" == "-snp" ]]; then
            FIRMWARE_ENTRY_POINT=$QEMU_ES_SNP_FW_ENTRY_POINT
            BZIMAGE_ENTRY_POINT=$QEMU_ES_SNP_BZIMAGE_ENTRY_POINT
            VMLINUX_ENTRY_POINT=$QEMU_ES_SNP_VMLINUX_ENTRY_POINT
        fi
        QEMU_RUN="./scripts/run-qemu.sh -attest -kernel ${KERNEL} ${INITRD} ${SEV}"
    elif [ "${FC}" == "1" ]; then
        TYPE="Firecracker"
        mkdir -p ./data/boot/firecracker
        RESULTS_PATH="./data/boot/firecracker/$(basename ${KERNEL})${SEV}${ADD_INITRD_TO_RESULTS_PATH}"
        FIRMWARE_ENTRY_POINT=${RUST_ENTRY_POINT}
        FC_RUN="./scripts/run-fc.sh -kernel ${KERNEL} ${INITRD} ${SEV} -attest"
    else
        echo "Invalid VMM type"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $NUM_RUNS =~ $re ]] ; then
        echo "Invalid number of runs: $NUM_RUNS"
        exit 1
    fi

    if ! [[ $VM_NUM =~ $re ]] && [ "x$VM_NUM" != "x" ] ; then
        echo "Invalid VM number: $VM_NUM"
        exit 1
    fi

    if [ "x$VM_NUM" != "x" ]; then
        FC_LOG_PATH="/tmp/fc-log-$VM_NUM.file"
    fi

    if ! [[ $MEM_SIZE =~ $re ]] && [ "x$MEM_SIZE" != "x" ] ; then
        echo "Invalid mem size: $MEM_SIZE"
        exit 1
    fi
}

perf_bench_qemu () {
    PERF_DATA=/tmp/perf.data
    PERF_LOG=/tmp/perf.log
    PERF="./bin/perf"

    sudo rm -rf ${PERF_DATA}
    sudo rm -rf ${PERF_LOG}

    sudo touch ${PERF_DATA}
    sudo touch ${PERF_LOG}

    sudo ${PERF} record -a -e kvm:kvm_vmgexit_msr_protocol_enter -e kvm:kvm_pio -e sched:sched_process_exec -o ${PERF_DATA} > /dev/null 2>&1  &

    PERF_PID=$! 2>&1 > /dev/null 
    sleep 1

    # run qemu
    ${QEMU_RUN} 2>&1 > /dev/null
    
    sudo pkill perf 2>&1 > /dev/null 
    wait ${PERF_PID}
    sudo ${PERF} script -i ${PERF_DATA} | sudo tee ${PERF_LOG} > /dev/null
}

parse_results_fc () {
    #parse firecracker log
    if ! [[ "${SEV}" == "" ]]; then
        hash_start=($(grep "${HASH_START}" ${FC_LOG_PATH} | awk '{print $7}' ))
        hash_end=($(grep "${HASH_END}" ${FC_LOG_PATH} | awk '{print $7}' ))

        copy_start=($(grep "${COPY_START}" ${FC_LOG_PATH} | awk '{print $7}' ))
        copy_end=($(grep "${COPY_END}" ${FC_LOG_PATH} | awk '{print $7}' ))

        initrd_hash_start=($(grep "${INITRD_HASH_START}" ${FC_LOG_PATH} | awk '{print $7}' ))
        initrd_hash_end=($(grep "${INITRD_HASH_END}" ${FC_LOG_PATH} | awk '{print $7}' ))

        initrd_copy_start=($(grep "${INITRD_COPY_START}" ${FC_LOG_PATH} | awk '{print $7}' ))
        initrd_copy_end=($(grep "${INITRD_COPY_END}" ${FC_LOG_PATH} | awk '{print $7}' ))

        initrd_unpack_start=($(grep "${INITRD_LOAD_START}" ${FC_LOG_PATH} | awk '{print $7}' ))
        initrd_unpack_done=($(grep "${INITRD_LOAD_END}" ${FC_LOG_PATH} | awk '{print $7}' ))

        pre_encrypt_start=($(grep "${PRE_ENCRYPT_START}" ${FC_LOG_PATH} | awk '{print $5}' ))
        pre_encrypt_done=($(grep "${PRE_ENCRYPT_DONE}" ${FC_LOG_PATH} | awk '{print $5}' ))

        firmware_entry_point=$(grep "${FIRMWARE_ENTRY_POINT}" ${FC_LOG_PATH} | awk '{print $7}' )

        if [[ "${KERNEL}" == *"bzImage"* ]]; then
            bzimage_entry_point=$(grep "${BZIMAGE_ENTRY_POINT}" ${FC_LOG_PATH} | awk '{print $7}' )
        fi

    fi
    linux_entry_point=$(grep "${VMLINUX_ENTRY_POINT}" ${FC_LOG_PATH} | awk '{print $7}' )
    linux_run_init=$(grep "${LINUX_RUN_INIT}" ${FC_LOG_PATH} | awk '{print $7}' )
    attestation_done=$(grep "${ATTESTATION_DONE}" ${FC_LOG_PATH} | awk '{print $7}' )

    #convert time strings to us
    if ! [[ "${SEV}" == "" ]]; then

        convert_all_to_µs hash_start
        convert_all_to_µs hash_end

        convert_all_to_µs copy_start
        convert_all_to_µs copy_end

        convert_all_to_µs initrd_hash_start
        convert_all_to_µs initrd_hash_end

        convert_all_to_µs initrd_copy_start
        convert_all_to_µs initrd_copy_end

        hash_time=$(sum_all hash_start hash_end)
        copy_time=$(sum_all copy_start copy_end)
        initrd_hash_time=$(sum_all initrd_hash_start initrd_hash_end)
        initrd_copy_time=$(sum_all initrd_copy_start initrd_copy_end)

        convert_all_to_µs pre_encrypt_start
        convert_all_to_µs pre_encrypt_done
        pre_encrypt_time=$(sum_all pre_encrypt_start pre_encrypt_done)

        firmware_entry_point=$(echo $firmware_entry_point | sed 's/^0*//')
        if [[ "${KERNEL}" == *"bzImage"* ]]; then
            bzimage_entry_point=$(echo $bzimage_entry_point | sed 's/^0*//')
        fi
    fi

    linux_entry_point=$(echo $linux_entry_point | sed 's/^0*//')
    linux_run_init=$(echo $linux_run_init | sed 's/^0*//')
    attestation_done=$(echo $attestation_done | sed 's/^0*//')

    initrd_unpack_start=$(echo $initrd_unpack_start | sed 's/^0*//')
    initrd_unpack_done=$(echo $initrd_unpack_done | sed 's/^0*//')

    if [ "x${initrd_unpack_done}" == "x" ]; then
        initrd_unpack_done="0"
    fi


    if ! [[ "${SEV}" == "-snp" ]]; then
        attestation_done=$linux_run_init
    fi

    if ! [[ "$KERNEL" == *"lupine"* ]]; then
        ATTESTATION=", \"attestation_done\" : ${attestation_done}"
    fi
        

    if ! [[ "${SEV}" == "" ]]; then
        if [[ "${KERNEL}" == *"bzImage"* ]]; then
            echo "{\"copy_time\" : ${copy_time}, \"hash_time\" : ${hash_time}, \"initrd_copy_time\" : ${initrd_copy_time}, \"initrd_hash_time\" : ${initrd_hash_time}, \"pre_encrypt_time\" : ${pre_encrypt_time}, \"firmware_entry_point\" : ${firmware_entry_point}, \"bzimage_entry_point\" : ${bzimage_entry_point}, \"linux_entry_point\" : ${linux_entry_point}, \"initrd_unpack_start\" : ${initrd_unpack_start}, \"initrd_unpack_done\" : ${initrd_unpack_done}, \"linux_run_init\" : ${linux_run_init}${ATTESTATION}}" >> ${RESULTS_PATH}
        elif [[ "${KERNEL}" == *"vmlinux"* ]]; then
            echo "{\"copy_time\" : ${copy_time}, \"hash_time\" : ${hash_time}, \"initrd_copy_time\" : ${initrd_copy_time}, \"initrd_hash_time\" : ${initrd_hash_time},\"pre_encrypt_time\" : ${pre_encrypt_time}, \"firmware_entry_point\" : ${firmware_entry_point}, \"linux_entry_point\" : ${linux_entry_point}, \"initrd_unpack_start\" : ${initrd_unpack_start}, \"initrd_unpack_done\" : ${initrd_unpack_done}, \"linux_run_init\" : ${linux_run_init}${ATTESTATION}}" >> ${RESULTS_PATH}
        fi
    else
        echo "{\"linux_entry_point\" : ${linux_entry_point}, \"linux_run_init\" : ${linux_run_init}}" >> ${RESULTS_PATH}
    fi
}

parse_results_qemu () {
    sleep 1
    QEMU_LOG=/tmp/qemu.log
    PERF_LOG=/tmp/perf.log

    EXEC_STR="sched:sched_process_exec: filename=${QEMU_BUILD}"
    
    if [ "${SEV}" == "-snp" ]; then
        PRE_ENC_TRACE_START="kvm_sev_snp_measure_regions_start"
        PRE_ENC_TRACE_DONE="kvm_sev_snp_measure_regions_done"
    else
        PRE_ENC_TRACE_START="kvm_sev_launch_update_data"
        PRE_ENC_TRACE_DONE="kvm_sev_launch_update_data"
    fi

    KERNEL_HASH_TRACE_START="kvm_sev_hash_kernel_start"
    KERNEL_HASH_TRACE_DONE="kvm_sev_hash_kernel_done"

    INITRD_HASH_TRACE_START="kvm_sev_hash_initrd_start"
    INITRD_HASH_TRACE_DONE="kvm_sev_hash_initrd_done"

    qemu_run=$(grep "${EXEC_STR}" ${PERF_LOG} | awk '{print $4}' ) 

    firmware_entry_point=$(grep "${FIRMWARE_ENTRY_POINT}" ${PERF_LOG} | awk '{print $4}' )
    firmware_entry_point=${firmware_entry_point::-1}s

    sec_entry_point=$(grep "${LOG_STR}${SEC_ENTRY_POINT}" ${PERF_LOG} | awk '{print $4}' )
    pei_entry_point=$(grep "${LOG_STR}${PEI_ENTRY_POINT}" ${PERF_LOG} | awk '{print $4}' )
    dxe_entry_point=$(grep "${LOG_STR}${DXE_ENTRY_POINT}" ${PERF_LOG} | awk '{print $4}' )
    bds_entry_point=$(grep "${LOG_STR}${BDS_ENTRY_POINT}" ${PERF_LOG} | awk '{print $4}' )
    verify_blobs_start=$(grep "${LOG_STR}${VERIFY_BLOBS_START}" ${PERF_LOG} | awk '{print $4}' )
    verify_blobs_end=$(grep "${LOG_STR}${VERIFY_BLOBS_END}" ${PERF_LOG} | awk '{print $4}' )

    bzimage_entry_point=$(grep "${BZIMAGE_ENTRY_POINT}" ${PERF_LOG} | awk '{print $4}' )
    bzimage_entry_point=${bzimage_entry_point::-1}s
    linux_entry_point=$(grep "${VMLINUX_ENTRY_POINT}" ${PERF_LOG} | awk '{print $4}' )
    linux_entry_point=${linux_entry_point::-1}s
    linux_run_init=$(grep "${LOG_STR}${LINUX_RUN_INIT}" ${PERF_LOG} | awk '{print $4}' )
    linux_run_init=${linux_run_init::-1}s

    attestation_done=$(grep "${LOG_STR}${ATTESTATION_DONE}" ${PERF_LOG} | awk '{print $4}' )

    if [ "x$attestation_done" == "x" ]; then
	    attestation_done=$linux_run_init
    fi

    attestation_done=${attestation_done::-1}s

    pre_encrypt_start=$(grep -m 1 "${PRE_ENC_TRACE_START}" ${QEMU_LOG} | cut -d ':' -f 1 | cut  --complement -d '@' -f 1 | awk '{print $1}' )s
    pre_encrypt_done=$(grep -m 2 "${PRE_ENC_TRACE_DONE}" ${QEMU_LOG} | cut -d ':' -f 1 | tail -n 1 |  cut  --complement -d '@' -f 1 | awk '{print $1}' )s

    kernel_hash_start=$(grep "${KERNEL_HASH_TRACE_START}" ${QEMU_LOG} | cut -d ':' -f 1 | tail -n 1 |  cut  --complement -d '@' -f 1 | awk '{print $1}' )s
    kernel_hash_done=$(grep "${KERNEL_HASH_TRACE_DONE}" ${QEMU_LOG} | cut -d ':' -f 1 | tail -n 1 |  cut  --complement -d '@' -f 1 | awk '{print $1}' )s

    initrd_hash_start=$(grep -m 1 "${INITRD_HASH_TRACE_START}" ${QEMU_LOG} | cut -d ':' -f 1 | tail -n 1 |  cut  --complement -d '@' -f 1 | awk '{print $1}' )s
    initrd_hash_done=$(grep -m 2 "${INITRD_HASH_TRACE_DONE}" ${QEMU_LOG} | cut -d ':' -f 1 | tail -n 1 |  cut  --complement -d '@' -f 1 | awk '{print $1}' )s


    qemu_run=$(convert_to_µs $qemu_run)

    firmware_entry_point=$(convert_to_µs $firmware_entry_point)
    
    sec_entry_point=$(convert_to_µs $sec_entry_point)
    pei_entry_point=$(convert_to_µs $pei_entry_point)
    dxe_entry_point=$(convert_to_µs $dxe_entry_point)
    bds_entry_point=$(convert_to_µs $bds_entry_point)
    
    verify_blobs_start=$(convert_to_µs $verify_blobs_start)
    verify_blobs_end=$(convert_to_µs $verify_blobs_end)
    bzimage_entry_point=$(convert_to_µs $bzimage_entry_point)

    linux_entry_point=$(convert_to_µs $linux_entry_point)
    linux_run_init=$(convert_to_µs $linux_run_init)
    attestation_done=$(convert_to_µs $attestation_done)

    pre_encrypt_start=$(convert_to_µs $pre_encrypt_start)

    pre_encrypt_done=$(convert_to_µs $pre_encrypt_done)
    kernel_hash_start=$(convert_to_µs $kernel_hash_start)
    kernel_hash_done=$(convert_to_µs $kernel_hash_done)

    initrd_hash_start=$(convert_to_µs $initrd_hash_start)
    initrd_hash_done=$(convert_to_µs $initrd_hash_done)

    firmware_entry_point=$(expr $firmware_entry_point-$qemu_run | bc)
    sec_entry_point=$(expr $sec_entry_point-$qemu_run | bc)
    pei_entry_point=$(expr $pei_entry_point-$qemu_run | bc)
    dxe_entry_point=$(expr $dxe_entry_point-$qemu_run | bc)
    bds_entry_point=$(expr $bds_entry_point-$qemu_run | bc)
    verify_blobs_start=$(expr $verify_blobs_start-$qemu_run | bc)
    verify_blobs_end=$(expr $verify_blobs_end-$qemu_run | bc)
    bzimage_entry_point=$(expr $bzimage_entry_point-$qemu_run | bc)
    linux_entry_point=$(expr $linux_entry_point-$qemu_run | bc)
    linux_run_init=$(expr $linux_run_init-$qemu_run | bc)
    attestation_done=$(expr $attestation_done-$qemu_run | bc)
    pre_encrypt_time=$(expr $pre_encrypt_done-$pre_encrypt_start | bc)
    kernel_hash_time=$(expr $kernel_hash_done-$kernel_hash_start | bc)
    initrd_hash_time=$(expr $initrd_hash_done-$initrd_hash_start | bc)

    if [ "${SEV}" == "-snp" ]; then
        echo "{\"pre_encrypt_time\" : ${pre_encrypt_time}, \"kernel_hash_time\" : ${kernel_hash_time}, \"initrd_hash_time\" : ${initrd_hash_time}, \"firmware_entry_point\" : ${firmware_entry_point}, \"sec_entry_point\" : ${sec_entry_point}, \"pei_entry_point\" : ${pei_entry_point}, \"dxe_entry_point\" : ${dxe_entry_point}, \"bds_entry_point\" : ${bds_entry_point}, \"verify_blobs_start\" : ${verify_blobs_start}, \"verify_blobs_end\" : ${verify_blobs_end}, \"bzimage_entry_point\" : ${bzimage_entry_point}, \"linux_entry_point\" : ${linux_entry_point}, \"linux_run_init\" : ${linux_run_init}, \"attestation_done\" : ${attestation_done}}" >> ${RESULTS_PATH}
    else
        echo "{\"pre_encrypt_time\" : ${pre_encrypt_time}, \"kernel_hash_time\" : ${kernel_hash_time}, \"initrd_hash_time\" : ${initrd_hash_time}, \"firmware_entry_point\" : ${firmware_entry_point}, \"sec_entry_point\" : ${sec_entry_point}, \"pei_entry_point\" : ${pei_entry_point}, \"dxe_entry_point\" : ${dxe_entry_point}, \"bds_entry_point\" : ${bds_entry_point}, \"verify_blobs_start\" : ${verify_blobs_start}, \"verify_blobs_end\" : ${verify_blobs_end}, \"bzimage_entry_point\" : ${bzimage_entry_point}, \"linux_entry_point\" : ${linux_entry_point}, \"linux_run_init\" : ${linux_run_init}}" >> ${RESULTS_PATH}
    fi
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
        SEV=$1
        ;;
    -es)
        SEV=$1
        ;;
    -sev)
        SEV=$1
        ;;
    -qemu)
        QEMU="1"
        ;;
    -fc)
        FC="1"
        ;;
    -vm-num)
        VM_NUM=$2
        shift
        ;;
    -mem)
        MEM_SIZE=$2
        shift
        ;;
    -num-runs)
        NUM_RUNS=$2
        shift
        ;;
    esac
    shift
done

setup

# warm up
echo -n "Warming cache..."
if [ "${QEMU}" == "1" ]; then
    for ((n = 0 ; n < 5 ; n++ )); do
	perf_bench_qemu
    done
elif [ "${FC}" == "1" ]; then
    for ((n = 0 ; n < 5 ; n++ )); do
	$FC_RUN > /dev/null 2>&1
    done
else
    echo "Error warming buffer cache"
    exit 1
fi
echo ""

# Run experiment
for ((n = 1 ; n <= ${NUM_RUNS} ; n++ )); do
    echo -n "Booting $(basename ${KERNEL}) with ${TYPE} and ${SEV:1}: ${n}/${NUM_RUNS}"
    echo -ne '\r'
    if [ "${QEMU}" == "1" ]; then
        perf_bench_qemu
        parse_results_qemu
    elif [ "${FC}" == "1" ]; then
        $FC_RUN > /dev/null 2>&1 
        parse_results_fc
    else
        echo "Invalid VMM type"
        exit 1
    fi
done
echo ""
