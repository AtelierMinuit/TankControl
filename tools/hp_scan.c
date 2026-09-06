/*
 * hp_scan.c - Motor nativo de escaneo USB para HP Smart Tank 500 en macOS (Apple Silicon).
 * Protocolo: LEDM sobre USB Bulk (Interface 0: 0xff/0xcc/0x00)
 * Comunicación de sesión única (Single Session) garantizando sincronización exacta de buffers.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/file.h>
#include <libusb.h>

#define HP_VID 0x03f0
#define HP_PID 0x2b54
#define USB_LOCK_FILE "/tmp/hp_smart_tank_usb.lock"

static int acquire_usb_lock(int timeout_sec) {
    int fd = open(USB_LOCK_FILE, O_RDWR | O_CREAT | O_NOFOLLOW, 0600);
    if (fd < 0) return -1;

    for (int i = 0; i < timeout_sec * 10; i++) {
        if (flock(fd, LOCK_EX | LOCK_NB) == 0) {
            return fd;
        }
        usleep(100000); // 100ms
    }
    close(fd);
    return -1;
}

static void release_usb_lock(int lock_fd) {
    if (lock_fd >= 0) {
        flock(lock_fd, LOCK_UN);
        close(lock_fd);
    }
}

static int bulk_send_text(libusb_device_handle *h, unsigned char endpoint,
                          const char *text, int *transferred, unsigned int timeout_ms) {
    size_t length = strlen(text);
    if (length > (size_t)INT_MAX) return LIBUSB_ERROR_OVERFLOW;
    return libusb_bulk_transfer(h, endpoint, (unsigned char *)text, (int)length,
                                transferred, timeout_ms);
}

static void print_usage(const char *program) {
    printf("Uso: %s [archivo.jpg] [dpi] [gray|color] [x] [y] [ancho] [alto]\n", program);
    printf("Escanea mediante LEDM sobre USB; no ejecuta mantenimiento.\n");
}

static int parse_nonnegative_arg(const char *text, int *value) {
    char *end = NULL;
    long parsed;
    if (!text || !value || *text == '\0') return -1;
    errno = 0;
    parsed = strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' || parsed < 0 || parsed > INT_MAX) return -1;
    *value = (int)parsed;
    return 0;
}

static int read_http_response(libusb_device_handle *h, char *buf, int max_buf) {
    int total = 0;
    int complete = 0;
    memset(buf, 0, (size_t)max_buf);
    while (total < max_buf - 1) {
        int chunk = 0;
        int r = libusb_bulk_transfer(h, 0x81, (unsigned char *)buf + total, max_buf - 1 - total, &chunk, 2000);
        if (r == 0 && chunk > 0) {
            total += chunk;
            buf[total] = '\0';
            char *hdr_end = strstr(buf, "\r\n\r\n");
            if (hdr_end) {
                char *cl = strstr(buf, "Content-Length: ");
                if (cl) {
                    char *endptr = NULL;
                    errno = 0;
                    long len = strtol(cl + 16, &endptr, 10);
                    const long body_bytes = total - (long)(hdr_end + 4 - buf);
                    if (errno != 0 || endptr == cl + 16 || len < 0) return -1;
                    if (body_bytes >= len) {
                        complete = 1;
                        break;
                    }
                } else if (strstr(buf, "Transfer-Encoding: chunked") || strstr(buf, "Transfer-Encoding: Chunked")) {
                    if (strstr(buf, "\r\n0\r\n\r\n") != NULL ||
                        strstr(buf, "0\r\n\r\n") != NULL ||
                        strstr(buf, "</ScanStatus>") != NULL ||
                        strstr(buf, "</Jobs>") != NULL ||
                        strstr(buf, "</Job>") != NULL ||
                        strstr(buf, "</ScannerCapabilities>") != NULL) {
                        complete = 1;
                        break;
                    }
                } else {
                    fprintf(stderr, "[hp_scan] Respuesta HTTP sin Content-Length; se rechaza para evitar desincronización\n");
                    return -1;
                }
            }
        } else {
            break;
        }
    }
    return complete ? total : -1;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "hp_scan: requiere una ruta de salida explícita\n");
        print_usage(argv[0]);
        return 2;
    }
    if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        print_usage(argv[0]);
        return 0;
    }
    if (strcmp(argv[1], "--version") == 0) {
        puts("hp_scan 0.1.0-alpha");
        return 0;
    }
    const char *outfile = NULL;
    int resolution = 300;
    const char *raw_mode = "Color";
    int x_start = 0, y_start = 0, width = 0, height = 0;

    int pos = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--output") == 0 && i + 1 < argc) {
            outfile = argv[++i];
        } else if (strcmp(argv[i], "--resolution") == 0 && i + 1 < argc) {
            if (parse_nonnegative_arg(argv[++i], &resolution) != 0) {
                fprintf(stderr, "DPI inválido: debe ser un entero entre 75 y 1200\n");
                return 2;
            }
        } else if (strcmp(argv[i], "--mode") == 0 && i + 1 < argc) {
            raw_mode = argv[++i];
        } else if (strcmp(argv[i], "--x") == 0 && i + 1 < argc) {
            parse_nonnegative_arg(argv[++i], &x_start);
        } else if (strcmp(argv[i], "--y") == 0 && i + 1 < argc) {
            parse_nonnegative_arg(argv[++i], &y_start);
        } else if (strcmp(argv[i], "--width") == 0 && i + 1 < argc) {
            parse_nonnegative_arg(argv[++i], &width);
        } else if (strcmp(argv[i], "--height") == 0 && i + 1 < argc) {
            parse_nonnegative_arg(argv[++i], &height);
        } else if (argv[i][0] != '-') {
            if (pos == 0) outfile = argv[i];
            else if (pos == 1) parse_nonnegative_arg(argv[i], &resolution);
            else if (pos == 2) raw_mode = argv[i];
            else if (pos == 3) parse_nonnegative_arg(argv[i], &x_start);
            else if (pos == 4) parse_nonnegative_arg(argv[i], &y_start);
            else if (pos == 5) parse_nonnegative_arg(argv[i], &width);
            else if (pos == 6) parse_nonnegative_arg(argv[i], &height);
            pos++;
        }
    }

    if (!outfile) {
        fprintf(stderr, "Uso: %s <archivo-salida.jpg> [dpi] [modo] [x] [y] [ancho] [alto]\n", argv[0]);
        fprintf(stderr, "   o: %s --output <archivo.jpg> --resolution <dpi> --mode <Color|Gray>\n", argv[0]);
        return 2;
    }

    const char *colormode = (strcmp(raw_mode, "gray") == 0 || strcmp(raw_mode, "Grayscale8") == 0 || strcmp(raw_mode, "Gray") == 0) ? "Gray" : "Color";
    if (resolution < 75 || resolution > 1200) resolution = 300;

    /* Geometría de cama plana LEDM: estrictamente en espacio de coordenadas 1/300 pulgada (2550 x 3508).
       Si los argumentos provienen en píxeles (> 2550/3508), se escalan a coordenadas base 300. */
    const int MAX_LEDM_WIDTH = 2550;
    const int MAX_LEDM_HEIGHT = 3508;

    if (width > MAX_LEDM_WIDTH && resolution > 300) {
        width = (int)((long)width * 300 / resolution);
    }
    if (height > MAX_LEDM_HEIGHT && resolution > 300) {
        height = (int)((long)height * 300 / resolution);
    }
    if (x_start > MAX_LEDM_WIDTH && resolution > 300) {
        x_start = (int)((long)x_start * 300 / resolution);
    }
    if (y_start > MAX_LEDM_HEIGHT && resolution > 300) {
        y_start = (int)((long)y_start * 300 / resolution);
    }

    if (width <= 0 || width > MAX_LEDM_WIDTH) width = MAX_LEDM_WIDTH;
    if (height <= 0 || height > MAX_LEDM_HEIGHT) height = MAX_LEDM_HEIGHT;

    if (x_start < 0) x_start = 0;
    if (y_start < 0) y_start = 0;
    if (x_start >= MAX_LEDM_WIDTH) x_start = 0;
    if (y_start >= MAX_LEDM_HEIGHT) y_start = 0;
    if (x_start + width > MAX_LEDM_WIDTH) width = MAX_LEDM_WIDTH - x_start;
    if (y_start + height > MAX_LEDM_HEIGHT) height = MAX_LEDM_HEIGHT - y_start;

    printf("[hp_scan] Iniciando escaneo: Res=%d DPI, Modo=%s, Región=(%d,%d %dx%d) -> %s\n",
           resolution, colormode, x_start, y_start, width, height, outfile);

    int lock_fd = acquire_usb_lock(5);
    if (lock_fd < 0) {
        fprintf(stderr, "[hp_scan] Error: El bus USB está ocupado por otro proceso (impresión o consulta activa)\n");
        return 1;
    }

    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) != 0) {
        fprintf(stderr, "[hp_scan] Error inicializando libusb\n");
        return 1;
    }

    libusb_device_handle *h = libusb_open_device_with_vid_pid(ctx, HP_VID, HP_PID);
    if (!h) {
        fprintf(stderr, "[hp_scan] Error: Impresora HP Smart Tank 500 no detectada en USB\n");
        libusb_exit(ctx);
        release_usb_lock(lock_fd);
        return 1;
    }

    libusb_set_auto_detach_kernel_driver(h, 1);
    if (libusb_claim_interface(h, 0) != 0) {
        fprintf(stderr, "[hp_scan] Error reclamando interfaz 0 de escaneo\n");
        libusb_close(h);
        libusb_exit(ctx);
        release_usb_lock(lock_fd);
        return 1;
    }

    int ret = 1;

    /* 1. Drenar residuos de transacciones previas */
    unsigned char drain[4096];
    int trans = 0;
    int idle_reads = 0;
    /* A single timeout is insufficient on this device: stale responses can
       arrive shortly after the first empty read. Cap the flush at 2 seconds. */
    while (idle_reads < 20) {
        const int drain_rc = libusb_bulk_transfer(h, 0x81, drain, sizeof(drain), &trans, 100);
        if (drain_rc == 0 && trans > 0) {
            idle_reads = 0;
        } else if (drain_rc == LIBUSB_ERROR_TIMEOUT) {
            idle_reads++;
        } else {
            break;
        }
    }

    /* 1b. Sincronizar la sesión LEDM con una lectura segura de estado. Las
       variantes históricas del protocolo hacen este GET antes de crear jobs;
       consumir la respuesta evita mezclarla con el POST siguiente. */
    const char *status_req =
        "GET /Scan/Status HTTP/1.1\r\n"
        "Host: localhost\r\nUser-Agent: hp-smart-tank\r\n"
        "Accept: text/xml\r\nAccept-Language: en-us,en\r\n"
        "Accept-Charset: utf-8\r\nKeep-Alive: 20\r\n"
        "Proxy-Connection: keep-alive\r\nCookie: AccessCounter=new\r\n"
        "0\r\n\r\n";
    char status_buf[8192];
    int idle_ready = 0;
    for (int wait_cycle = 0; wait_cycle < 15; wait_cycle++) {
        if (bulk_send_text(h, 0x02, status_req, &trans, 3000) != 0) {
            fprintf(stderr, "[hp_scan] Error enviando preflight /Scan/Status\n");
            goto cleanup;
        }
        if (read_http_response(h, status_buf, sizeof(status_buf)) <= 0) {
            fprintf(stderr, "[hp_scan] Error leyendo preflight /Scan/Status\n");
            goto cleanup;
        }
        if (strstr(status_buf, "<ScannerState>Idle</ScannerState>") ||
            strstr(status_buf, "Idle")) {
            idle_ready = 1;
            break;
        }
        usleep(500000); // 500ms esperar que el carro mecánico retorne a posición de inicio
    }
    if (!idle_ready) {
        fprintf(stderr, "[hp_scan] Advertencia: El escáner aún no reporta estado Idle\n");
    }

    /* 2. Enviar petición para iniciar el trabajo de escaneo */
    char scan_xml[1024];
    snprintf(scan_xml, sizeof(scan_xml),
             "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n"
             "<ScanSettings xmlns=\"http://www.hp.com/schemas/imaging/con/cnx/scan/2008/08/19\">\r\n"
             "  <XResolution>%d</XResolution>\r\n"
             "  <YResolution>%d</YResolution>\r\n"
             "  <XStart>%d</XStart>\r\n"
             "  <Width>%d</Width>\r\n"
             "  <YStart>%d</YStart>\r\n"
             "  <Height>%d</Height>\r\n"
             "  <Format>Jpeg</Format>\r\n"
             "  <CompressionQFactor>15</CompressionQFactor>\r\n"
             "  <ColorSpace>%s</ColorSpace>\r\n"
             "  <BitDepth>8</BitDepth>\r\n"
             "  <InputSource>Platen</InputSource>\r\n"
             "  <ContentType>Photo</ContentType>\r\n"
             "</ScanSettings>\r\n",
             resolution, resolution, x_start, width, y_start, height, colormode);

    char post_req[2048];
    snprintf(post_req, sizeof(post_req),
             "POST /Scan/Jobs HTTP/1.1\r\n"
             "Host: localhost\r\nUser-Agent: hp-smart-tank\r\n"
             "Accept: text/plain, */*\r\nContent-Type: text/xml; charset=UTF-8\r\n"
             "X-Requested-With: XMLHttpRequest\r\nContent-Length: %zu\r\n"
             "Cookie: AccessCounter=new\r\nPragma: no-cache\r\n"
             "Cache-Control: no-cache\r\n\r\n%s\r\n0\r\n\r\n",
             strlen(scan_xml), scan_xml);

    if (bulk_send_text(h, 0x02, post_req, &trans, 3000) != 0) {
        fprintf(stderr, "[hp_scan] Error enviando POST /Scan/Jobs al hardware\n");
        goto cleanup;
    }

    char buf[16384];
    read_http_response(h, buf, sizeof(buf));

    char job_url[256] = {0};
    char *loc = strstr(buf, "Location: ");
    if (!loc) {
        fprintf(stderr, "[hp_scan] Error: Respuesta inesperada del hardware:\n%s\n", buf);
        goto cleanup;
    }
    sscanf(loc, "Location: %255[^\r\n]", job_url);

    char *job_path = strstr(job_url, "/Jobs/");
    if (!job_path) job_path = strstr(job_url, "/Scan/");
    if (!job_path) job_path = job_url;
    printf("[hp_scan] Trabajo de escaneo activo: %s\n", job_path);

    /* 3. Polling de adquisición de imagen */
    char poll_req[512];
    snprintf(poll_req, sizeof(poll_req),
             "GET %s HTTP/1.1\r\nHost: localhost\r\nUser-Agent: hp-smart-tank\r\n"
             "Accept: text/plain\r\nX-Requested-With: XMLHttpRequest\r\n"
             "Cookie: AccessCounter=new\r\n0\r\n\r\n", job_path);

    char binary_url[256] = {0};
    printf("[hp_scan] Digitalizando documento");
    fflush(stdout);

    int max_retries = (resolution >= 600) ? 90 : 45;
    for (int retry = 0; retry < max_retries; retry++) {
        sleep(1);
        if (bulk_send_text(h, 0x02, poll_req, &trans, 2000) != 0) {
            fprintf(stderr, "\n[hp_scan] Error enviando consulta de estado del trabajo\n");
            goto cleanup;
        }
        read_http_response(h, buf, sizeof(buf));
        if (strstr(buf, "ReadyToUpload")) {
            char *b_ptr = strstr(buf, "<BinaryURL>");
            if (b_ptr) sscanf(b_ptr, "<BinaryURL>%255[^<]", binary_url);
            printf("\n[hp_scan] ¡Digitalización completada en hardware!\n");
            break;
        }
        printf(".");
        fflush(stdout);
    }

    if (binary_url[0] == '\0') {
        fprintf(stderr, "\n[hp_scan] Error: Timeout esperando ReadyToUpload del escáner\n");
        goto cleanup;
    }

    char *bin_path = strstr(binary_url, "/Scan/");
    if (!bin_path) bin_path = strstr(binary_url, "/Jobs/");
    if (!bin_path) bin_path = binary_url;

    printf("[hp_scan] Descargando imagen desde: %s\n", bin_path);
    char get_bin[512];
    snprintf(get_bin, sizeof(get_bin),
             "GET %s HTTP/1.1\r\nHost: localhost\r\nUser-Agent: hp-smart-tank\r\n"
             "Accept: image/jpeg\r\nCookie: AccessCounter=new\r\n0\r\n\r\n", bin_path);
    if (bulk_send_text(h, 0x02, get_bin, &trans, 3000) != 0) {
        fprintf(stderr, "[hp_scan] Error solicitando la imagen escaneada\n");
        goto cleanup;
    }

    int out_fd = open(outfile, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0600);
    if (out_fd < 0) {
        perror("[hp_scan] Error abriendo archivo destino");
        goto cleanup;
    }
    FILE *fp = fdopen(out_fd, "wb");
    if (!fp) {
        perror("[hp_scan] Error preparando archivo destino");
        close(out_fd);
        goto cleanup;
    }

    int total_bytes = 0, stripped = 0;
    unsigned char raw[65536];

    int eoi_found = 0;
    int write_failed = 0;
    int timeouts = 0;
    while (!eoi_found) {
        int rbytes = 0;
        int r = libusb_bulk_transfer(h, 0x81, raw, sizeof(raw), &rbytes, 3000);
        if (r == 0 && rbytes > 0) {
            timeouts = 0;
            int write_start = 0;
            int write_len = rbytes;
            if (!stripped) {
                int start = -1;
                for (int i = 0; i < rbytes - 1; i++) {
                    if (raw[i] == 0xFF && raw[i+1] == 0xD8) { start = i; break; }
                }
                if (start >= 0) {
                    stripped = 1;
                    write_start = start;
                    write_len = rbytes - start;
                } else {
                    continue;
                }
            }

            for (int i = write_start; i < rbytes - 1; i++) {
                if (raw[i] == 0xFF && raw[i+1] == 0xD9) {
                    write_len = (i + 2) - write_start;
                    eoi_found = 1;
                    break;
                }
            }

            size_t written = fwrite(raw + write_start, 1, (size_t)write_len, fp);
            if (written != (size_t)write_len) {
                write_failed = 1;
                break;
            }
            total_bytes += write_len;
        } else if (r == LIBUSB_ERROR_TIMEOUT) {
            timeouts++;
            if (timeouts > 10) {
                break;
            }
        } else {
            break;
        }
    }
    if (fclose(fp) != 0) write_failed = 1;
    if (!eoi_found || write_failed || total_bytes < 4) {
        fprintf(stderr, "[hp_scan] Imagen JPEG incompleta o no válida; no se declara escaneo completado\n");
        ret = 1;
        goto cleanup;
    }
    printf("[hp_scan] Escaneo completado; %d bytes guardados en %s\n", total_bytes, outfile);
    ret = 0;

cleanup:
    if (h) {
        libusb_release_interface(h, 0);
        libusb_close(h);
    }
    if (ctx) libusb_exit(ctx);
    release_usb_lock(lock_fd);
    return ret;
}
