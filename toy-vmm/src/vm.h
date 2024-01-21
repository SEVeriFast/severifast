#ifndef VM_H
#define VM_H

#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/kvm.h>

#define DEVICE_KVM "/dev/kvm"

typedef struct kvm_vm {
    int fd_kvm;
    int fd_vm;
    size_t mmap_size;
    size_t ram_size;
    void* mem_start;
} Vm;

int vm_create(Vm *vm, int snp);
int vm_init(Vm *vm);

#define KVM_SET_USER_MEMORY_REGION2 _IOW(KVMIO, 0x49, \
					struct kvm_userspace_memory_region2)

#endif
