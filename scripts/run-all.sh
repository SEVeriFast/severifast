#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f $0))
. ${SCRIPT_DIR}/common

NUM_RUNS=100

LUPINE_KERNEL=${ROOT_DIR}/kernels/bzImage-lupine-6.4-lz4
LUPINE_VMLINUX=${ROOT_DIR}/kernels/vmlinux-lupine-6.4
LUPINE_KERNEL_GZIP=${ROOT_DIR}/kernels/bzImage-lupine-6.4-gzip
LUPINE_INITRD=${ROOT_DIR}/images/initrd-lupine.img
LUPINE_INITRD_LZ4=${ROOT_DIR}/images/initrd-lupine-lz4.img
LUPINE_INITRD_GZIP=${ROOT_DIR}/images/initrd-lupine-gzip.img

AWS_KERNEL=${ROOT_DIR}/kernels/bzImage-aws-6.4-lz4
AWS_VMLINUX=${ROOT_DIR}/kernels/vmlinux-aws-6.4
AWS_KERNEL_GZIP=${ROOT_DIR}/kernels/bzImage-aws-6.4-gzip
AWS_INITRD=${ROOT_DIR}/images/initrd-aws.img
AWS_INITRD_LZ4=${ROOT_DIR}/images/initrd-aws-lz4.img
AWS_INITRD_GZIP=${ROOT_DIR}/images/initrd-aws-gzip.img

UBUNTU_KERNEL=${ROOT_DIR}/kernels/bzImage-ubuntu-6.4-lz4
UBUNTU_VMLINUX=${ROOT_DIR}/kernels/vmlinux-ubuntu-6.4
UBUNTU_KERNEL_GZIP=${ROOT_DIR}/kernels/bzImage-ubuntu-6.4-gzip
UBUNTU_INITRD=${ROOT_DIR}/images/initrd-ubuntu.img
UBUNTU_INITRD_LZ4=${ROOT_DIR}/images/initrd-ubuntu-lz4.img
UBUNTU_INITRD_GZIP=${ROOT_DIR}/images/initrd-ubuntu-gzip.img

MEM=256

rm -rf ${ROOT_DIR}/data/boot/firecracker
rm -rf ${ROOT_DIR}/data/boot/qemu
rm -rf ${ROOT_DIR}/hashes

echo "########## Stock Firecracker ##########"
${SCRIPT_DIR}/run-bench.sh -fc -mem $MEM -num-runs ${NUM_RUNS} -kernel ${LUPINE_VMLINUX}
${SCRIPT_DIR}/run-bench.sh -fc -mem $MEM -num-runs ${NUM_RUNS} -kernel ${AWS_VMLINUX}
${SCRIPT_DIR}/run-bench.sh -fc -mem $MEM -num-runs ${NUM_RUNS} -kernel ${UBUNTU_VMLINUX}

echo "########## Firecracker w/ SEV-SNP ##########"

# these run with uncompressed initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${LUPINE_KERNEL}
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${LUPINE_VMLINUX}
# run with gzip kernel/initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${LUPINE_KERNEL_GZIP} -initrd ${LUPINE_INITRD_GZIP}
# run with lz4 initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${LUPINE_KERNEL} -initrd ${LUPINE_INITRD_LZ4}

# these run with uncompressed initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${AWS_KERNEL}
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${AWS_VMLINUX}
# run with gzip kernel/initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${AWS_KERNEL_GZIP} -initrd ${AWS_INITRD_GZIP}
# run with lz4 initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${AWS_KERNEL} -initrd ${AWS_INITRD_LZ4}

# these run with uncompressed initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${UBUNTU_KERNEL}
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${UBUNTU_VMLINUX}
# run with gzip kernel/initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${UBUNTU_KERNEL_GZIP} -initrd ${UBUNTU_INITRD_GZIP}
# run with lz4 initrd
${SCRIPT_DIR}/run-bench.sh -fc -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${UBUNTU_KERNEL} -initrd ${UBUNTU_INITRD_LZ4}

echo "########## QEMU w/ SEV-SNP ##########"
${SCRIPT_DIR}/run-bench.sh -qemu -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${LUPINE_KERNEL}
${SCRIPT_DIR}/run-bench.sh -qemu -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${AWS_KERNEL}
${SCRIPT_DIR}/run-bench.sh -qemu -mem 256 -num-runs ${NUM_RUNS} -snp -kernel ${UBUNTU_KERNEL}

echo "########## Pre-encryption ###########"
${SCRIPT_DIR}/run-pre-enc.sh

echo "########## Concurrent boot ##########"
${SCRIPT_DIR}/run-bench-concurrent.sh

echo "Generating figs"

${SCRIPT_DIR}/plot-pre-encrypt.py
${SCRIPT_DIR}/plot-ovmf-breakdown.py
${SCRIPT_DIR}/plot-copy-and-hash.py
${SCRIPT_DIR}/plot-severifast-vs-qemu.py
${SCRIPT_DIR}/plot-severifast-vs-stock-fc.py
${SCRIPT_DIR}/plot-concurrent-boot.py

echo "Done"
