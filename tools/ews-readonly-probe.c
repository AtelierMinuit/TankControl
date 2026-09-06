/* Diagnóstico EWS sólo lectura. No envía POST ni datos de impresión. */
#include <limits.h>
#include <libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VID 0x03f0
#define PID 0x2b54
#define MAX_RESPONSE 65536

static int send_text(libusb_device_handle *h, unsigned char ep, const char *s, int *n) {
    size_t len = strlen(s);
    if (len > (size_t)INT_MAX) return LIBUSB_ERROR_OVERFLOW;
    return libusb_bulk_transfer(h, ep, (unsigned char *)s, (int)len, n, 3000);
}

static int probe(libusb_context *ctx, int iface, unsigned char in_ep, unsigned char out_ep,
                 const char *path) {
    libusb_device_handle *h = libusb_open_device_with_vid_pid(ctx, VID, PID);
    if (!h) return 2;
    libusb_set_auto_detach_kernel_driver(h, 1);
    int r = libusb_claim_interface(h, iface);
    if (r != 0) { libusb_close(h); return 3; }

    char req[1024];
    int req_len = snprintf(req, sizeof(req),
                           "GET %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n", path);
    int sent = 0;
    int write_rc = 0;
    if (req_len < 0 || (size_t)req_len >= sizeof(req)) r = LIBUSB_ERROR_OVERFLOW;
    else { write_rc = send_text(h, out_ep, req, &sent); r = write_rc; }

    unsigned char *buf = (unsigned char *)calloc(1, MAX_RESPONSE);
    int received = 0;
    if (r == 0 && buf) {
        r = libusb_bulk_transfer(h, in_ep, buf, MAX_RESPONSE - 1, &received, 5000);
    }
    printf("interface=%d out=0x%02x in=0x%02x write_rc=%d written=%d read_rc=%d bytes=%d\n",
           iface, out_ep, in_ep, write_rc, sent, r, received);
    if (received > 0 && buf) fwrite(buf, 1, (size_t)received, stdout);
    free(buf);
    libusb_release_interface(h, iface);
    libusb_close(h);
    return r == 0 ? 0 : 4;
}

int main(int argc, char **argv) {
    const char *path = argc > 1 ? argv[1] : "/DevMgmt/ConsumableConfigDyn.xml";
    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) != 0) return 1;
    int rc2 = probe(ctx, 2, 0x86, 0x07, path);
    int rc3 = probe(ctx, 3, 0x88, 0x09, path);
    libusb_exit(ctx);
    return (rc2 == 0 || rc3 == 0) ? 0 : 1;
}
