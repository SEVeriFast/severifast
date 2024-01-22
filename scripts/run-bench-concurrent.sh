#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
. ${SCRIPT_DIR}/common

PERF=${BIN_DIR}/perf
PERF_DATA=/tmp/perf.data
PERF_LOG=/tmp/perf.log

start_perf() {
    sudo rm -rf ${PERF_DATA}
    sudo rm -rf ${PERF_LOG}

    sudo touch ${PERF_DATA}
    sudo touch ${PERF_LOG}

    sudo ${PERF} record -a -e kvm:kvm_vmgexit_msr_protocol_enter -e kvm:kvm_pio -e sched:sched_process_exec -e sched:sched_process_fork -o ${PERF_DATA} > /dev/null 2>&1  &

    PERF_PID=$! > /dev/null 2>&1 
    sleep 1
}

stop_perf() {
    sudo kill ${PERF_PID} > /dev/null 2>&1
    wait ${PERF_PID}
    sudo ${PERF} script -i ${PERF_DATA} | sudo tee ${PERF_LOG} > /dev/null
}

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

run_qemu() {

    SEV=$1
    NUM_VMS=$2

    QEMU_PIDS=()

    if [ "$SEV" == "1" ]; then
        rm -rf ./data/boot/concurrent/qemu/snp-$NUM_VMS.dat
	SNP="with SEV-SNP"
    else
        rm -rf ./data/boot/concurrent/qemu/stock-$NUM_VMS.dat
    fi

    echo "Warming cache..."
    for ((i = 0; i < 5; i++)); do
	if [ "$SEV" == "1" ]; then
            ./scripts/run-qemu.sh -no-net -kernel ./kernels/bzImage-aws-6.4-lz4 -initrd ./images/initrd-aws-no-net.img -snp -vm-num ${VMS} 2>&1 > /dev/null
        else
            ./scripts/run-qemu.sh -no-net -kernel ./kernels/bzImage-aws-6.4-lz4 -initrd ./images/initrd-aws-no-net.img -vm-num ${VMS} 2>&1 > /dev/null
        fi
    done
    echo "Done warming cache"

    rm -rf /tmp/qemu.pids

    echo -ne '\r'    
    echo "QEMU: spawning ${NUM_VMS} VMs ${SNP}"
    echo -ne '\r'

    start_perf

    VMS=0
    until [ $VMS -eq $NUM_VMS ]
    do
        if [ "$SEV" == "1" ]; then
            ./scripts/run-qemu.sh -no-net -kernel ./kernels/bzImage-aws-6.4-lz4 -initrd ./images/initrd-aws-no-net.img -snp -vm-num ${VMS} >> /tmp/qemu.pids &
        else
            ./scripts/run-qemu.sh -no-net -kernel ./kernels/bzImage-aws-6.4-lz4 -initrd ./images/initrd-aws-no-net.img -vm-num ${VMS} >> /tmp/qemu.pids &
        fi

        pids[${VMS}]=$!
        ((VMS++))
    done
    echo -ne '\r'

    echo "Waiting for ${NUM_VMS} VMs"

    echo -ne "\r"

    for pid in ${pids[*]}; do
        wait $pid
    done

    echo "All VMs completed"
    echo -ne "\r"

    stop_perf

    all_times=0
    while read pid; do
        exec=$(grep $pid $PERF_LOG | grep "sched_process_exec" | awk '{print $4}' )
        exec=${exec::-1}s
        exec=$(convert_to_µs $exec)

        fork=$(grep "qemu-system-x86 $pid" $PERF_LOG | grep -m 2 "sched_process_fork" | tail -n 1)
        kvm_pid=$(echo $fork | awk '{print $9}')
        kvm_pid=${kvm_pid:10}

        if [ "$SEV" == "1" ]; then
            linux_run_init=$(grep "write at 0x80 size 1 count 1 val 0x41" ${PERF_LOG} | grep $kvm_pid | awk '{print $4}')
        else
            linux_run_init=$(grep "write at 0x80 size 1 count 1 val 0x41" ${PERF_LOG} | grep $kvm_pid | awk '{print $4}')
        fi

        linux_run_init=${linux_run_init::-1}s
        linux_run_init=$(convert_to_µs $linux_run_init)

        boot_time=$(expr $linux_run_init-$exec | bc)
        if [ "$SEV" == "1" ]; then
            echo $boot_time >> ./data/boot/concurrent/qemu/snp-$NUM_VMS.dat
        else
            echo $boot_time >> ./data/boot/concurrent/qemu/stock-$NUM_VMS.dat
        fi
    done < /tmp/qemu.pids

}

run_fc() {

    SEV=$1

    NUM_VMS=$2

    cp ./bin/snp-fw.bin /tmp/tmp-fw.bin

    VMS=0
    if [ "$SEV" == "1" ]; then
	SNP="with SEV-SNP"
    else
	SNP=""
    fi
    # boot 50 vms at once
    echo -ne '\r'

    # warm cache
    echo "Warming cache..."
    for ((i = 0 ; i < 5 ; i++ )); do
	if [ "$SEV" == "1" ]; then
            ./scripts/run-fc.sh -fw /tmp/tmp-fw.bin -no-net -snp -kernel ./kernels/bzImage-aws-6.4-lz4 -initrd ./images/initrd-aws-no-net.img -mem 256  2>&1 > /dev/null
	else
            ./scripts/run-fc.sh -no-net -kernel ./kernels/vmlinux-aws-6.4 -mem 256  2>&1 > /dev/null
	fi
    done
    
    echo -ne '\r'
    echo "Done warming cache"
    echo -ne '\r'

    echo "Firecracker: spawning ${NUM_VMS} VMs $SNP"
    until [ $VMS -eq ${NUM_VMS} ]
    do 
        if [ "$SEV" == "1" ]; then
            ./scripts/run-fc.sh -fw /tmp/tmp-fw.bin -no-net -snp -kernel ./kernels/bzImage-aws-6.4-lz4 -initrd ./images/initrd-aws-no-net.img -mem 256 -num ${VMS} 2>&1 > /dev/null  &
        else
            ./scripts/run-fc.sh -no-net -kernel  ./kernels/vmlinux-aws-6.4 -mem 256 -num ${VMS} 2>&1 > /dev/null  &
        fi
        ((VMS++))
    done

    echo -ne '\r'

    echo "Waiting for ${NUM_VMS} VMs"
    wait $(jobs -p)

    VMS=0
    all_times=0
    until [ $VMS -eq ${NUM_VMS} ]
    do
        if [ "$SEV" == "1" ]; then
            boot_time=$(grep "Debug code 0x41" /tmp/fc-log-${VMS}.file | awk '{print $7}' | sed 's/^0*//') 
        else
            boot_time=$(grep "Debug code 0x41" /tmp/fc-log-${VMS}.file | awk '{print $7}' | sed 's/^0*//') 
        fi
	
        # just echoing every VMs boot time
        if [ "$SEV" == "1" ]; then
            echo $boot_time >> ./data/boot/concurrent/firecracker/snp-${NUM_VMS}.dat
        else
            echo $boot_time >> ./data/boot/concurrent/firecracker/stock-${NUM_VMS}.dat
        fi

        rm -rf /tmp/fc-log-${VMS}.file
        ((VMS++))
    done
}

rm -rf ./data/boot/concurrent/qemu/*
rm -rf ./data/boot/concurrent/firecracker/*

mkdir -p ./data/boot/concurrent
mkdir -p ./data/boot/concurrent/qemu
mkdir -p ./data/boot/concurrent/firecracker

MAX_VMS=50

ACC=1
until [ $ACC -gt $MAX_VMS ]
do
    run_qemu 0 ${ACC}
    ((ACC++))
done

ACC=1
until [ $ACC -gt $MAX_VMS ]
do
    run_qemu 1 ${ACC}
    ((ACC++))
done

ACC=1
until [ $ACC -gt $MAX_VMS ]
do
   run_fc 0 ${ACC}
   ((ACC++))
done

ACC=1
until [ $ACC -gt $MAX_VMS ]
do
    run_fc 1 ${ACC}
    ((ACC++))
done
