#!/usr/bin/python

import os
from matplotlib import pyplot as plt
import matplotlib
import numpy as np
import seaborn as sns
import json

RESULTS_PATH="./data/boot/"
KERNELS_PATH="./kernels/"

OUTDIR="./figs/"
OUTFILE="severifast-vs-qemu.pdf"

def plot_cdf_all():
    all_kernels=os.listdir(KERNELS_PATH)

    all_kernels.sort()
    # put kernel paths in order (lupine, aws, ubuntu)
    all_kernels.sort(key = lambda x : ("lupine" not in x))
    fig,ax = plt.subplots()
    plt.figure(1)

    max_times = []

    acc=211
    for vmm_type in ["firecracker", "qemu"]:
        
        plt.subplot(acc)
        acc += 1
        for kernel in all_kernels:
            # only snp for this graph
            for sev_type in ["-snp"]:
                data_path=f"{RESULTS_PATH}{vmm_type}/{kernel}{sev_type}"
                if os.path.exists(data_path) and not "gzip" in kernel and not "vmlinux" in kernel: 
                    max_times.append(plot_cdf(data_path))

        if vmm_type == "firecracker":
            plt.legend(loc="center right", prop={'size': 8}, frameon=False)
        else:
            plt.legend(loc="center left", prop={'size': 8}, frameon=False)


    for plot in [211, 212]:
        plt.subplot(plot)
        plt.xlim([-0.02*np.max(max_times), 1.02 * np.max(max_times)])
        plt.xlabel("Time (ms)")
        plt.xticks([0, 500, 2000, 3000, 2000, 4000, 5000])
        fig.set_size_inches(4, 2.6)
        plt.tight_layout()

    if not os.path.exists(OUTDIR):
        os.makedirs(OUTDIR)
    plt.savefig(OUTDIR + OUTFILE)

def plot_cdf(path):
    f=open(path)
    lines=f.readlines()

    all_times={}
    all_end_to_end_times=[]
    average_times={}

    pre_enc_time=0
    fw_time=0

    for l in lines:
        try:
            j=(json.loads(l))
            if "lupine" in path and "firecracker" in path:
                all_end_to_end_times.append(j["linux_run_init"]/1000)
            else:
                all_end_to_end_times.append(j["attestation_done"]/1000)

            pre_enc_time += j["pre_encrypt_time"]/1000

            fw_time += (j["bzimage_entry_point"] - j["firmware_entry_point"]) / 1000

        except:
            print(f"Problem with {path}")

    if "firecracker" in path:
        label = "SEVeriFast "
    else:
        label = "QEMU "

    kernel = os.path.basename(os.path.normpath(path)).split("-")
    kernel = kernel[1]

    label = label + kernel 

    print(label + (" "*(18-len(label))) + "| " + "{:.2f}".format(pre_enc_time) + "ms" + (" "*(len("Pre-encryption")-len("{:.2f}".format(pre_enc_time)) -1 ))  + "| " + "{:.2f}".format(fw_time) + "ms")

    if "lupine" in kernel:
        label += "\n(no attestation)"

    sns.kdeplot(data = all_end_to_end_times, cumulative = True, label = label, bw_adjust = 0.01)

    return np.max(all_end_to_end_times)

if __name__ == "__main__":
    font = {'size'   : 9}

    matplotlib.rc('font', **font)
    print("                  | Pre-encryption | Firmware/Boot Verification ")
    print("----------------------------------------------------------------")
    plot_cdf_all()
