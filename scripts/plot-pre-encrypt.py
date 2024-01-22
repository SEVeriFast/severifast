#!/usr/bin/python

from matplotlib import pyplot as plt
import matplotlib
import numpy as np
import json
import os
import re

DATAPATH="./data/pre-encrypt/"

LUPINE_BZIMAGE_SIZE_KB=os.path.getsize("./kernels/bzImage-lupine-6.4-lz4")/1024
LUPINE_VMLINUX_SIZE_KB=os.path.getsize("./kernels/vmlinux-lupine-6.4")/1024
LUPINE_INITRD_SIZE_KB=os.path.getsize("./images/initrd-lupine-lz4.img")/1024
LUPINE_UNCOMPRESSED_INITRD_SIZE_KB=os.path.getsize("./images/initrd-lupine.img")/1024
OVMF_SIZE_KB=os.path.getsize("./bin/AmdSev-1MB.fd")/1024

OUTDIR="./figs/"
OUTFILE="pre-encrypt.pdf"

def rand_graph(path):

    all_files=os.listdir(path)

    all_files=sorted(all_files, key=lambda x: int(x[:-4]))

    averages=[]
    x_axis=[]

    for file in all_files:
        f=open(path + str(file))
        x_axis.append(int(file[:-4]))

        all_data=f.readlines()
        all_data=[int(x.split("\n")[0]) for x in all_data]
        averages.append(np.average(all_data) / 1000.0)

    x_axis = [x / 1024 for x in x_axis]

    slope, intercept = np.polyfit(x_axis, averages, 1)
    plt.plot(x_axis, averages)
    plt.plot(LUPINE_VMLINUX_SIZE_KB, LUPINE_VMLINUX_SIZE_KB*slope, marker="o",label="Lupine vmlinux (%.2fs)" % (LUPINE_VMLINUX_SIZE_KB*slope/1000.0))
    plt.plot(LUPINE_BZIMAGE_SIZE_KB, LUPINE_BZIMAGE_SIZE_KB*slope, marker="s",label="Lupine bzImage (%.2fs)" % (LUPINE_BZIMAGE_SIZE_KB*slope/1000.0))
    plt.plot(LUPINE_INITRD_SIZE_KB, LUPINE_INITRD_SIZE_KB*slope, marker="o",label="Compressed initrd (%.2fs)" % (LUPINE_INITRD_SIZE_KB*slope/1000.0))
    plt.plot(LUPINE_UNCOMPRESSED_INITRD_SIZE_KB, LUPINE_UNCOMPRESSED_INITRD_SIZE_KB*slope, marker="o",label="initrd (%.2fs)" % (LUPINE_UNCOMPRESSED_INITRD_SIZE_KB*slope/1000.0))
    plt.plot(OVMF_SIZE_KB, OVMF_SIZE_KB*slope, marker="o",label="OVMF (%.2fms)" % (OVMF_SIZE_KB*slope))

if __name__ == "__main__":
    font = {'size'   : 7}

    matplotlib.rc('font', **font)

    rand_graph(DATAPATH)
    plt.legend(loc="upper left", framealpha=0)

    y_label="Time (ms)"
    x_label="Region Size (KB)"

    plt.ylabel(y_label)
    plt.xlabel(x_label)

    fig = plt.gcf()
    fig.set_size_inches(5, 1.6)

    plt.tight_layout()
    if not os.path.exists(OUTDIR):
        os.makedirs(OUTDIR)
    plt.savefig(OUTDIR + OUTFILE)
