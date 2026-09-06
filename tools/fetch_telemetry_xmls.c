#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stddef.h>
#include <libusb.h>
#include <CommonCrypto/CommonDigest.h>

#define HP_VID 0x03f0
#define HP_PID 0x2b54

typedef struct {
    libusb_device_handle *handle;
    int interface_number;
    uint8_t ep_out;
    uint8_t ep_in;
} usb_channel_t;

static int open_channel(libusb_context *ctx, uint8_t class_code, uint8_t subclass_code,
                        uint8_t proto_code, usb_channel_t *chan) {
    libusb_device **devs = NULL;
    ssize_t cnt = libusb_get_device_list(ctx, &devs);
    if (cnt < 0) return -1;

    libusb_device *target_dev = NULL;
    for (ssize_t i = 0; i < cnt; i++) {
        struct libusb_device_descriptor desc;
        if (libusb_get_device_descriptor(devs[i], &desc) == 0) {
            if (desc.idVendor == HP_VID && desc.idProduct == HP_PID) {
                target_dev = libusb_ref_device(devs[i]);
                break;
            }
        }
    }
    if (!target_dev) {
        libusb_free_device_list(devs, 1);
        return -1;
    }

    struct libusb_config_descriptor *config = NULL;
    if (libusb_get_active_config_descriptor(target_dev, &config) != 0) {
        libusb_free_device_list(devs, 1);
        return -1;
    }

    int matched_iface = -1;
    uint8_t in_ep = 0, out_ep = 0;

    for (int i = 0; i < config->bNumInterfaces; i++) {
        const struct libusb_interface *iface = &config->interface[i];
        for (int a = 0; a < iface->num_altsetting; a++) {
            const struct libusb_interface_descriptor *alt = &iface->altsetting[a];
            if (alt->bInterfaceClass == class_code &&
                alt->bInterfaceSubClass == subclass_code &&
                alt->bInterfaceProtocol == proto_code) {
                matched_iface = alt->bInterfaceNumber;
                for (int e = 0; e < alt->bNumEndpoints; e++) {
                    const struct libusb_endpoint_descriptor *ep = &alt->endpoint[e];
                    if ((ep->bmAttributes & 0x03) == LIBUSB_TRANSFER_TYPE_BULK) {
                        if ((ep->bEndpointAddress & 0x80) == LIBUSB_ENDPOINT_IN) {
                            in_ep = ep->bEndpointAddress;
                        } else {
                            out_ep = ep->bEndpointAddress;
                        }
                    }
                }
                break;
            }
        }
        if (matched_iface >= 0) break;
    }

    libusb_free_config_descriptor(config);

    if (matched_iface < 0 || in_ep == 0 || out_ep == 0) {
        libusb_unref_device(target_dev);
        libusb_free_device_list(devs, 1);
        return -1;
    }

    libusb_device_handle *h = NULL;
    int r = libusb_open(target_dev, &h);
    libusb_unref_device(target_dev);
    libusb_free_device_list(devs, 1);
    if (r != 0 || !h) {
        fprintf(stderr, "open_channel: libusb_open failed: %d (%s)\n", r, libusb_error_name(r));
        return -1;
    }

    libusb_set_auto_detach_kernel_driver(h, 1);
    r = libusb_claim_interface(h, matched_iface);
    if (r != 0) {
        fprintf(stderr, "open_channel: claim_interface(%d) failed: %d (%s)\n", matched_iface, r, libusb_error_name(r));
        libusb_close(h);
        return -1;
    }
    libusb_clear_halt(h, out_ep);
    libusb_clear_halt(h, in_ep);

    chan->handle = h;
    chan->interface_number = matched_iface;
    chan->ep_out = out_ep;
    chan->ep_in = in_ep;
    return 0;
}

static void close_channel(usb_channel_t *chan) {
    if (chan && chan->handle) {
        libusb_release_interface(chan->handle, chan->interface_number);
        libusb_close(chan->handle);
        chan->handle = NULL;
    }
}

static void drain_endpoint(usb_channel_t *chan) {
    unsigned char dummy[4096];
    int trans = 0;
    while (libusb_bulk_transfer(chan->handle, chan->ep_in, dummy, sizeof(dummy), &trans, 60) == 0 && trans > 0) {
        // drained residual
    }
}

static int http_request(usb_channel_t *chan, const char *req, char *resp_buf, int max_resp, double *duration_ms) {
    drain_endpoint(chan);
    struct timeval t0, t1;
    gettimeofday(&t0, NULL);

    int transferred = 0;
    int r = libusb_bulk_transfer(chan->handle, chan->ep_out, (unsigned char *)req, (int)strlen(req), &transferred, 3000);
    if (r != 0) {
        return -1;
    }

    int total_read = 0;
    int complete = 0;
    int retries_empty = 0;
    memset(resp_buf, 0, (size_t)max_resp);

    while (total_read < max_resp - 1) {
        int chunk_read = 0;
        r = libusb_bulk_transfer(chan->handle, chan->ep_in, (unsigned char *)resp_buf + total_read, max_resp - 1 - total_read, &chunk_read, 1500);
        if (r == 0 && chunk_read > 0) {
            total_read += chunk_read;
            resp_buf[total_read] = '\0';

            char *hdr_end = strstr(resp_buf, "\r\n\r\n");
            if (hdr_end) {
                char *cl_ptr = strstr(resp_buf, "Content-Length: ");
                if (cl_ptr) {
                    long cl = strtol(cl_ptr + 16, NULL, 10);
                    ptrdiff_t body_offset = hdr_end + 4 - resp_buf;
                    int body_len = (int)(total_read - body_offset);
                    if (body_len >= cl) {
                        complete = 1;
                        break;
                    }
                } else if (strstr(resp_buf, "Transfer-Encoding: chunked") || strstr(resp_buf, "Transfer-Encoding: Chunked")) {
                    if (strstr(resp_buf, "\r\n0\r\n\r\n") || strstr(resp_buf, "0\r\n\r\n") ||
                        strstr(resp_buf, "</psdyn:ProductStatusDyn>") ||
                        strstr(resp_buf, "</ccdyn:ConsumableConfigDyn>") ||
                        strstr(resp_buf, "</pudyn:ProductUsageDyn>") ||
                        strstr(resp_buf, "</ScanStatus>") ||
                        strstr(resp_buf, "</scan:ScanCaps>") ||
                        strstr(resp_buf, "</ProductConfigDyn>") ||
                        strstr(resp_buf, "</DiscoveryTree>") ||
                        strstr(resp_buf, "</MediaCapabilities>")) {
                        complete = 1;
                        break;
                    }
                }
            }
        } else {
            if (total_read == 0 && retries_empty++ < 15) {
                usleep(50000);
                continue;
            }
            if (total_read > 0 && strstr(resp_buf, "\r\n\r\n")) {
                complete = 1;
            }
            break;
        }
    }

    gettimeofday(&t1, NULL);
    *duration_ms = (t1.tv_sec - t0.tv_sec) * 1000.0 + (t1.tv_usec - t0.tv_usec) / 1000.0;

    return complete ? total_read : -1;
}

static void compute_sha256(const unsigned char *data, size_t len, char *hex_out) {
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data, (CC_LONG)len, hash);
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        sprintf(hex_out + (i * 2), "%02x", hash[i]);
    }
    hex_out[64] = '\0';
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <output-dir>\n", argv[0]);
        return 1;
    }
    const char *out_dir = argv[1];

    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) != 0) {
        fprintf(stderr, "libusb_init error\n");
        return 1;
    }

    struct {
        uint8_t c, sc, p;
        const char *name;
        const char *path;
    } endpoints[] = {
        {0xff, 0x04, 0x01, "ProductStatusDyn.xml", "/DevMgmt/ProductStatusDyn.xml"},
        {0xff, 0x04, 0x01, "ConsumableConfigDyn.xml", "/DevMgmt/ConsumableConfigDyn.xml"},
        {0xff, 0x04, 0x01, "ProductUsageDyn.xml", "/DevMgmt/ProductUsageDyn.xml"},
        {0xff, 0x04, 0x01, "ProductConfigDyn.xml", "/DevMgmt/ProductConfigDyn.xml"},
        {0xff, 0x04, 0x01, "DiscoveryTree.xml", "/DevMgmt/DiscoveryTree.xml"},
        {0xff, 0x04, 0x01, "MediaCapabilities.xml", "/DevMgmt/MediaCapabilities.xml"},
        {0xff, 0xcc, 0x00, "ScannerStatus.xml", "/Scan/Status"},
        {0xff, 0xcc, 0x00, "ScannerCapabilities.xml", "/Scan/ScanCaps"}
    };
    int num_eps = sizeof(endpoints) / sizeof(endpoints[0]);

    static char resp[131072];
    char table_file[512];
    snprintf(table_file, sizeof(table_file), "%s/telemetry_inventory.txt", out_dir);
    FILE *tfp = fopen(table_file, "w");
    if (!tfp) {
        perror("Error creating telemetry_inventory.txt");
        libusb_exit(ctx);
        return 1;
    }

    fprintf(tfp, "# TELEMETRÍA LEDM Y CONSUMIBLES — EVIDENCIA HARDWARE REAL\n");
    fprintf(tfp, "# VID 0x03F0, PID 0x2B54, Serial CN1924S1W7\n");
    fprintf(tfp, "# Formato: Endpoint | HTTP Status | Bytes | Duración (ms) | SHA-256 | Archivo\n\n");

    printf("=========================================================================================================\n");
    printf("%-26s | %-11s | %-7s | %-12s | %-64s\n", "Endpoint", "HTTP Status", "Bytes", "Duración (ms)", "SHA-256");
    printf("---------------------------------------------------------------------------------------------------------\n");

    for (int i = 0; i < num_eps; i++) {
        usb_channel_t chan;
        usleep(250000); // 250ms delay between USB operations

        int n = -1;
        double duration_ms = 0.0;
        char req[512];
        snprintf(req, sizeof(req), "GET %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n", endpoints[i].path);

        for (int attempt = 0; attempt < 3; attempt++) {
            if (open_channel(ctx, endpoints[i].c, endpoints[i].sc, endpoints[i].p, &chan) != 0) {
                usleep(150000);
                continue;
            }
            n = http_request(&chan, req, resp, sizeof(resp), &duration_ms);
            close_channel(&chan);
            if (n > 0) break;
            usleep(200000);
        }

        if (n <= 0) {
            printf("%-26s | ERROR       | 0       | %-12.1f | -\n", endpoints[i].name, duration_ms);
            continue;
        }

        int http_code = 0;
        sscanf(resp, "HTTP/1.1 %d", &http_code);

        char out_path[512];
        snprintf(out_path, sizeof(out_path), "%s/%s", out_dir, endpoints[i].name);
        FILE *ofp = fopen(out_path, "wb");
        if (ofp) {
            fwrite(resp, 1, (size_t)n, ofp);
            fclose(ofp);
        }

        char sha_hex[65];
        compute_sha256((const unsigned char *)resp, (size_t)n, sha_hex);

        printf("%-26s | %-11d | %-7d | %-12.1f | %s\n",
               endpoints[i].name, http_code, n, duration_ms, sha_hex);
        fprintf(tfp, "%-26s | HTTP %-7d | %-7d | %-10.1f ms | %s | %s\n",
                endpoints[i].name, http_code, n, duration_ms, sha_hex, endpoints[i].name);
    }
    printf("=========================================================================================================\n");

    fclose(tfp);
    libusb_exit(ctx);
    return 0;
}
