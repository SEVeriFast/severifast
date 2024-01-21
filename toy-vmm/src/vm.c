#include <err.h>
#include <linux/kvm.h>
#include <stdlib.h>

#include "vm.h"

int vm_create(Vm *vm, int snp){
    int type;

    vm->fd_kvm = open(DEVICE_KVM, O_RDWR | O_CLOEXEC);
    if (vm->fd_kvm < 0)
        err(1, DEVICE_KVM);

    int ret = ioctl(vm->fd_kvm, KVM_GET_VCPU_MMAP_SIZE, NULL);
    if (ret < 0)
        err(1, "KVM_GET_VCPU_MMAP_SIZE");

    vm->mmap_size = ret;

    if(snp) {
        type = 1;
    } else {
        type = 0;
    }

    vm->fd_vm = ioctl(vm->fd_kvm, KVM_CREATE_VM, type);
    if (vm->fd_vm < 0)
        err(1, "KVM_CREATE_VM");

    return 0;
}

int vm_init(Vm *vm){
    return 0;    
}