#include <stdio.h>
#include <stdlib.h>
#include <err.h>
#include <string.h>
#include <sys/time.h>

#include "vm.h"
#include "sev.h"
#include "memory.h"
#include "layout.h"

int main(int argc, char *argv[]) {
    int ret;
    Vm vm;
    int snp = 1;

    if (argc < 2) {
        printf("Usage: toy-vmm <mem-size-KB>\n");
        return -1;
    }

    uint64_t size = atoi(argv[1]);

    // Do VM setup
    ret = vm_create(&vm, snp);

    if (ret != 0) {
        err(1, "Error creating VM");
    }

    ret = init_guest_memory(&vm, snp);

    if (ret != 0) {
        err(1, "Error initializing guest memory");
    }

    Sev sev;
    sev.vm_fd = vm.fd_vm;

    snp_init(&sev);

    uint8_t *addr = get_host_addr(&vm, FW_ADDR);

    struct timeval start, end;

    gettimeofday(&start, NULL);
    snp_launch_update_data(&sev, FW_ADDR, addr, size);
    gettimeofday(&end, NULL);

    long usecs = ((end.tv_sec * 1000000 + end.tv_usec) - (start.tv_sec * 1000000 + start.tv_usec));
    printf("%ld\n", usecs);

    return ret;
}
