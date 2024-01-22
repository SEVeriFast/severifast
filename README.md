# SEVeriFast
A minimal bootstrap scheme for fast boot of serverless microVMs with AMD Secure Encrypted Virtualization (SEV)

This repository holds the artifacts and scripts required to reproduce the results presented in the paper 
"SEVeriFast: Minimizing the Minimizing the root of trust for fast
startup of SEV microVMs" (to appear at ASPLOS'24)

## Requirements
**AMD SEV-SNP is required to run experiments.** If you are on a machine with support for SEV-SNP, please refer to [these instructions](https://github.com/AMDESE/AMDSEV/tree/snp-latest) to set up your machine for launching SEV-SNP VMs. One of the experiments in this repo
boots up to 50 SEV-SNP VMs concurrently, so the number of SEV-ES ASIDs configured in your BIOS should be at least 50.

These artifacts have been tested on a machine running Ubuntu 22.04 and uses `apt` to install dependencies.

## Running Experiments
1. Clone this repository.
2. Run `./scripts/install.sh`. This will install the dependencies needed to build components for running experiments and give you access to `/dev/kvm`, `/dev/sev`, and docker.
3. Run `./scripts/build.sh` to build the necessary components. This script builds the host kernel, the guest kernels used in the experiments with the configurations provided in `./kernel-configs`, Firecracker, the SEVeriFast boot verifier, QEMU, OVMF, and SEV tooling required to generate certificates and validate attestation reports.
4. Run `./scripts/run-all.sh` to run the experiments used in the paper. Upon successful completion, the data collected will be placed in `./data` and figures will be generated from the new data and placed in `./figs/`. `./figs/paper` contains the plots used in the paper which should be compared to the new plots to validate results.

## Repo Structure
```
Root
|---- attestation    # script to perform remote attestation and nginx attestation server config
|---- fc-config      # base config for launching Firecracker microVMs
|---- figs/paper     # figures used in the paper
|---- images         # initrds for each kernel config
|---- kernel-configs # Linux kernel configurations for our three sample kernels used in the paper
|---- kernel-hasher  # A utility that computes hashes for bzImage and vmlinux Linux kernels
|---- scripts        # scripts for installation, building components, running experiments, and generating plots
|---- toy-vmm        # A minimal VMM implementation used to benchmark SEV-SNP pre-encryption speed
```
