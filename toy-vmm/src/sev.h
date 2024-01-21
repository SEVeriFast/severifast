#ifndef SEV_H
#define SEV_H

#include <stdint.h>
#include <fcntl.h>
#include <linux/kvm.h>

#define SEV_DEV "/dev/sev"
#define DEAULT_POLICY 0x1

typedef struct sev {
    int vm_fd;
    int sev_fd;
    uint32_t handle;
    uint32_t policy;
} Sev;

int sev_init(Sev *sev);
int snp_init(Sev *sev);
int sev_launch_start(Sev *sev);
int snp_launch_start(Sev *sev);
int sev_launch_update_data(Sev *sev, uint8_t *addr, uint64_t len);
int snp_launch_update_data(Sev *sev, uint64_t guest_addr, uint8_t *uaddr, uint64_t len);
int sev_reg_region(Sev *sev, void* host, size_t size);
int sev_unreg_region(Sev *sev, void* host, size_t size);
int sev_platform_ioctl(Sev *sev, int cmd, void *data, int *error);
int sev_ioctl(Sev *sev, int cmd, void *data, int *error);

#endif