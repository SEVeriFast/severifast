#ifndef MEMORY_H
#define MEMORY_H

#include <sys/ioctl.h>

#include "vm.h"

#define MEMORY_SIZE 0x10000000

int init_guest_memory(Vm *vm, int snp);
__uint8_t *get_host_addr(Vm *vm, uint64_t gpa);

#endif
