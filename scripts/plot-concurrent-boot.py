#!/usr/bin/python

from matplotlib import pyplot as plt
import matplotlib
import numpy as np
import os

OUTDIR="./figs/"
OUTFILE="concurrent-boot.pdf"

def abline(slope, intercept):
    axes = plt.gca()
    x_vals = np.array(axes.get_xlim())
    y_vals = intercept + slope * x_vals
    plt.plot(x_vals, y_vals, '--')

def plot_all(path, fig, ax, label=None):
    averages=[]
    after_averages=[]
    file=open(path)
    lines=file.readlines()

    x_axis=[x for x in range(0, len(lines))]
    y_axis=[]
    acc = 0
    for line in lines:
        try:
            y_axis.append(float(line))
        except:
            pass
    return np.max(y_axis)

    if "firecracker" in path:
        y_axis = np.array(y_axis)

    ax.plot(x_axis, y_axis, linestyle="-", marker="D", markevery=5, label=label)

    slope, intercept = np.polyfit(x_axis, y_axis, 1)

if __name__ == "__main__":
    fig,ax =plt.subplots()

    font = {'size'   : 13}

    matplotlib.rc('font', **font)

    plt.figure(1)
    plt.subplot(121)

    x_axis=[]
    y_axis=[]

    n = int(len(os.listdir("./data/boot/concurrent/qemu/")) / 2)
    
    for i in range(1, n):
        average = plot_all(f"./data/boot/concurrent/qemu/stock-{i}.dat", fig, ax, label = "Stock QEMU")
        y_axis.append(average/1000)
        x_axis.append(i)

    plt.plot(x_axis, y_axis, label="Stock QEMU", marker="o", linestyle='--', markevery=10)

    x_axis=[]
    y_axis=[]

    for i in range(1, n):
        average = plot_all(f"./data/boot/concurrent/qemu/snp-{i}.dat", fig, ax, label = "QEMU SEV")
        y_axis.append(average/1000)
        x_axis.append(i)
    slope, intercept = np.polyfit(x_axis, y_axis, 1)

    plt.plot(x_axis, y_axis, label=f"QEMU SEV slope={int(slope)}", marker="s", linestyle='--', markevery=10)

    plt.legend(frameon=False, framealpha=0, loc="upper left")
    plt.ylabel("Mean Boot Time (ms)")
    plt.xlabel("Concurrent QEMU Instances")

    plt.subplot(122)
    x_axis=[]
    y_axis=[]
    for i in range(1, n):
        average = plot_all(f"./data/boot/concurrent/firecracker/stock-{i}.dat", fig, ax, label = "Stock FC")
        y_axis.append(average/1000)
        x_axis.append(i)

    plt.plot(x_axis, y_axis, label="Stock FC", marker="o", linestyle='--', markevery=10)

    x_axis=[]
    y_axis=[]

    for i in range(1, n):
        average = plot_all(f"./data/boot/concurrent/firecracker/snp-{i}.dat", fig, ax, label = "FC SEV")
        y_axis.append(average/1000)
        x_axis.append(i)
    slope, intercept = np.polyfit(x_axis, y_axis, 1)

    plt.plot(x_axis, y_axis, label=f"FC SEV slope={int(slope)}", marker="s", linestyle='--', markevery=10)
    plt.legend(frameon=False, framealpha=0)

    plt.ylabel("Mean Boot Time (ms)")
    plt.xlabel("Concurrent Firecracker Instances")
    fig.set_size_inches(7.5, 3.5)

    plt.tight_layout()

    if not os.path.exists(OUTDIR):
        os.makedirs(OUTDIR)
    plt.savefig(OUTDIR + OUTFILE)
