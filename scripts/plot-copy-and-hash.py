#!/usr/bin/python

from matplotlib import pyplot as plt
import matplotlib
import numpy as np
import json
from matplotlib.patches import Patch
import os

LUPINE_BZIMAGE_DATA="./data/boot/firecracker/bzImage-lupine-6.4-lz4-snp"
LUPINE_RUST_DIRECT_DATA="./data/boot/firecracker/vmlinux-lupine-6.4-snp"
LUPINE_GZIP_DATA="./data/boot/firecracker/bzImage-lupine-6.4-gzip-snp-initrd-lupine-gzip.img"

AWS_BZIMAGE_DATA="./data/boot/firecracker/bzImage-aws-6.4-lz4-snp"
AWS_LZ4_INITRD="./data/boot/firecracker/bzImage-aws-6.4-lz4-snp-initrd-aws-lz4.img"
AWS_RUST_DIRECT_DATA="./data/boot/firecracker/vmlinux-aws-6.4-snp"
AWS_GZIP_DATA="./data/boot/firecracker/bzImage-aws-6.4-gzip-snp-initrd-aws-gzip.img"

UBUNTU_BZIMAGE_DATA="./data/boot/firecracker/bzImage-ubuntu-6.4-lz4-snp"
UBUNTU_RUST_DIRECT_DATA="./data/boot/firecracker/vmlinux-ubuntu-6.4-snp"
UBUNTU_GZIP_DATA="./data/boot/firecracker/bzImage-ubuntu-6.4-gzip-snp-initrd-ubuntu-gzip.img"

OUTDIR="./figs/"
OUTFILE="boot-verifier.pdf"

def parse_data(in_file, fig, ax, out_file=None, sev=True, firmware=True, bzImage=True, x_coord=0, hashes=True, qemu=False, initrd=False, legend=False):

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
    bar_width=10
    # Average times in ms
    for key in all_times.keys():
        average_times[key] = np.average(all_times[key])/1000.0

    pre_encrypt_time=0
    fw_time=0
    bzimage_time=0
    hypervisor_time=0
    hash_time=0
    copy_time=0

    if bzImage:
        hypervisor_time = average_times["bzimage_entry_point"]
    if firmware:
        hypervisor_time = average_times["firmware_entry_point"]
    if hashes:
        if initrd:
            hash_time = average_times["initrd_hash_time"]
            copy_time = average_times["initrd_copy_time"]
        else:
            hash_time = average_times["hash_time"]
            copy_time = average_times["copy_time"]
    else:
        hypervisor_time = average_times["linux_entry_point"]

    if sev:
        pre_encrypt_time = average_times["pre_encrypt_time"]
        if not qemu:
            pre_encrypt_time = pre_encrypt_time / 1000.0

    if firmware and bzImage:
        fw_time = average_times["bzimage_entry_point"] - average_times["firmware_entry_point"]
    if firmware and not bzImage:
        fw_time = average_times["linux_entry_point"] - average_times["firmware_entry_point"]
    if bzImage:
        if initrd:
            bzimage_time = average_times["initrd_unpack_done"] - average_times["initrd_unpack_start"]
        else:
            bzimage_time = average_times["linux_entry_point"] - average_times["bzimage_entry_point"]

    linux_time = average_times["linux_run_init"] - average_times["linux_entry_point"]

    ax.set_ylabel("Average Time (ms)")

    plt.tight_layout()

    bar1 = None
    bar2 = None
    bar3 = None

    if bzImage:
        ax.bar(x_coord, bzimage_time, color="orange", edgecolor="black", hatch="..", bottom=copy_time+hash_time, label="bzImage Bootloader", width=0.3)
    if initrd:
        bar1 = ax.bar(x_coord, bzimage_time, color="orchid", edgecolor="black", hatch="\|", bottom=copy_time+hash_time, label="initrd Unpacking", width=0.3)

    if firmware:
        if not initrd:
            ax.bar(x_coord, hash_time, color="green", bottom=copy_time, label="Kernel Hash Time", edgecolor="black", hatch="\\\\", width=0.3)
            ax.bar(x_coord, copy_time, color="red", bottom=0, label="Kernel Copy Time", edgecolor="black", hatch="//", width=0.3)
        else:
            bar2 = ax.bar(x_coord, hash_time, color="turquoise", bottom=copy_time, label="Initrd Hash Time", edgecolor="black", hatch="++", width=0.3)
            bar3 = ax.bar(x_coord, copy_time, color="pink", bottom=0, label="Initrd Copy Time", edgecolor="black", hatch="**", width=0.3)


    #Save graph
    if out_file is not None:
        ax.get_xaxis().set_visible(False)
        plt.xlim([-0.5, 2])
        leg = ax.legend(loc=1, prop={'size': 6})
        leg.get_frame().set_linewidth(0.0)
        plt.savefig(out_file)

def plot_all():
    fig,ax =plt.subplots(figsize=(6, 4))

    legend1 = [
        Patch(edgecolor="black", facecolor="orange", label="bzImage Bootloader", hatch="..."),
        Patch(edgecolor="black", facecolor="green", label="Kernel Hash Time", hatch="\\\\\\"),
        Patch(edgecolor="black", facecolor="red", label="Kernel Copy Time", hatch="///")
    ]

    legend2 = [
        Patch(edgecolor="black", facecolor="orchid", label="initrd Unpacking", hatch="\|\|\|"),
        Patch(edgecolor="black", facecolor="turquoise", label="initrd Hash Time", hatch="+++"),
        Patch(edgecolor="black", facecolor="pink", label="initrd Copy Time", hatch="***")
    ]

    parse_data(LUPINE_BZIMAGE_DATA, fig, ax, x_coord=0, sev=True,firmware=True,bzImage=True)
    legend1 = plt.legend(frameon=False, framealpha=0, loc="upper left", handles=legend1)
    plt.legend(frameon=False, framealpha=0, loc="upper right", handles=legend2)
    plt.gca().add_artist(legend1)

    parse_data(LUPINE_RUST_DIRECT_DATA, fig, ax, x_coord=0.3, bzImage=False)
    parse_data(LUPINE_GZIP_DATA, fig, ax, x_coord=0.6, sev=True, firmware=True, bzImage=True)

    parse_data(AWS_BZIMAGE_DATA, fig, ax, x_coord=1, sev=True,firmware=True,bzImage=True)
    parse_data(AWS_RUST_DIRECT_DATA, fig, ax, x_coord=1.3, bzImage=False)
    parse_data(AWS_GZIP_DATA, fig, ax, x_coord=1.6, sev=True, firmware=True, bzImage=True)

    parse_data(UBUNTU_BZIMAGE_DATA, fig, ax, x_coord=2, sev=True,firmware=True,bzImage=True)
    parse_data(UBUNTU_RUST_DIRECT_DATA, fig, ax, x_coord=2.3, bzImage=False)
    parse_data(UBUNTU_GZIP_DATA, fig, ax, x_coord=2.6, sev=True, firmware=True, bzImage=True)

    plt.axvline(x=2.8, color="black")

    parse_data(AWS_BZIMAGE_DATA, fig, ax, x_coord=3.4, sev=True,firmware=True,  initrd=True, legend=True)
    parse_data(AWS_LZ4_INITRD, fig, ax, x_coord=3.7,  initrd=True)
    parse_data(AWS_BZIMAGE_DATA, fig, ax, x_coord=4,  initrd=True)

    trans = ax.get_xaxis_transform()

    ax.annotate("Lupine", xy=(0.25, 0.4), xycoords=trans, ha='center')
    ax.annotate("AWS", xy=(1.25, 0.5), xycoords=trans, ha='center')
    ax.annotate("Ubuntu", xy=(2.20, 0.5), xycoords=trans, ha='center')
    plt.xticks([0, 0.3, 0.6, 3.4, 3.7, 4], ["bzImage LZ4", "vmlinux", "bzImage GZIP", "initrd uncompressed", "initrd lz4", "initrd gzip"], rotation=25, ha='right')
    ax.set_ylim(0, 130)

    plt.tight_layout()

    if not os.path.exists(OUTDIR):
        os.makedirs(OUTDIR)
    plt.savefig(OUTDIR + OUTFILE)

if __name__ == "__main__":
    font = {'size'   : 10}

    matplotlib.rc('font', **font)

    plot_all()
