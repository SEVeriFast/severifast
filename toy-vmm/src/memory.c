#include <stdlib.h>
#include <sys/mman.h>
#include <err.h>
#include <linux/kvm.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include "memory.h"
#include "vm.h"

int init_guest_memory(Vm *vm, int snp){
    
    vm->ram_size = MEMORY_SIZE / 4;
    int ret;
    int restricted_fd = 0;

    if(snp) {
        restricted_fd = syscall(451, 0);
    }

    void *mem = mmap(NULL, vm->ram_size, PROT_READ | PROT_WRITE ,
                MAP_PRIVATE | MAP_ANONYMOUS , -1, 0);

    madvise(mem, vm->ram_size, MADV_HUGEPAGE);
    
    if (mem == MAP_FAILED) {
        errx(1, "mmap failed: %s", strerror(errno));
    }

    if (snp) {
        struct kvm_userspace_memory_region2 region = {
            .slot = 0,
            .guest_phys_addr = 0x0,
            .memory_size = vm->ram_size,
            .userspace_addr = (uint64_t)mem,
            .flags = 4,
            .restrictedmem_fd = restricted_fd,
            .restrictedmem_offset = 0,
        };

        ret = ioctl(vm->fd_vm, KVM_SET_USER_MEMORY_REGION2, &region);
        if (ret == -1)
            err(1, "KVM_SET_USER_MEMORY_REGION2");

    } else {
        struct kvm_userspace_memory_region region = {
            .slot = 0,
            .guest_phys_addr = 0x0,
            .memory_size = vm->ram_size,
            .userspace_addr = (uint64_t)mem,
        };
        ret = ioctl(vm->fd_vm, KVM_SET_USER_MEMORY_REGION, &region);
        if (ret == -1)
            err(1, "KVM_SET_USER_MEMORY_REGION");
    }
    

    vm->mem_start = mem;

    return ret;
}

__uint8_t *get_host_addr(Vm *vm, uint64_t gpa){
    __u64 mem_start = (unsigned long)vm->mem_start;
    return (__uint8_t *)(mem_start + gpa);
}