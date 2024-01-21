#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
. ${SCRIPT_DIR}/common

SIZES=("4096" "8128" "16384" "32768" "65536" "131072" "262144" "524288" "1048576" "2097152" "4194304" "8388608" "16777216" "33554432")
num_runs=100

SRC=(/dev/urandom)
RESULTS=${ROOT_DIR}/data/pre-encrypt/

rm -rf $RESULTS

mkdir -p ${RESULTS}

make -C ${ROOT_DIR}/toy-vmm

for size in ${SIZES[@]}; do
    RESULTS_PATH=${RESULTS}/${size}.dat
    counter=1
    until [ $counter -gt $num_runs ]
    do
        echo -n "Benchmarking pre-encryption with SEV-SNP for region size ${size}B ${counter}/${num_runs}" 
        echo -ne "\r"
        ((counter++))
        echo $(${ROOT_DIR}/toy-vmm/toy-vmm $size) >> ${RESULTS_PATH}            
    done

    echo ""
done

