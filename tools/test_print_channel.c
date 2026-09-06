#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libusb.h>

#define HP_VID 0x03f0
#define HP_PID 0x2b54

int main(void) {
    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) != 0) {
        fprintf(stderr, "libusb_init failed\n");
        return 1;
    }

    libusb_device_handle *h = libusb_open_device_with_vid_pid(ctx, HP_VID, HP_PID);
    if (!h) {
        fprintf(stderr, "Device not found\n");
        libusb_exit(ctx);
        return 1;
    }
    printf("Device opened successfully\n");

    libusb_set_auto_detach_kernel_driver(h, 1);
    int r = libusb_claim_interface(h, 1);
    printf("claim_interface(1) = %d (%s)\n", r, libusb_error_name(r));
    if (r != 0) {
        libusb_close(h);
        libusb_exit(ctx);
        return 1;
    }

    int c1 = libusb_clear_halt(h, 0x05);
    printf("clear_halt(0x05) = %d (%s)\n", c1, libusb_error_name(c1));
    int c2 = libusb_clear_halt(h, 0x84);
    printf("clear_halt(0x84) = %d (%s)\n", c2, libusb_error_name(c2));

    const char pjl[] = "\033%-12345X@PJL \r\n@PJL INFO ID\r\n\033%-12345X";
    int trans = 0;
    r = libusb_bulk_transfer(h, 0x05, (unsigned char *)pjl, (int)strlen(pjl), &trans, 3000);
    printf("bulk_transfer(0x05, len=%zu) = %d (%s), transferred=%d\n", strlen(pjl), r, libusb_error_name(r), trans);

    char resp[1024];
    memset(resp, 0, sizeof(resp));
    r = libusb_bulk_transfer(h, 0x84, (unsigned char *)resp, sizeof(resp) - 1, &trans, 2000);
    printf("bulk_transfer(0x84, read) = %d (%s), transferred=%d\n", r, libusb_error_name(r), trans);
    if (trans > 0) {
        printf("Response:\n%s\n", resp);
    }

    libusb_release_interface(h, 1);
    libusb_close(h);
    libusb_exit(ctx);
    return 0;
}
