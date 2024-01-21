#include <linux/kvm.h>
#include <linux/psp-sev.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <err.h>
#include <errno.h>

#include "sev.h"

int sev_init(Sev *sev) {
    int ret, error;
    struct sev_user_data_status status = {};

    sev->sev_fd = open(SEV_DEV, O_RDWR);
    if (sev->sev_fd < 0)
        err(1, "Error opening %s", SEV_DEV);

    printf("/dev/sev fd: %d\n", sev->sev_fd);

    ret = sev_platform_ioctl(sev, SEV_PLATFORM_STATUS, &status, &error);

    if (ret) {
        err(1, "SEV_ISSUE_CMD failed ret=%d error=%d", ret, error);
        return -1;
    }

    ret = sev_ioctl(sev, KVM_SEV_INIT, NULL, &error);

    if (ret) {
        err(1, "Error initializing SEV ret=%d error=%d", ret, error);
        return -1;
    }

    return sev_launch_start(sev);
}

int snp_init(Sev *sev) {
    int ret, error = 0;
    struct kvm_snp_init init;
    init.flags = 0;

    sev->sev_fd = open(SEV_DEV, O_RDWR);
    if (sev->sev_fd < 0)
        err(1, "Error opening %s", SEV_DEV);

    ret = sev_ioctl(sev, KVM_SEV_SNP_INIT, &init, &error);

    if (ret) {
        err(1, "Error initializing SEV-SNP ret=%d error=%d", ret, error);
        return -1;
    }

    return snp_launch_start(sev);
}

int snp_launch_start(Sev *sev) {
    int ret, error;

    struct kvm_sev_snp_launch_start start;

    start.policy = 0x30000;

    ret = sev_ioctl(sev, KVM_SEV_SNP_LAUNCH_START, &start, &error);

    if (ret) {
        err(1, "SNP_LAUNCH_START error ret=%d, error=%d", ret, error);
        return -1;
    }

    return 0;
}

int sev_launch_start(Sev *sev) {
    int ret, error;

    struct kvm_sev_launch_start start = {
        .handle = 0, .policy = DEAULT_POLICY
    };

    ret = sev_ioctl(sev, KVM_SEV_LAUNCH_START, &start, &error);

    if (ret) {
        err(1, "LAUNCH_START error ret=%d error=%d", ret, error);
        return -1;
    }

    sev->handle = start.handle;

    return 0;
}

int snp_launch_update_data(Sev *sev, uint64_t guest_addr, uint8_t *uaddr, uint64_t len) {
    int ret, error;
    uint64_t gfn;
    struct kvm_sev_snp_launch_update region = {0};

    gfn = guest_addr >> 12;

    region.start_gfn = gfn;
    region.len = len;
    region.uaddr = (uint64_t)uaddr;
    region.imi_page = 0;
    region.page_type = 1;
    region.vmpl1_perms = 0;
    region.vmpl2_perms = 0;
    region.vmpl3_perms = 0;

    ret = sev_ioctl(sev, KVM_SEV_SNP_LAUNCH_UPDATE, &region, &error);

    if (ret) {
        err(1, "SNP_LAUNCH_UPDATE error: ret=%d, error=%d", ret, error);
        return -1;
    }

    return 0;
}

int sev_launch_update_data(Sev *sev, uint8_t *addr, uint64_t len) {
    int ret, error;
    struct kvm_sev_launch_update_data region;

    if (!addr || !len) {
        return -1;
    }

    region.uaddr = (__u64)(unsigned long)addr;
    region.len = len;

    ret = sev_ioctl(sev, KVM_SEV_LAUNCH_UPDATE_DATA, &region, &error);

    if (ret) {
        err(1, "LAUNCH_UPDATE error ret=%d, error=%d", ret, error);
        return -1;
    }

    return 0;
}

int sev_reg_region(Sev *sev, void* host, size_t size) {
    int ret;
    struct kvm_enc_region range;

    range.addr = (__u64)(unsigned long)host;
    range.size = size;

    ret = ioctl(sev->vm_fd, KVM_MEMORY_ENCRYPT_REG_REGION, &range);

    if (ret) {
        err(1, "Failed to register region");
        return -1;
    }
    return 0;
}

int sev_unreg_region(Sev *sev, void* host, size_t size) {
    int ret;
    struct kvm_enc_region range;

    range.addr = (__u64)(unsigned long)host;
    range.size = size;

    ret = ioctl(sev->vm_fd, KVM_MEMORY_ENCRYPT_UNREG_REGION, &range);

    if (ret) {
        err(1, "Failed to unregister region");
        return -1;
    }
    return 0;
}

int sev_platform_ioctl(Sev *sev, int cmd, void *data, int *error) {
    int ret;
    struct sev_issue_cmd arg;

    arg.cmd = cmd;
    arg.data = (unsigned long)data;
    ret = ioctl(sev->sev_fd, SEV_ISSUE_CMD, &arg);
    if (error) {
        *error = arg.error; 
    }

    return ret;
}

int sev_ioctl(Sev *sev, int cmd, void *data, int *error) {
    int ret;
    struct kvm_sev_cmd input;

    memset(&input, 0x0, sizeof(input));

    input.id = cmd;
    input.sev_fd = sev->sev_fd;
    input.data = (__u64)(unsigned long)data;

    ret = ioctl(sev->vm_fd, KVM_MEMORY_ENCRYPT_OP, &input);

    *error = input.error;

    return ret;
}
