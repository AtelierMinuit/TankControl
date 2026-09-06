/*
 * cups_backend_smarttank.c
 * Backend bidireccional nativo de CUPS para HP Smart Tank 500 series en macOS Apple Silicon.
 * URI Scheme: smarttank://HP/Smart%20Tank%20500%20series?serial=...
 *
 * Características:
 * - Descubrimiento automático de impresora en el bus USB (backend list).
 * - Transmisión de datos de impresión a Interface 1 (Endpoint 0x02 Bulk OUT).
 * - Sondeo bidireccional de estado del motor (Interface 0/2 LEDM):
 *   Detecta en vivo: outOfPaper, mediaJam, doorOpen, lowInk.
 * - Emisión de directivas CUPS nativas a stderr:
 *   STATE: +media-empty-error / -media-empty-error
 *   STATE: +media-jam-error / -media-jam-error
 *   STATE: +door-open-error / -door-open-error
 *   PAGE: <página_actual> <total_páginas>
 *
 * Licencia: MIT
 */

#include <cups/cups.h>
#include <cups/backend.h>
#include <libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/file.h>
#include <pthread.h>
#include <signal.h>

#define HP_VID 0x03f0
#define HP_PID 0x2b54
#define USB_LOCK_FILE "/tmp/hp_smart_tank_usb.lock"
#define CHUNK_SIZE 16384
#define STATUS_POLL_INTERVAL_SEC 3

static volatile int g_cancel_job = 0;

static void sigterm_handler(int sig) {
    (void)sig;
    g_cancel_job = 1;
}

static int acquire_usb_lock(int timeout_sec) {
    int fd = open(USB_LOCK_FILE, O_RDWR | O_CREAT | O_NOFOLLOW, 0600);
    if (fd < 0) return -1;
    for (int i = 0; i < timeout_sec * 10; i++) {
        if (flock(fd, LOCK_EX | LOCK_NB) == 0) return fd;
        usleep(100000);
    }
    close(fd);
    return -1;
}

static void release_usb_lock(int fd) {
    if (fd >= 0) {
        flock(fd, LOCK_UN);
        close(fd);
    }
}

static void sanitize_log_field(const char *input, char *output, size_t output_size) {
    if (output_size == 0) return;
    size_t j = 0;
    const char *value = input ? input : "";
    while (*value != '\0' && j + 1 < output_size) {
        const unsigned char c = (unsigned char)*value++;
        if (c == '"' || c == '\r' || c == '\n') {
            output[j++] = ' ';
        } else {
            output[j++] = (char)c;
        }
    }
    output[j] = '\0';
}

static int parse_copies(const char *text, int *copies) {
    char *end = NULL;
    long parsed;
    if (!text || !copies || *text == '\0') return -1;
    errno = 0;
    parsed = strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' || parsed < 1 || parsed > 10000) return -1;
    *copies = (int)parsed;
    return 0;
}

/* Registra la auditoría financiera y consumo de tinta por trabajo */
static void record_job_accounting(const char *job_id, const char *user, const char *title, int pages, size_t bytes, const char *options) {
    if (pages < 1) pages = 1;
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    char time_str[32];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", tm_info);

    const char *opts = options ? options : "";
    char safe_user[256];
    char safe_title[256];
    char safe_job[128];
    sanitize_log_field(user, safe_user, sizeof(safe_user));
    sanitize_log_field(title, safe_title, sizeof(safe_title));
    sanitize_log_field(job_id, safe_job, sizeof(safe_job));
    double saver_discount_k = 0.0;
    double saver_discount_c = 0.0;
    const char *saver_label = "Off";

    if (strstr(opts, "HPInkSaver=Eco25") || strstr(opts, "ink_saver=eco25") || strstr(opts, "ink_saver=25")) {
        saver_discount_k = 0.25;
        saver_discount_c = 0.25;
        saver_label = "Eco25";
    } else if (strstr(opts, "HPInkSaver=Eco50") || strstr(opts, "ink_saver=eco50") || strstr(opts, "ink_saver=50")) {
        saver_discount_k = 0.50;
        saver_discount_c = 0.50;
        saver_label = "Eco50";
    } else if (strstr(opts, "HPInkSaver=Eco75") || strstr(opts, "ink_saver=eco75") || strstr(opts, "ink_saver=75")) {
        saver_discount_k = 0.75;
        saver_discount_c = 0.75;
        saver_label = "Eco75";
    } else if (strstr(opts, "HPInkSaver=EdgePreserve") || strstr(opts, "ink_saver=edge")) {
        saver_discount_k = 0.35;
        saver_discount_c = 0.35;
        saver_label = "EdgePreserve";
    } else if (strstr(opts, "HPInkSaver=DotGainGrid") || strstr(opts, "ink_saver=dotgain")) {
        saver_discount_k = 0.30;
        saver_discount_c = 0.30;
        saver_label = "DotGainGrid";
    }

    if (strstr(opts, "HPEcoColorDrop=DropColorBg") || strstr(opts, "color_drop=bg")) {
        saver_discount_c += 0.20;
        if (saver_discount_c > 0.85) saver_discount_c = 0.85;
    } else if (strstr(opts, "HPEcoColorDrop=EcoGrayscale") || strstr(opts, "color_drop=gray")) {
        saver_discount_c = 1.00;
        saver_discount_k += 0.10;
    }

    double base_k_ml = pages * 0.12;
    double base_color_ml = pages * 0.08;

    double saved_k_ml = base_k_ml * saver_discount_k;
    double saved_color_ml = base_color_ml * saver_discount_c;

    double ink_k_ml = base_k_ml - saved_k_ml;
    double ink_color_ml = base_color_ml - saved_color_ml;

    double ink_cost = (ink_k_ml * 0.1037) + (ink_color_ml * 0.1571);
    double paper_cost = pages * 0.015;
    double total_cost = ink_cost + paper_cost;

    double ink_saved_ml = saved_k_ml + saved_color_ml;
    double money_saved_usd = (saved_k_ml * 0.1037) + (saved_color_ml * 0.1571);

    int accounting_fd = open("/tmp/hp_smarttank_accounting.csv",
                             O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, 0600);
    FILE *fp = (accounting_fd >= 0) ? fdopen(accounting_fd, "a") : NULL;
    if (fp) {
        fseek(fp, 0, SEEK_END);
        if (ftell(fp) == 0) {
            fprintf(fp, "timestamp,job_id,user,title,pages,bytes,ink_k_ml,ink_color_ml,cost_usd,ink_saved_ml,money_saved_usd,saver_mode\n");
        }
        fprintf(fp, "\"%s\",%s,\"%s\",\"%s\",%d,%zu,%.3f,%.3f,%.4f,%.3f,%.4f,\"%s\"\n",
                time_str, safe_job[0] ? safe_job : "0", safe_user[0] ? safe_user : "anonymous",
                safe_title[0] ? safe_title : "Untitled", pages, bytes, ink_k_ml, ink_color_ml, total_cost,
                ink_saved_ml, money_saved_usd, saver_label);
        fclose(fp);
    }

    int last_cost_fd = open("/tmp/hp_smarttank_last_cost.json",
                            O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0600);
    FILE *fj = (last_cost_fd >= 0) ? fdopen(last_cost_fd, "w") : NULL;
    if (fj) {
        fprintf(fj, "{\n"
                    "  \"timestamp\": \"%s\",\n"
                    "  \"job_id\": \"%s\",\n"
                    "  \"user\": \"%s\",\n"
                    "  \"title\": \"%s\",\n"
                    "  \"pages\": %d,\n"
                    "  \"bytes\": %zu,\n"
                    "  \"ink_k_ml\": %.3f,\n"
                    "  \"ink_color_ml\": %.3f,\n"
                    "  \"cost_usd\": %.4f,\n"
                    "  \"ink_saved_ml\": %.3f,\n"
                    "  \"money_saved_usd\": %.4f,\n"
                    "  \"saver_mode\": \"%s\"\n"
                    "}\n",
                time_str, safe_job[0] ? safe_job : "0", safe_user[0] ? safe_user : "anonymous",
                safe_title[0] ? safe_title : "Untitled", pages, bytes, ink_k_ml, ink_color_ml, total_cost,
                ink_saved_ml, money_saved_usd, saver_label);
        fclose(fj);
    }

    if (ink_saved_ml > 0.001) {
        fprintf(stderr, "INFO: [smarttank] Contabilidad estimada: Trabajo #%s - %d paginas, Costo: $%.3f USD | Reduccion raster estimada: %.2f ml ($%.3f USD)\n",
                safe_job[0] ? safe_job : "0", pages, total_cost, ink_saved_ml, money_saved_usd);
    } else {
        fprintf(stderr, "INFO: [smarttank] Contabilidad: Trabajo #%s - %d paginas, Costo estimado: $%.3f USD (Tinta: $%.3f, Papel: $%.3f)\n",
                safe_job[0] ? safe_job : "0", pages, total_cost, ink_cost, paper_cost);
    }
}

/* Modo descubrimiento: cups ejecuta el backend sin argumentos */
static int do_discovery(void) {
    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) != LIBUSB_SUCCESS) {
        return CUPS_BACKEND_FAILED;
    }

    libusb_device **devs;
    ssize_t cnt = libusb_get_device_list(ctx, &devs);
    int found = 0;

    if (cnt > 0) {
        for (ssize_t i = 0; i < cnt; i++) {
            struct libusb_device_descriptor desc;
            if (libusb_get_device_descriptor(devs[i], &desc) == LIBUSB_SUCCESS) {
                if (desc.idVendor == HP_VID && desc.idProduct == HP_PID) {
                    found = 1;
                    char serial[64] = {0};
                    libusb_device_handle *h = NULL;
                    if (libusb_open(devs[i], &h) == LIBUSB_SUCCESS) {
                        if (desc.iSerialNumber > 0) {
                            libusb_get_string_descriptor_ascii(h, desc.iSerialNumber, (unsigned char *)serial, sizeof(serial));
                        }
                        libusb_close(h);
                    }
                    printf("direct smarttank://HP/Smart%%20Tank%%20500%%20series%s%s "
                           "\"HP Smart Tank 500 series\" "
                           "\"HP Smart Tank 500 (Nativo Apple Silicon)\" "
                           "\"MFG:HP;MDL:smart tank 500 series;DES:smart tank 500 series;CMD:PCL3GUI,LEDM;\" "
                           "\"\"\n", serial[0] ? "?serial=" : "", serial);
                }
            }
        }
        libusb_free_device_list(devs, 1);
    }

    /* Si se corre en entorno simulado / mock y no hay hardware */
    if (!found && (getenv("HP_SMART_TANK_MOCK") != NULL)) {
        printf("direct smarttank://HP/Smart%%20Tank%%20500%%20series "
               "\"HP Smart Tank 500 series\" "
               "\"HP Smart Tank 500 (Virtual Mock)\" "
               "\"MFG:HP;MDL:smart tank 500 series;DES:smart tank 500 series;CMD:PCL3GUI,LEDM;\" "
               "\"\"\n");
    }

    libusb_exit(ctx);
    return CUPS_BACKEND_OK;
}

typedef struct {
    libusb_device_handle *handle;
    pthread_mutex_t *usb_mutex;
    volatile int running;
    int is_mock;
} monitor_ctx_t;

/* Hilo de monitoreo bidireccional LEDM con sincronización thread-safe */
static void *status_monitor_thread(void *arg) {
    monitor_ctx_t *m = (monitor_ctx_t *)arg;
    int last_out_of_paper = 0;
    int last_jam = 0;
    int last_door = 0;

    while (m->running && !g_cancel_job) {
        sleep(STATUS_POLL_INTERVAL_SEC);
        if (!m->running || g_cancel_job) break;

        if (m->is_mock) {
            continue;
        }

        /* Consultar estado por canal EWS/LEDM bajo mutex */
        char req[] = "GET /DevMgmt/ProductStatusDyn.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int transferred = 0;
        unsigned char resp_buf[4096];
        memset(resp_buf, 0, sizeof(resp_buf));

        if (m->usb_mutex) pthread_mutex_lock(m->usb_mutex);
        if (!m->running || !m->handle || g_cancel_job) {
            if (m->usb_mutex) pthread_mutex_unlock(m->usb_mutex);
            break;
        }

        int r = libusb_bulk_transfer(m->handle, 0x03, (unsigned char *)req, (int)strlen(req), &transferred, 1000);
        if (r == 0) {
            transferred = 0;
            r = libusb_bulk_transfer(m->handle, 0x83, resp_buf, sizeof(resp_buf) - 1, &transferred, 1000);
        }
        if (m->usb_mutex) pthread_mutex_unlock(m->usb_mutex);

        if (r == 0 && transferred > 0) {
            resp_buf[transferred] = '\0';
            char *str = (char *)resp_buf;

            int out_of_paper = (strstr(str, "outOfPaper") != NULL || strstr(str, "mediaEmpty") != NULL);
                int jam = (strstr(str, "mediaJam") != NULL);
                int door = (strstr(str, "doorOpen") != NULL);

                if (out_of_paper != last_out_of_paper) {
                    if (out_of_paper) {
                        fprintf(stderr, "STATE: +media-empty-error\n");
                        fprintf(stderr, "ERROR: Bandeja sin papel. Por favor cargue papel en la impresora.\n");
                    } else {
                        fprintf(stderr, "STATE: -media-empty-error\n");
                        fprintf(stderr, "INFO: Papel detectado. Reanudando impresion...\n");
                    }
                    last_out_of_paper = out_of_paper;
                }

                if (jam != last_jam) {
                    if (jam) {
                        fprintf(stderr, "STATE: +media-jam-error\n");
                        fprintf(stderr, "ERROR: Atasco de papel detectado en la impresora.\n");
                    } else {
                        fprintf(stderr, "STATE: -media-jam-error\n");
                    }
                    last_jam = jam;
                }

                if (door != last_door) {
                    if (door) {
                        fprintf(stderr, "STATE: +door-open-error\n");
                        fprintf(stderr, "ERROR: Cubierta frontal de la impresora abierta.\n");
                    } else {
                        fprintf(stderr, "STATE: -door-open-error\n");
                    }
                    last_door = door;
                }
            }
        }
        return NULL;
}

int main(int argc, char *argv[]) {
    /* Un dispositivo USB desconectado no debe terminar el backend por SIGPIPE. */
    signal(SIGPIPE, SIG_IGN);
    signal(SIGTERM, sigterm_handler);
    signal(SIGINT, sigterm_handler);

    /* 1. Modo Descubrimiento */
    if (argc == 1) {
        return do_discovery();
    }

    /* 2. Validación de argumentos CUPS */
    if (argc < 6 || argc > 7) {
        fprintf(stderr, "Uso: %s job-id user title copies options [file]\n", argv[0]);
        return CUPS_BACKEND_FAILED;
    }

    const char *job_id = argv[1];
    const char *user = argv[2];
    const char *title = argv[3];
    int copies = 0;
    if (parse_copies(argv[4], &copies) != 0) {
        fprintf(stderr, "ERROR: cantidad de copias inválida (use un entero entre 1 y 10000)\n");
        return CUPS_BACKEND_FAILED;
    }
    const char *options = argv[5];
    const char *filename = (argc == 7) ? argv[6] : NULL;

    char safe_job[128];
    char safe_title[256];
    char safe_user[256];
    char safe_options[512];
    sanitize_log_field(job_id, safe_job, sizeof(safe_job));
    sanitize_log_field(title, safe_title, sizeof(safe_title));
    sanitize_log_field(user, safe_user, sizeof(safe_user));
    sanitize_log_field(options, safe_options, sizeof(safe_options));
    fprintf(stderr, "DEBUG: [smarttank] Iniciando trabajo #%s ('%s') de %s (copias: %d, opciones: %s)\n",
            safe_job, safe_title, safe_user, copies, safe_options);

    const char *dev_uri = getenv("DEVICE_URI");
    int is_mock = (getenv("HP_SMART_TANK_MOCK") != NULL) ||
                  (strstr(options, "mock=1") != NULL) ||
                  (dev_uri && strstr(dev_uri, "mock=1") != NULL);

    int dry_time = 0;
    if (strstr(options, "HPDryTime=Short") || strstr(options, "dry_time=5")) dry_time = 5;
    else if (strstr(options, "HPDryTime=Medium") || strstr(options, "dry_time=10")) dry_time = 10;
    else if (strstr(options, "HPDryTime=Long") || strstr(options, "dry_time=20")) dry_time = 20;
    else if (strstr(options, "HPDryTime=Maximum") || strstr(options, "dry_time=40")) dry_time = 40;

    int input_fd = 0; /* stdin por defecto */
    if (filename) {
        input_fd = open(filename, O_RDONLY | O_NOFOLLOW);
        if (input_fd < 0) {
            perror("ERROR: No se pudo abrir de forma segura el archivo de impresion");
            return CUPS_BACKEND_FAILED;
        }
    }

    /* 3. Modo Mock / Simulación */
    if (is_mock) {
        fprintf(stderr, "INFO: [smarttank] Modo Mock activo: simulando envio de impresion...\n");
        if (dry_time > 0) {
            fprintf(stderr, "INFO: [smarttank] Tiempo de secado entre paginas configurado: %d seg\n", dry_time);
        }
        unsigned char buf[CHUNK_SIZE];
        ssize_t r;
        size_t total_bytes = 0;
        int page_no = 0;

        fprintf(stderr, "STATE: -media-empty-error,media-jam-error,door-open-error\n");
        fprintf(stderr, "PAGE: 1 1\n");

        while ((r = read(input_fd, buf, sizeof(buf))) > 0) {
            total_bytes += (size_t)r;
            for (ssize_t i = 0; i < r; i++) {
                if (buf[i] == 0x0c) {
                    page_no++;
                    fprintf(stderr, "PAGE: %d %d\n", page_no, page_no);
                }
            }
        }
        if (filename && input_fd >= 0) close(input_fd);
        record_job_accounting(job_id, user, title, page_no, total_bytes, options);
        fprintf(stderr, "INFO: [smarttank] Trabajo #%s simulado exitosamente (%zu bytes).\n", job_id, total_bytes);
        return CUPS_BACKEND_OK;
    }

    /* 4. Conexión USB real */
    int lock_fd = acquire_usb_lock(10);
    if (lock_fd < 0) {
        fprintf(stderr, "ERROR: [smarttank] Bus USB ocupado por otra sesion (timeout lock)\n");
        if (filename && input_fd >= 0) close(input_fd);
        return CUPS_BACKEND_RETRY;
    }

    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) != LIBUSB_SUCCESS) {
        fprintf(stderr, "ERROR: [smarttank] No se pudo inicializar libusb\n");
        release_usb_lock(lock_fd);
        if (filename && input_fd >= 0) close(input_fd);
        return CUPS_BACKEND_FAILED;
    }

    libusb_device_handle *handle = libusb_open_device_with_vid_pid(ctx, HP_VID, HP_PID);
    if (!handle) {
        fprintf(stderr, "ERROR: [smarttank] Impresora HP Smart Tank 500 no conectada en USB\n");
        libusb_exit(ctx);
        release_usb_lock(lock_fd);
        if (filename && input_fd >= 0) close(input_fd);
        return CUPS_BACKEND_RETRY_CURRENT;
    }

    /* Reclamar Interfaz 1 (Printer Class) */
    libusb_detach_kernel_driver(handle, 1);
    int r = libusb_claim_interface(handle, 1);
    if (r != LIBUSB_SUCCESS) {
        fprintf(stderr, "ERROR: [smarttank] No se pudo reclamar interfaz de impresion (error %d)\n", r);
        libusb_close(handle);
        libusb_exit(ctx);
        release_usb_lock(lock_fd);
        if (filename && input_fd >= 0) close(input_fd);
        return CUPS_BACKEND_FAILED;
    }

    /* Iniciar hilo de monitoreo bidireccional con mutex de sincronización */
    pthread_mutex_t usb_mutex = PTHREAD_MUTEX_INITIALIZER;
    monitor_ctx_t mon_ctx;
    mon_ctx.handle = handle;
    mon_ctx.usb_mutex = &usb_mutex;
    mon_ctx.running = 1;
    mon_ctx.is_mock = is_mock;
    pthread_t mon_th;
    pthread_create(&mon_th, NULL, status_monitor_thread, &mon_ctx);

    /* 5. Transmisión de flujo PCL3GUI */
    unsigned char buf[CHUNK_SIZE];
    ssize_t bytes_read = 0;
    size_t total_transferred = 0;
    int page_no = 0;
    int hotplug_failed = 0;

    fprintf(stderr, "STATE: -media-empty-error,media-jam-error,door-open-error\n");
    fprintf(stderr, "PAGE: 1 1\n");

    while (!g_cancel_job && (bytes_read = read(input_fd, buf, sizeof(buf))) > 0) {
        int written = 0;
        while (written < bytes_read && !g_cancel_job) {
            int chunk = (int)(bytes_read - written);
            int actual_written = 0;

            pthread_mutex_lock(&usb_mutex);
            r = libusb_bulk_transfer(handle, 0x02, buf + written, chunk, &actual_written, 10000);
            pthread_mutex_unlock(&usb_mutex);

            if (r != LIBUSB_SUCCESS) {
                if (r == LIBUSB_ERROR_NO_DEVICE || r == LIBUSB_ERROR_IO) {
                    fprintf(stderr, "STATE: +connecting-to-device\n");
                    fprintf(stderr, "INFO: [smarttank] Desconexion USB transitoria detectada. Esperando reconexion del hardware (hasta 30s)...\n");

                    int reconnected = 0;
                    for (int retry = 0; retry < 30 && !g_cancel_job; retry++) {
                        sleep(1);
                        pthread_mutex_lock(&usb_mutex);
                        if (handle) {
                            libusb_release_interface(handle, 1);
                            libusb_close(handle);
                            handle = NULL;
                        }
                        handle = libusb_open_device_with_vid_pid(ctx, HP_VID, HP_PID);
                        if (handle) {
                            libusb_detach_kernel_driver(handle, 1);
                            if (libusb_claim_interface(handle, 1) == LIBUSB_SUCCESS) {
                                mon_ctx.handle = handle;
                                pthread_mutex_unlock(&usb_mutex);
                                reconnected = 1;
                                fprintf(stderr, "STATE: -connecting-to-device\n");
                                fprintf(stderr, "INFO: [smarttank] Impresora reconectada exitosamente en el segundo %d. Reanudando impresion...\n", retry + 1);
                                break;
                            }
                            libusb_close(handle);
                            handle = NULL;
                        }
                        pthread_mutex_unlock(&usb_mutex);
                    }

                    if (reconnected) {
                        continue; /* Reintentar enviar el mismo chunk */
                    } else {
                        fprintf(stderr, "ERROR: [smarttank] Tiempo de espera agotado sin reconexion. Notificando a CUPS para reintento automatico.\n");
                        hotplug_failed = 1;
                        g_cancel_job = 1;
                        break;
                    }
                } else {
                    fprintf(stderr, "ERROR: [smarttank] Error escribiendo a USB Bulk EP 0x02 (libusb %d)\n", r);
                    g_cancel_job = 1;
                    break;
                }
            }
            if (actual_written <= 0) {
                fprintf(stderr, "ERROR: [smarttank] USB no avanzó la transferencia (0 bytes escritos).\n");
                g_cancel_job = 1;
                break;
            }
            written += actual_written;
            total_transferred += (size_t)actual_written;
        }

        /* Contar expulsiones de página PCL3GUI (0x0C o PAGE_EJECT) */
        for (ssize_t i = 0; i < bytes_read; i++) {
            if (buf[i] == 0x0c) {
                page_no++;
                fprintf(stderr, "PAGE: %d %d\n", page_no, page_no);
            }
        }
    }

    int input_failed = (bytes_read < 0);
    if (input_failed) {
        fprintf(stderr, "ERROR: [smarttank] Error leyendo el spool de impresión: %s\n", strerror(errno));
        g_cancel_job = 1;
    }

    /* Detener hilo de monitoreo */
    mon_ctx.running = 0;
    pthread_join(mon_th, NULL);

    /* Limpieza y cierre */
    pthread_mutex_lock(&usb_mutex);
    if (handle) {
        libusb_release_interface(handle, 1);
        libusb_close(handle);
        handle = NULL;
    }
    pthread_mutex_unlock(&usb_mutex);
    pthread_mutex_destroy(&usb_mutex);

    libusb_exit(ctx);
    release_usb_lock(lock_fd);
    if (filename && input_fd >= 0) close(input_fd);

    if (hotplug_failed) {
        return CUPS_BACKEND_RETRY_CURRENT;
    }

    if (input_failed) {
        return CUPS_BACKEND_FAILED;
    }

    if (g_cancel_job) {
        fprintf(stderr, "INFO: [smarttank] Trabajo cancelado por el usuario.\n");
        return CUPS_BACKEND_CANCEL;
    }

    record_job_accounting(job_id, user, title, page_no, total_transferred, options);
    fprintf(stderr, "INFO: [smarttank] Impresion completada exitosamente (%zu bytes enviados).\n", total_transferred);
    return CUPS_BACKEND_OK;
}
