#!/usr/bin/python

from matplotlib import pyplot as plt
import matplotlib
import numpy as np
import json
import os

LUPINE_BZIMAGE_SEV_DATA="./data/boot/firecracker/bzImage-lupine-6.4-lz4-snp"
LUPINE_RUST_DIRECT_SEV_DATA="./data/boot/firecracker/vmlinux-lupine-6.4-snp"
LUPINE_DIRECT_DATA="./data/boot/firecracker/vmlinux-lupine-6.4"

AWS_BZIMAGE_SEV_DATA="./data/boot/firecracker/bzImage-aws-6.4-lz4-snp"
AWS_RUST_DIRECT_SEV_DATA="./data/boot/firecracker/vmlinux-aws-6.4-snp"
AWS_DIRECT_DATA="./data/boot/firecracker/vmlinux-aws-6.4"

UBUNTU_BZIMAGE_SEV_DATA="./data/boot/firecracker/bzImage-ubuntu-6.4-lz4-snp"
UBUNTU_RUST_DIRECT_SEV_DATA="./data/boot/firecracker/vmlinux-ubuntu-6.4-snp"
UBUNTU_DIRECT_DATA="./data/boot/firecracker/vmlinux-ubuntu-6.4"

OUTDIR="./figs/"
OUTFILE="severifast-vs-stock-fc.pdf"

def geo_mean_overflow(iterable):
    return np.exp(np.log(iterable).mean())

def parse_data(in_file, fig, ax, sev=True, firmware=True, bzImage=True, x_coord=0, micro_stats=False, hashes=True, qemu=False, overall=False, color=None, label=None, width=0.3):

    file=open(in_file)
    lines=file.readlines()

    all_times={}

    for line in lines:
        try:
            j=(json.loads(line))
            for key in j.keys():
                all_times[key] = all_times.setdefault(key, [])
                all_times[key].append(j[key])
        except:
            pass

    average_times={}
    max_times={}
    min_times={}
    
    # Average times in ms
    for key in all_times.keys():
        average_times[key] = np.average(all_times[key])/1000.0
        max_times[key] = np.max(all_times[key])/1000.0
        min_times[key] = np.min(all_times[key])/1000.0

    pre_encrypt_time=0
    fw_time=0
    bzimage_time=0
    hypervisor_time=0
    qemu_hash=0
    hash_time=0
    copy_time=0
    verify_time=0

    out_width = width
    in_width = width* 0.8

    if bzImage:
        hypervisor_time = average_times["bzimage_entry_point"]
    if firmware:
        hypervisor_time = average_times["firmware_entry_point"]
    else:
        hypervisor_time = average_times["linux_entry_point"]
    if hashes:
        hash_time = average_times["hash_time"] 
        copy_time = average_times["copy_time"] 
        
    if sev:
        pre_encrypt_time = average_times["pre_encrypt_time"]

    if qemu:
        hypervisor_time = average_times["firmware_entry_point"]
        sec_time = average_times["pei_entry_point"] - average_times["sec_entry_point"]
        pei_time = average_times["dxe_entry_point"] - average_times["pei_entry_point"]
        dxe_time = average_times["bds_entry_point"] - average_times["dxe_entry_point"]
        bds_time = average_times["bzimage_entry_point"] - average_times["bds_entry_point"]
        qemu_hash = average_times["kernel_hash_time"]
        verify_time = average_times["verify_blobs_end"] - average_times["verify_blobs_start"]

    if firmware and bzImage:
        fw_time = average_times["bzimage_entry_point"] - average_times["firmware_entry_point"]
    if firmware and not bzImage:
        fw_time = average_times["linux_entry_point"] - average_times["firmware_entry_point"]
    if bzImage:
        bzimage_time = average_times["linux_entry_point"] - average_times["bzimage_entry_point"]

    linux_time = average_times["linux_run_init"] - average_times["linux_entry_point"]

    attestation_time = 0

    data = np.std(np.array(all_times["linux_run_init"])/1000.0)

    ax.set_ylabel("Time (ms)")

    ax.bar(x_coord, linux_time,  fill=True, color="khaki", edgecolor="black", bottom=bzimage_time+fw_time+hypervisor_time, label="Linux Boot",width=out_width, yerr=data, capsize=7)
    if bzImage:
        ax.bar(x_coord, bzimage_time, fill=True, edgecolor="black", hatch="..", color="orange", bottom=fw_time+hypervisor_time, label="Bootstrap Loader", width=out_width)
    if firmware:
        ax.bar(x_coord, fw_time, fill=True, hatch="//", edgecolor="black", color="darkturquoise", bottom=hypervisor_time, label="OVMF" if qemu else "Boot Verifier",width=out_width)
        if hashes:
            ax.bar(x_coord, hash_time, fill=False, edgecolor="black", hatch="//", color="green", bottom=hypervisor_time+copy_time, label="Hash Time", width=in_width)
            ax.bar(x_coord, copy_time, color="red", bottom=hypervisor_time, label="Copy Time", width=in_width)
        if qemu: 
            ax.bar(x_coord, verify_time, color="red", bottom=average_times["verify_blobs_start"], width=0.3, label="Boot Verifier")

    ax.bar(x_coord, hypervisor_time, color="orchid", edgecolor="black", fill=True, hatch="\\\\", bottom=None, label="QEMU" if qemu else "Firecracker",width=out_width)
    if sev:
        if qemu:
            ax.bar(x_coord, qemu_hash, color="red", bottom=pre_encrypt_time, width=in_width, label="First kernel hash")
        ax.bar(x_coord, pre_encrypt_time, color="indigo", bottom=0, width=in_width, label="Pre-encryption")

def plot_all():
    fig,ax =plt.subplots(figsize=(6, 4))

    parse_data(LUPINE_BZIMAGE_SEV_DATA, fig, ax, x_coord=0.3, sev=False,firmware=True,bzImage=True, hashes=False)
    ax.legend(frameon=True, framealpha=1)
    parse_data(LUPINE_DIRECT_DATA, fig, ax, x_coord=0, sev=False,firmware=False,bzImage=False,hashes=False)
    parse_data(LUPINE_RUST_DIRECT_SEV_DATA, fig, ax, x_coord=0.6, sev=False,firmware=True,bzImage=False, hashes=False)

    parse_data(AWS_BZIMAGE_SEV_DATA, fig, ax, x_coord=1.3, sev=False,firmware=True,bzImage=True, hashes=False)
    parse_data(AWS_DIRECT_DATA, fig, ax, x_coord=1, sev=False,firmware=False,bzImage=False,hashes=False)
    parse_data(AWS_RUST_DIRECT_SEV_DATA, fig, ax, x_coord=1.6, sev=False,firmware=True,bzImage=False, hashes=False)

    parse_data(UBUNTU_BZIMAGE_SEV_DATA, fig, ax, x_coord=2.3, sev=False,firmware=True,bzImage=True, hashes=False)
    parse_data(UBUNTU_DIRECT_DATA, fig, ax, x_coord=2, sev=False,firmware=False,bzImage=False,hashes=False)
    parse_data(UBUNTU_RUST_DIRECT_SEV_DATA, fig, ax, x_coord=2.6, sev=False,firmware=True,bzImage=False, hashes=False)

    trans = ax.get_xaxis_transform()
    ax.set_ylim(0, 370)
    ax.annotate("Lupine", xy=(0.28, 0.51), xycoords=trans, ha='center')
    ax.annotate("AWS", xy=(1.28, 0.6), xycoords=trans, ha='center')
    ax.annotate("Ubuntu", xy=(2.3, 0.93), xycoords=trans, ha='center')
    plt.xticks([0, 0.3, 0.6], ["Stock Firecracker", 
        "SEVeriFast", "SEVeriFast (no compression)"], rotation=25, ha='right')
    plt.tight_layout()
    if not os.path.exists(OUTDIR):
        os.makedirs(OUTDIR)

    plt.savefig(OUTDIR + OUTFILE)
    plt.cla()

if __name__ == "__main__":
    font = {'size'   : 11}

    matplotlib.rc('font', **font)
    plot_all()

