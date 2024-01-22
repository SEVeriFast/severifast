#!/usr/bin/python

from matplotlib import pyplot as plt
import matplotlib
import numpy as np
import json
from matplotlib.patches import Patch
import os

# only using one kernel for OVMF because its so slow
LUPINE_OVMF_DATA="./data/boot/qemu/bzImage-ubuntu-6.4-lz4-snp"
OUTDIR="./figs/"
OUTFILE="ovmf-breakdown.pdf"

def parse_data(in_file, fig, ax, sev=True, firmware=True, bzImage=True, x_coord=0, micro_stats=False, hashes=True, qemu=False):

    file=open(in_file)
    lines=file.readlines()

    all_times={}

    for line in lines:
        j=(json.loads(line))
        for key in j.keys():
            all_times[key] = all_times.setdefault(key, [])
            all_times[key].append(j[key])
    
    average_times={}
    
    # Average times in ms
    for key in all_times.keys():
        average_times[key] = np.average(all_times[key])/1000.0

    pre_encrypt_time=0
    fw_time=0
    bzimage_time=0
    hypervisor_time=0
    hash_time=0
    copy_time=0
    verify_time=0

    if bzImage:
        hypervisor_time = average_times["bzimage_entry_point"]
    if firmware:
        hypervisor_time = average_times["firmware_entry_point"]
    if hashes:
        hash_time = average_times["hash_time"] 
        copy_time = average_times["copy_time"] 
    else:
        hypervisor_time = average_times["linux_entry_point"]

    if sev:
        pre_encrypt_time = average_times["pre_encrypt_time"]

    if qemu:
        sec_time = average_times["pei_entry_point"] - average_times["sec_entry_point"]
        pei_time = average_times["dxe_entry_point"] - average_times["pei_entry_point"]
        dxe_time = average_times["bds_entry_point"] - average_times["dxe_entry_point"]
        bds_time = average_times["bzimage_entry_point"] - average_times["bds_entry_point"]
        verify_time = average_times["verify_blobs_end"] - average_times["verify_blobs_start"]

    if firmware and bzImage:
        fw_time = average_times["bzimage_entry_point"] - average_times["firmware_entry_point"]
    if firmware and not bzImage:
        fw_time = average_times["linux_entry_point"] - average_times["firmware_entry_point"]
    if bzImage:
        bzimage_time = average_times["linux_entry_point"] - average_times["bzimage_entry_point"]

    linux_time = average_times["linux_run_init"] - average_times["linux_entry_point"]

    ax.set_ylabel("Time (ms)")

    hypervisor_time = average_times["firmware_entry_point"]

    ax.barh(x_coord, linux_time, fill=True, color="khaki", edgecolor="black",  left=bzimage_time+fw_time, label="Linux Kernel",height=0.4)
    if bzImage:
        ax.barh(x_coord, bzimage_time, fill=True, hatch="..", edgecolor="black", color="orange", left=fw_time, label="bzImage Bootloader", height=0.4)
    if firmware:
        ax.barh(x_coord, fw_time, linewidth =1, color="lightblue", hatch="oo", edgecolor="black", fill=True, left=0, label="OVMF" if qemu else "microSEV-FW", height=0.4)
        if hashes:
            ax.bar(x_coord, copy_time, color="red", bottom=hypervisor_time, label="Copy Time", width=0.3)
            ax.bar(x_coord, hash_time, color="green", bottom=hypervisor_time+copy_time, label="Hash Time", width=0.3)
        if qemu: 
            ax.barh(x_coord,  bds_time, color="wheat", fill=True, edgecolor="black", hatch="xx", left=average_times["bds_entry_point"] - hypervisor_time, label="UEFI related bootstrap", height=0.3)
            ax.barh(x_coord,  dxe_time, color="wheat", fill=True, edgecolor="black",  hatch="\|\|", left=average_times["dxe_entry_point"] - hypervisor_time, height=0.3)
            ax.barh(x_coord,  pei_time, color="wheat", edgecolor="black", fill=True, hatch="\\\\", left=average_times["pei_entry_point"] - hypervisor_time, height=0.3)
            ax.barh(x_coord,  sec_time, color="wheat",edgecolor="black", fill=True,  hatch="//", left=average_times["sec_entry_point"] - hypervisor_time, height=0.3)
            ax.barh(x_coord, verify_time, color="mediumseagreen", edgecolor="black", hatch="**", fill=True, left=average_times["verify_blobs_start"] - hypervisor_time, height=0.3, label="Boot Verifier")

if __name__ == "__main__":
    fig,ax =plt.subplots()

    parse_data(LUPINE_OVMF_DATA, fig, ax, bzImage=True, qemu=True, sev=True, hashes=False)

    ax.get_yaxis().set_visible(False)
    ax.set_ylim(-0.25, 0.25)
    ax.set_xlim(0, 5500)
    ax.set_xlabel("Time (ms)")
    fig.set_size_inches(6.4, 2.3)

    legend = [ 
        Patch(edgecolor="black", facecolor="khaki", label="Linux Kernel"),
        Patch(edgecolor="black", facecolor="orange", label="bzImage bootloader"),
        Patch(edgecolor="black", facecolor="lightblue", label="OVMF", hatch="ooo"),
        Patch(edgecolor="black", facecolor="wheat", label="SEC Phase", hatch="////"),
        Patch(edgecolor="black", facecolor="wheat", label="PEI Phase", hatch="\\\\\\\\"),
        Patch(edgecolor="black", facecolor="wheat", label="DXE Phase", hatch="\|\|"),
        Patch(edgecolor="black", facecolor="wheat", label="BDS Phase", hatch="xxxx"),
        Patch(edgecolor="black", facecolor="mediumseagreen", label="Boot Verifier", hatch="**"),
    ]

    ax.legend(loc=7, handles=legend, frameon=False)
    plt.tight_layout()
    if not os.path.exists(OUTDIR):
        os.makedirs(OUTDIR)
    plt.savefig(OUTDIR + OUTFILE)
