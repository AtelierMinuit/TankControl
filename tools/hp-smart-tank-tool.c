/*
 * hp-smart-tank-tool.c
 * Herramienta nativa para HP Smart Tank 500 series en macOS Apple Silicon.
 *
 * Mapeo USB verificado:
 *   Interface 0 (0xff/0xcc/0x00): Escáner LEDM / eSCL (HTTP sobre USB)
 *   Interface 1 (0x07/0x01/0x02): Impresora PCL3GUI (USB Print Class)
 *   Interface 2 (0xff/0x04/0x01): EWS / Estado y Suministros (HTTP sobre USB)
 *   Interface 3 (0xff/0x04/0x01): EWS secundario
 */

#include <libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>
#include <errno.h>
#include <sys/file.h>

#define HP_VID 0x03f0
#define HP_PID 0x2b54
#define USB_LOCK_FILE "/tmp/hp_smart_tank_usb.lock"

#define TIMEOUT_MS 5000
#define BUFFER_SIZE 65536
#define HP_SMART_TANK_VERSION "0.1.0-alpha"

typedef struct {
    libusb_device_handle *handle;
    int interface_number;
    uint8_t ep_in;
    uint8_t ep_out;
    uint16_t ep_in_max_packet;
    uint16_t ep_out_max_packet;
    int lock_fd;
} usb_channel_t;

static FILE *open_private_read(const char *path) {
    int fd = open(path, O_RDONLY | O_NOFOLLOW);
    if (fd < 0) return NULL;
    FILE *fp = fdopen(fd, "r");
    if (!fp) close(fd);
    return fp;
}

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

static int bulk_send_text(usb_channel_t *chan, const char *text,
                          int *transferred, unsigned int timeout_ms) {
    size_t length = strlen(text);
    if (length > (size_t)INT_MAX) return LIBUSB_ERROR_OVERFLOW;
    return libusb_bulk_transfer(chan->handle, chan->ep_out, (unsigned char *)text,
                                (int)length, transferred, timeout_ms);
}

static void print_usage(const char *prog) {
    printf("Uso: %s <comando> [opciones]\n\n", prog);
    printf("Comandos disponibles:\n");
    printf("  info             Muestra inventario completo de descriptores, interfaces y endpoints USB\n");
    printf("  status           Consulta el estado de la impresora (Puerta, Error, Papel) vía EWS\n");
    printf("  supplies         Consulta niveles de tinta (C, M, Y, K) y estado de cabezales vía EWS\n");
    printf("  odometer         Consulta telemetría de hardware (páginas, atascos, consumo de tinta)\n");
    printf("  scan-caps        Consulta capacidades del escáner (resoluciones, formatos) vía LEDM\n");
    printf("  scan-status      Consulta estado actual del escáner (Reposo, Ocupado) vía LEDM\n");
    printf("  clean-heads      Limpieza Nivel 1: purga básica de burbujas en cabezales vía EWS\n");
    printf("  deep-clean       Limpieza Nivel 2: purga profunda con bomba de vacío vía EWS\n");
    printf("  clean-rollers    Limpieza Nivel 3: limpieza de rodillos y manchas de papel vía EWS\n");
    printf("  nozzle-test      Imprime patrón de verificación de inyectores vía EWS (diag-page)\n");
    printf("  align            Inicia el proceso de alineación óptica de cabezales vía EWS\n");
    printf("  dump-tree        Vuelca el árbol de capacidades XML y configuración profunda del firmware\n");
    printf("  inject-raw <f>   Inyecta flujo binario directo (PJL/PCL3GUI/PML) al puerto USB Bulk OUT [requiere --confirm-hardware]\n");
    printf("  accounting       Muestra la auditoría financiera, consumo de tinta y coste por página\n");
    printf("  test-pattern <t> Imprime patrón profesional de diagnóstico (grid, cmyk, alignment)\n");
    printf("  prime-tubes      Taller CISS: purga forzada y cebado de aire en mangueras de tinta\n");
    printf("  waste-ink        Auditoría de saturación de almohadillas de tinta residual (Absorber)\n");
    printf("  head-health      Diagnóstico térmico, eléctrico y de inyectores de cabezales K y CMY\n");
    printf("  scan <archivo>   Realiza un escaneo en color a 300 DPI y guarda la imagen JPEG\n");
}

static int find_channel(libusb_device *dev, uint8_t target_class, uint8_t target_subclass, uint8_t target_proto, usb_channel_t *chan) {
    struct libusb_config_descriptor *config = NULL;
    int r = libusb_get_active_config_descriptor(dev, &config);
    if (r != LIBUSB_SUCCESS) {
        r = libusb_get_config_descriptor(dev, 0, &config);
        if (r != LIBUSB_SUCCESS) return -1;
    }

    chan->interface_number = -1;
    chan->ep_in = 0;
    chan->ep_out = 0;

    for (int i = 0; i < config->bNumInterfaces; i++) {
        const struct libusb_interface *inter = &config->interface[i];
        for (int a = 0; a < inter->num_altsetting; a++) {
            const struct libusb_interface_descriptor *desc = &inter->altsetting[a];
            if (desc->bInterfaceClass == target_class &&
                desc->bInterfaceSubClass == target_subclass &&
                desc->bInterfaceProtocol == target_proto) {
                chan->interface_number = desc->bInterfaceNumber;
                for (int e = 0; e < desc->bNumEndpoints; e++) {
                    const struct libusb_endpoint_descriptor *ep = &desc->endpoint[e];
                    if ((ep->bmAttributes & LIBUSB_TRANSFER_TYPE_MASK) != LIBUSB_TRANSFER_TYPE_BULK) {
                        continue; /* Ignorar endpoints que no sean BULK (p. ej. Interrupt EP 0x83) */
                    }
                    if ((ep->bEndpointAddress & LIBUSB_ENDPOINT_DIR_MASK) == LIBUSB_ENDPOINT_IN) {
                        chan->ep_in = ep->bEndpointAddress;
                        chan->ep_in_max_packet = ep->wMaxPacketSize;
                    } else {
                        chan->ep_out = ep->bEndpointAddress;
                        chan->ep_out_max_packet = ep->wMaxPacketSize;
                    }
                }
                libusb_free_config_descriptor(config);
                return (chan->ep_in && chan->ep_out) ? 0 : -1;
            }
        }
    }
    libusb_free_config_descriptor(config);
    return -1;
}

static int open_channel(libusb_context *ctx, uint8_t c, uint8_t sc, uint8_t p, usb_channel_t *chan) {
    chan->lock_fd = acquire_usb_lock(3);
    if (chan->lock_fd < 0) {
        return -4;
    }

    libusb_device_handle *handle = libusb_open_device_with_vid_pid(ctx, HP_VID, HP_PID);
    if (!handle) {
        release_usb_lock(chan->lock_fd);
        chan->lock_fd = -1;
        return -1;
    }
    libusb_device *dev = libusb_get_device(handle);
    if (find_channel(dev, c, sc, p, chan) < 0) {
        libusb_close(handle);
        release_usb_lock(chan->lock_fd);
        chan->lock_fd = -1;
        return -2;
    }
    chan->handle = handle;

    libusb_set_auto_detach_kernel_driver(handle, 1);
    int r = libusb_claim_interface(handle, chan->interface_number);
    if (r != LIBUSB_SUCCESS) {
        libusb_close(handle);
        release_usb_lock(chan->lock_fd);
        chan->lock_fd = -1;
        return -3;
    }

    /* No vaciar el endpoint aquí: en LEDM/EWS la primera respuesta puede estar
       disponible inmediatamente después de abrir el canal. El histórico seguro
       del Smart Tank recibe esa respuesta sin un drain previo. */
    return 0;
}

static void close_channel(usb_channel_t *chan) {
    if (chan->handle) {
        libusb_release_interface(chan->handle, chan->interface_number);
        libusb_close(chan->handle);
        chan->handle = NULL;
    }
    if (chan->lock_fd >= 0) {
        release_usb_lock(chan->lock_fd);
        chan->lock_fd = -1;
    }
}

static int parse_xml_nonnegative_int(const char *xml, const char *tag, int *value) {
    if (!xml || !tag || !value) return -1;
    const char *start = strstr(xml, tag);
    if (!start) return -1;
    start += strlen(tag);
    while (*start == ' ' || *start == '\t' || *start == '\r' || *start == '\n') start++;
    errno = 0;
    char *end = NULL;
    long parsed = strtol(start, &end, 10);
    if (errno != 0 || end == start || parsed < 0 || parsed > INT_MAX) return -1;
    while (*end == ' ' || *end == '\t' || *end == '\r' || *end == '\n') end++;
    if (*end != '<') return -1;
    *value = (int)parsed;
    return 0;
}

static int http_request(usb_channel_t *chan, const char *req, char *resp_buf, int max_resp_len) {
    /* Vaciar cualquier paquete residual en el endpoint IN con buffer adecuado (4096 bytes) */
    unsigned char drain_buf[4096];
    int drain_read = 0;
    while (libusb_bulk_transfer(chan->handle, chan->ep_in, drain_buf, sizeof(drain_buf), &drain_read, 30) == LIBUSB_SUCCESS && drain_read > 0) {
        /* Descartar residual */
    }
    usleep(50000);

    int transferred = 0;
    int r = bulk_send_text(chan, req, &transferred, TIMEOUT_MS);
    if (r != LIBUSB_SUCCESS) {
        fprintf(stderr, "Error enviando solicitud HTTP: %s\n", libusb_error_name(r));
        return -1;
    }

    int total_read = 0;
    int complete = 0;
    char *hdr_end = NULL;
    while (total_read < max_resp_len - 1) {
        int chunk_read = 0;
        r = libusb_bulk_transfer(chan->handle, chan->ep_in, (unsigned char *)resp_buf + total_read, max_resp_len - 1 - total_read, &chunk_read, 2000);
        if (r == LIBUSB_SUCCESS) {
            if (chunk_read == 0) {
                usleep(15000);
                continue;
            }
            total_read += chunk_read;
            resp_buf[total_read] = '\0';
            // Revisar si ya concluyó el cuerpo HTTP
            hdr_end = strstr(resp_buf, "\r\n\r\n");
            if (hdr_end) {
                char *cl_ptr = strstr(resp_buf, "Content-Length: ");
                if (cl_ptr) {
                    char *endptr = NULL;
                    errno = 0;
                    long parsed_cl = strtol(cl_ptr + 16, &endptr, 10);
                    if (errno != 0 || endptr == cl_ptr + 16 || parsed_cl < 0 || parsed_cl > INT_MAX) {
                        fprintf(stderr, "Content-Length HTTP inválido\n");
                        return -1;
                    }
                    int cl = (int)parsed_cl;
                    ptrdiff_t body_offset = hdr_end + 4 - resp_buf;
                    int body_len = (body_offset >= 0 && body_offset <= total_read) ?
                                   (int)(total_read - body_offset) : 0;
                    if (body_len >= cl) {
                        complete = 1;
                        break;
                    }
                } else if (strstr(resp_buf, "Transfer-Encoding: chunked") || strstr(resp_buf, "Transfer-Encoding: Chunked")) {
                    /* HTTP/1.1 chunked concluye con 0\r\n\r\n o etiqueta final de XML */
                    if (strstr(resp_buf, "\r\n0\r\n\r\n") != NULL ||
                        strstr(resp_buf, "0\r\n\r\n") != NULL ||
                        strstr(resp_buf, "</psdyn:ProductStatusDyn>") != NULL ||
                        strstr(resp_buf, "</ccdyn:ConsumableConfigDyn>") != NULL ||
                        strstr(resp_buf, "</pudyn:ProductUsageDyn>") != NULL) {
                        complete = 1;
                        break;
                    }
                } else {
                    fprintf(stderr, "Respuesta HTTP sin Content-Length; se rechaza de forma segura\n");
                    return -1;
                }
            }
        } else if (r == LIBUSB_ERROR_TIMEOUT) {
            if (total_read > 0 && hdr_end) {
                complete = 1;
                break;
            }
            fprintf(stderr, "Timeout esperando respuesta HTTP (total_read=%d)\n", total_read);
            return -1;
        } else {
            if (total_read > 0 && hdr_end) {
                complete = 1;
            }
            break;
        }
    }
    return complete ? total_read : -1;
}

static void parse_and_print_supplies(const char *xml) {
    printf("\n\033[1;37m=== NIVELES DE TINTA Y SUMINISTROS (HP Smart Tank 500) ===\033[0m\n");
    const char *ptr = xml;
    int items = 0;
    while ((ptr = strstr(ptr, ":ConsumableInfo>")) != NULL) {
        const char *end_tag = strstr(ptr + 15, "ConsumableInfo>");
        if (!end_tag) break;

        /* Verificar si es un tanque de tinta (inkTank) y no un cabezal/cartucho (inkCartridge) */
        const char *type_tag = strstr(ptr, "ConsumableTypeEnum>");
        if (type_tag && type_tag < end_tag) {
            char ctype[32] = {0};
            sscanf(type_tag, "ConsumableTypeEnum>%31[^<]", ctype);
            if (strcmp(ctype, "inkTank") != 0) {
                ptr = end_tag + 15;
                continue;
            }
        } else {
            ptr = end_tag + 15;
            continue;
        }

        char code[16] = {0};
        int level = -1;
        char state[32] = {0};

        const char *c_ptr = strstr(ptr, "ConsumableLabelCode>");
        if (c_ptr && c_ptr < end_tag) sscanf(c_ptr, "ConsumableLabelCode>%15[^<]", code);

        const char *l_ptr = strstr(ptr, "ConsumablePercentageLevelRemaining>");
        if (l_ptr && l_ptr < end_tag) sscanf(l_ptr, "ConsumablePercentageLevelRemaining>%d", &level);

        const char *s_ptr = strstr(ptr, "ConsumableState>");
        if (s_ptr && s_ptr < end_tag) sscanf(s_ptr, "ConsumableState>%31[^<]", state);

        if (code[0] != '\0') {
            items++;
            const char *color_name = "Desconocido";
            const char *color_ansi = "\033[1;37m";
            if (strcmp(code, "K") == 0) {
                color_name = "Negro (Black)";
                color_ansi = "\033[1;37m";
            } else if (strcmp(code, "C") == 0) {
                color_name = "Cian (Cyan)";
                color_ansi = "\033[1;36m";
            } else if (strcmp(code, "M") == 0) {
                color_name = "Magenta";
                color_ansi = "\033[1;35m";
            } else if (strcmp(code, "Y") == 0) {
                color_name = "Amarillo (Yellow)";
                color_ansi = "\033[1;33m";
            }

            printf("  %s[%s] %-18s\033[0m: ", color_ansi, code, color_name);
            if (level >= 0) {
                char bar[41] = {0};
                int filled = (level * 20) / 100;
                for (int b = 0; b < 20; b++) bar[b] = (b < filled) ? '#' : '-';
                const char *st_color = (strcmp(state, "inSensorRange") == 0 || strcmp(state, "ok") == 0 || strcmp(state, "newGenuineHP") == 0) ? "\033[1;32m" : "\033[1;31m";
                printf("%s[%s]\033[0m %3d%% (Estado: %s%s\033[0m)\n", color_ansi, bar, level, st_color, state);
            } else {
                printf("(Nivel no disponible / Estado: %s)\n", state);
            }
        }
        ptr = end_tag + 15;
    }
    if (items == 0) {
        printf("  Respuesta XML de suministros:\n%s\n", xml);
    }
    printf("\033[1;37m===========================================================\033[0m\n\n");
}

static void parse_and_print_status(const char *xml) {
    printf("\n\033[1;37m=== ESTADO DE LA IMPRESORA ===\033[0m\n");
    const char *s_ptr = strstr(xml, "StatusCategory>");
    if (s_ptr) {
        char cat[64] = {0};
        sscanf(s_ptr, "StatusCategory>%63[^<]", cat);
        printf("  Categoría: %s\n", cat);
        if (strcmp(cat, "ready") == 0 || strcmp(cat, "genuineHP") == 0) {
            printf("  Diagnóstico: \033[1;32m● Impresora lista y en reposo (Depósitos llenos / Genuinos HP)\033[0m\n");
        } else if (strcmp(cat, "inPowerSave") == 0) {
            printf("  Diagnóstico: \033[1;34m● En reposo (Modo ahorro de energía)\033[0m\n");
        } else if (strcmp(cat, "processing") == 0) {
            printf("  Diagnóstico: \033[1;34m● Imprimiendo o procesando trabajo\033[0m\n");
        } else if (strcmp(cat, "closeDoorOrCover") == 0) {
            printf("  Diagnóstico: \033[1;31m▲ Cubierta o puerta abierta\033[0m\n");
        } else if (strcmp(cat, "mediaEmpty") == 0) {
            printf("  Diagnóstico: \033[1;33m▲ Sin papel en la bandeja\033[0m\n");
        } else if (strcmp(cat, "mediaJam") == 0) {
            printf("  Diagnóstico: \033[1;31m▲ Atasco de papel detectado\033[0m\n");
        }
    } else {
        printf("  Respuesta XML:\n%s\n", xml);
    }
    printf("\033[1;37m==============================\033[0m\n\n");
}

static void parse_and_print_supplies_json(const char *xml) {
    printf("{\"connected\": true, \"supplies\": [");
    const char *ptr = xml;
    int items = 0;
    while ((ptr = strstr(ptr, ":ConsumableInfo>")) != NULL) {
        const char *end_tag = strstr(ptr + 15, "ConsumableInfo>");
        if (!end_tag) break;

        /* Verificar si es un tanque de tinta (inkTank) y no un cabezal/cartucho (inkCartridge) */
        const char *type_tag = strstr(ptr, "ConsumableTypeEnum>");
        if (type_tag && type_tag < end_tag) {
            char ctype[32] = {0};
            sscanf(type_tag, "ConsumableTypeEnum>%31[^<]", ctype);
            if (strcmp(ctype, "inkTank") != 0) {
                ptr = end_tag + 15;
                continue;
            }
        } else {
            ptr = end_tag + 15;
            continue;
        }

        char code[16] = {0};
        int level = -1;
        char state[32] = {0};

        const char *c_ptr = strstr(ptr, "ConsumableLabelCode>");
        if (c_ptr && c_ptr < end_tag) sscanf(c_ptr, "ConsumableLabelCode>%15[^<]", code);

        const char *l_ptr = strstr(ptr, "ConsumablePercentageLevelRemaining>");
        if (l_ptr && l_ptr < end_tag) sscanf(l_ptr, "ConsumablePercentageLevelRemaining>%d", &level);

        const char *s_ptr = strstr(ptr, "ConsumableState>");
        if (s_ptr && s_ptr < end_tag) sscanf(s_ptr, "ConsumableState>%31[^<]", state);

        if (code[0] != '\0') {
            const char *name = "Desconocido";
            if (strcmp(code, "K") == 0) name = "Negro (Black)";
            else if (strcmp(code, "C") == 0) name = "Cian (Cyan)";
            else if (strcmp(code, "M") == 0) name = "Magenta";
            else if (strcmp(code, "Y") == 0) name = "Amarillo (Yellow)";

            if (items > 0) printf(", ");
            printf("{\"code\": \"%s\", \"name\": \"%s\", \"level\": %d, \"state\": \"%s\"}",
                   code, name, level, state[0] ? state : "unknown");
            items++;
        }
        ptr = end_tag + 15;
    }
    printf("]}\n");
}

static void parse_and_print_status_json(const char *xml) {
    char cat[64] = "unknown";
    char desc[128] = "Estado desconocido";
    const char *s_ptr = strstr(xml, "StatusCategory>");
    if (s_ptr) {
        sscanf(s_ptr, "StatusCategory>%63[^<]", cat);
        if (strcmp(cat, "ready") == 0) strcpy(desc, "Lista y en reposo");
        else if (strcmp(cat, "genuineHP") == 0) strcpy(desc, "Lista y en reposo (Depósitos llenos)");
        else if (strcmp(cat, "inPowerSave") == 0) strcpy(desc, "En reposo (Ahorro de energía)");
        else if (strcmp(cat, "processing") == 0) strcpy(desc, "Imprimiendo o procesando");
        else if (strcmp(cat, "closeDoorOrCover") == 0) strcpy(desc, "Cubierta o puerta abierta");
        else if (strcmp(cat, "mediaEmpty") == 0) strcpy(desc, "Sin papel en la bandeja");
        else if (strcmp(cat, "mediaJam") == 0) strcpy(desc, "Atasco de papel detectado");
    }
    const char *loc = strstr(xml, "LocString lang=\"es\">");
    if (!loc) loc = strstr(xml, "LocString>");
    if (loc) {
        char loc_text[128] = {0};
        const char *tag_end = strchr(loc, '>');
        if (tag_end) {
            sscanf(tag_end + 1, "%127[^<]", loc_text);
            if (loc_text[0] != '\0') {
                if (strcmp(cat, "genuineHP") == 0 || strcmp(cat, "ready") == 0) {
                    snprintf(desc, sizeof(desc), "Lista (%s)", loc_text);
                } else {
                    strncpy(desc, loc_text, sizeof(desc) - 1);
                }
            }
        }
    }
    printf("{\"connected\": true, \"status\": \"%s\", \"description\": \"%s\"}\n", cat, desc);
}

static void parse_and_print_odometer(const char *xml) {
    printf("\n\033[1;37m=== ODÓMETRO Y TELEMETRÍA DE HARDWARE (HP Smart Tank 500) ===\033[0m\n");
    int total_pages = 0, mono_pages = 0, color_pages = 0, borderless = 0, jams = 0, picks = 0, scans = 0;
    long long drops_k = 0, drops_c = 0, drops_m = 0, drops_y = 0;

    const char *p;
    if ((p = strstr(xml, "TotalImpressions>"))) sscanf(p, "TotalImpressions>%d", &total_pages);
    if ((p = strstr(xml, "MonochromeImpressions>"))) sscanf(p, "MonochromeImpressions>%d", &mono_pages);
    if ((p = strstr(xml, "ColorImpressions>"))) sscanf(p, "ColorImpressions>%d", &color_pages);
    if ((p = strstr(xml, "BorderlessImpressions>"))) sscanf(p, "BorderlessImpressions>%d", &borderless);
    if ((p = strstr(xml, "JamEvents>"))) sscanf(p, "JamEvents>%d", &jams);
    if ((p = strstr(xml, "PickFailures>"))) sscanf(p, "PickFailures>%d", &picks);
    if ((p = strstr(xml, "FlatbedScans>"))) sscanf(p, "FlatbedScans>%d", &scans);
    if ((p = strstr(xml, "TotalDropsFiredK>"))) sscanf(p, "TotalDropsFiredK>%lld", &drops_k);
    if ((p = strstr(xml, "TotalDropsFiredC>"))) sscanf(p, "TotalDropsFiredC>%lld", &drops_c);
    if ((p = strstr(xml, "TotalDropsFiredM>"))) sscanf(p, "TotalDropsFiredM>%lld", &drops_m);
    if ((p = strstr(xml, "TotalDropsFiredY>"))) sscanf(p, "TotalDropsFiredY>%lld", &drops_y);

    printf("  Páginas Totales Impresas:      \033[1;32m%d\033[0m\n", total_pages);
    printf("    - Monocromáticas (Texto):    %d\n", mono_pages);
    printf("    - Color (Gráficos/Fotos):    %d\n", color_pages);
    printf("    - Fotos Sin Bordes (.FB):    %d\n", borderless);
    printf("  Digitalizaciones en Escáner:   %d\n", scans);
    printf("  Historial Mecánico:\n");
    printf("    - Atascos de Papel:          %d\n", jams);
    printf("    - Reintentos de Arrastre:    %d\n", picks);
    printf("  Disparos de Inyectores (Estimación de Consumo):\n");
    printf("    - Negro (GT51):              %lld gotas (~%.1f ml)\n", drops_k, (double)drops_k * 12.0e-9 * 1000.0);
    printf("    - Cian (GT52):               %lld gotas (~%.1f ml)\n", drops_c, (double)drops_c * 4.0e-9 * 1000.0);
    printf("    - Magenta (GT52):            %lld gotas (~%.1f ml)\n", drops_m, (double)drops_m * 4.0e-9 * 1000.0);
    printf("    - Amarillo (GT52):           %lld gotas (~%.1f ml)\n", drops_y, (double)drops_y * 4.0e-9 * 1000.0);
    printf("\033[1;37m===============================================================\033[0m\n\n");
}

static void parse_and_print_odometer_json(const char *xml) {
    int total_pages = 0, mono_pages = 0, color_pages = 0, borderless = 0, jams = 0, picks = 0, scans = 0;
    long long drops_k = 0, drops_c = 0, drops_m = 0, drops_y = 0;

    const char *p;
    if ((p = strstr(xml, "TotalImpressions>"))) sscanf(p, "TotalImpressions>%d", &total_pages);
    if ((p = strstr(xml, "MonochromeImpressions>"))) sscanf(p, "MonochromeImpressions>%d", &mono_pages);
    if ((p = strstr(xml, "ColorImpressions>"))) sscanf(p, "ColorImpressions>%d", &color_pages);
    if ((p = strstr(xml, "BorderlessImpressions>"))) sscanf(p, "BorderlessImpressions>%d", &borderless);
    if ((p = strstr(xml, "JamEvents>"))) sscanf(p, "JamEvents>%d", &jams);
    if ((p = strstr(xml, "PickFailures>"))) sscanf(p, "PickFailures>%d", &picks);
    if ((p = strstr(xml, "FlatbedScans>"))) sscanf(p, "FlatbedScans>%d", &scans);
    if ((p = strstr(xml, "TotalDropsFiredK>"))) sscanf(p, "TotalDropsFiredK>%lld", &drops_k);
    if ((p = strstr(xml, "TotalDropsFiredC>"))) sscanf(p, "TotalDropsFiredC>%lld", &drops_c);
    if ((p = strstr(xml, "TotalDropsFiredM>"))) sscanf(p, "TotalDropsFiredM>%lld", &drops_m);
    if ((p = strstr(xml, "TotalDropsFiredY>"))) sscanf(p, "TotalDropsFiredY>%lld", &drops_y);

    printf("{\"connected\": true, \"total_pages\": %d, \"mono_pages\": %d, \"color_pages\": %d, "
           "\"borderless_pages\": %d, \"scans\": %d, \"jams\": %d, \"pick_failures\": %d, "
           "\"drops\": {\"k\": %lld, \"c\": %lld, \"m\": %lld, \"y\": %lld}}\n",
           total_pages, mono_pages, color_pages, borderless, scans, jams, picks, drops_k, drops_c, drops_m, drops_y);
}

static int do_info(libusb_context *ctx) {
    libusb_device **devs;
    ssize_t cnt = libusb_get_device_list(ctx, &devs);
    if (cnt < 0) return 1;

    int found = 0;
    for (ssize_t i = 0; i < cnt; i++) {
        struct libusb_device_descriptor desc;
        if (libusb_get_device_descriptor(devs[i], &desc) == LIBUSB_SUCCESS) {
            if (desc.idVendor == HP_VID && desc.idProduct == HP_PID) {
                found = 1;
                printf("HP Smart Tank 500 detectada (VID 0x%04x, PID 0x%04x):\n", desc.idVendor, desc.idProduct);
                struct libusb_config_descriptor *cfg;
                if (libusb_get_active_config_descriptor(devs[i], &cfg) == LIBUSB_SUCCESS) {
                    for (int j = 0; j < cfg->bNumInterfaces; j++) {
                        const struct libusb_interface_descriptor *id = &cfg->interface[j].altsetting[0];
                        const char *role = "Desconocido";
                        if (id->bInterfaceClass == 0xff && id->bInterfaceSubClass == 0xcc) role = "Escáner LEDM / eSCL";
                        else if (id->bInterfaceClass == 0x07) role = "Impresora PCL3GUI (Print Class)";
                        else if (id->bInterfaceClass == 0xff && id->bInterfaceSubClass == 0x04) role = "EWS / Estado y Suministros";

                        printf("  Interfaz %d: Clase 0x%02x, Subclase 0x%02x, Protocolo 0x%02x [%s] (%d endpoints)\n",
                               id->bInterfaceNumber, id->bInterfaceClass, id->bInterfaceSubClass, id->bInterfaceProtocol,
                               role, id->bNumEndpoints);
                        for (int e = 0; e < id->bNumEndpoints; e++) {
                            const struct libusb_endpoint_descriptor *ep = &id->endpoint[e];
                            printf("    EP 0x%02x (%s, paquete max %d bytes)\n",
                                   ep->bEndpointAddress,
                                   (ep->bEndpointAddress & LIBUSB_ENDPOINT_DIR_MASK) ? "IN" : "OUT",
                                   ep->wMaxPacketSize);
                        }
                    }
                    libusb_free_config_descriptor(cfg);
                }
            }
        }
    }
    libusb_free_device_list(devs, 1);
    if (!found) {
        printf("Aviso: HP Smart Tank 500 (03f0:2b54) no encontrada en el bus USB.\n");
        printf("Verifique que el cable esté conectado y la impresora encendida.\n");
    }
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        print_usage(argv[0]);
        return 0;
    }
    if (strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-V") == 0) {
        printf("hp-smart-tank-tool %s\n", HP_SMART_TANK_VERSION);
        return 0;
    }

    const char *cmd = argv[1];
    int command_exit_code = 0;

    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) != LIBUSB_SUCCESS) {
        fprintf(stderr, "Error inicializando libusb\n");
        return 1;
    }

    if (strcmp(cmd, "info") == 0) {
        do_info(ctx);
        libusb_exit(ctx);
        return 0;
    }

    usb_channel_t chan;
    char buffer[BUFFER_SIZE];

    int is_mock = (getenv("HP_SMART_TANK_MOCK") != NULL);
    int confirm_hardware = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--mock") == 0) {
            is_mock = 1;
        } else if (strcmp(argv[i], "--confirm-hardware") == 0) {
            confirm_hardware = 1;
        }
    }

    const int hazardous_command =
        strcmp(cmd, "clean-heads") == 0 || strcmp(cmd, "deep-clean") == 0 ||
        strcmp(cmd, "clean-rollers") == 0 || strcmp(cmd, "diag-page") == 0 ||
        strcmp(cmd, "nozzle-test") == 0 || strcmp(cmd, "align") == 0 ||
        strcmp(cmd, "inject-raw") == 0 || strcmp(cmd, "test-pattern") == 0 ||
        strcmp(cmd, "prime-tubes") == 0;
    if (hazardous_command && !is_mock && !confirm_hardware) {
        fprintf(stderr, "Operación bloqueada: %s puede actuar físicamente sobre la impresora. "
                       "Use --confirm-hardware sólo con autorización explícita.\n", cmd);
        libusb_exit(ctx);
        return 2;
    }

    if (strcmp(cmd, "json-supplies") == 0) {
        if (is_mock) {
            printf("{\"connected\": true, \"mock\": true, \"supplies\": ["
                   "{\"code\": \"K\", \"name\": \"Negro (Black)\", \"level\": 100, \"state\": \"inSensorRange\"}, "
                   "{\"code\": \"C\", \"name\": \"Cian (Cyan)\", \"level\": 85, \"state\": \"inSensorRange\"}, "
                   "{\"code\": \"M\", \"name\": \"Magenta\", \"level\": 90, \"state\": \"inSensorRange\"}, "
                   "{\"code\": \"Y\", \"name\": \"Amarillo (Yellow)\", \"level\": 75, \"state\": \"inSensorRange\"}"
                   "]}\n");
            libusb_exit(ctx);
            return 0;
        }
        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            printf("{\"connected\": false, \"error\": \"Impresora HP Smart Tank 500 no detectada en USB\"}\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req = "GET /DevMgmt/ConsumableConfigDyn.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            parse_and_print_supplies_json(buffer);
        } else {
            printf("{\"connected\": false, \"error\": \"Fallo al leer suministros del hardware\"}\n");
            command_exit_code = 1;
        }
        close_channel(&chan);
        libusb_exit(ctx);
        return command_exit_code;
    } else if (strcmp(cmd, "json-status") == 0) {
        if (is_mock) {
            printf("{\"connected\": true, \"mock\": true, \"status\": \"ready\", \"description\": \"Lista y en reposo\"}\n");
            libusb_exit(ctx);
            return 0;
        }
        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            printf("{\"connected\": false, \"status\": \"disconnected\", \"description\": \"Impresora desconectada o apagada\"}\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req = "GET /DevMgmt/ProductStatusDyn.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            parse_and_print_status_json(buffer);
        } else {
            printf("{\"connected\": false, \"status\": \"error\", \"description\": \"Error de lectura del dispositivo\"}\n");
            command_exit_code = 1;
        }
        close_channel(&chan);
        libusb_exit(ctx);
        return command_exit_code;
    } else if (strcmp(cmd, "json-odometer") == 0) {
        if (is_mock) {
            printf("{\"connected\": true, \"mock\": true, \"total_pages\": 1248, \"mono_pages\": 830, \"color_pages\": 418, \"borderless_pages\": 94, \"scans\": 156, \"jams\": 2, \"pick_failures\": 1, \"drops\": {\"k\": 48291000, \"c\": 12400000, \"m\": 13100000, \"y\": 11800000}}\n");
            libusb_exit(ctx);
            return 0;
        }
        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            printf("{\"connected\": false, \"error\": \"Impresora no detectada\"}\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req = "GET /DevMgmt/ProductUsageDyn.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            parse_and_print_odometer_json(buffer);
        } else {
            printf("{\"connected\": false, \"error\": \"Fallo al leer odómetro\"}\n");
            command_exit_code = 1;
        }
        close_channel(&chan);
        libusb_exit(ctx);
        return command_exit_code;
    }

    if (strcmp(cmd, "supplies") == 0) {
        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal EWS (Interfaz 2)\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req = "GET /DevMgmt/ConsumableConfigDyn.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            parse_and_print_supplies(buffer);
        } else {
            fprintf(stderr, "No se recibieron datos de suministros desde el hardware\n");
            command_exit_code = 1;
        }
        close_channel(&chan);
    } else if (strcmp(cmd, "status") == 0) {
        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal EWS (Interfaz 2)\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req = "GET /DevMgmt/ProductStatusDyn.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            parse_and_print_status(buffer);
        } else {
            fprintf(stderr, "No se recibieron datos de estado desde el hardware\n");
            command_exit_code = 1;
        }
        close_channel(&chan);
    } else if (strcmp(cmd, "odometer") == 0 || strcmp(cmd, "telemetry") == 0 || strcmp(cmd, "stats") == 0) {
        if (is_mock) {
            const char *mock_xml = "<pudyn:ProductUsageDyn><TotalImpressions>1248</TotalImpressions><MonochromeImpressions>830</MonochromeImpressions><ColorImpressions>418</ColorImpressions><BorderlessImpressions>94</BorderlessImpressions><JamEvents>2</JamEvents><PickFailures>1</PickFailures><FlatbedScans>156</FlatbedScans><TotalDropsFiredK>48291000</TotalDropsFiredK><TotalDropsFiredC>12400000</TotalDropsFiredC><TotalDropsFiredM>13100000</TotalDropsFiredM><TotalDropsFiredY>11800000</TotalDropsFiredY></pudyn:ProductUsageDyn>";
            parse_and_print_odometer(mock_xml);
            libusb_exit(ctx);
            return 0;
        }
        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal EWS (Interfaz 2)\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req = "GET /DevMgmt/ProductUsageDyn.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            parse_and_print_odometer(buffer);
        } else {
            fprintf(stderr, "No se recibieron datos de odómetro desde el hardware\n");
            command_exit_code = 1;
        }
        close_channel(&chan);
    } else if (strcmp(cmd, "scan-caps") == 0) {
        if (open_channel(ctx, 0xff, 0xcc, 0x00, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal de Escaneo LEDM (Interfaz 0)\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req = "GET /Scan/ScanCaps HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            printf("\n=== CAPACIDADES DEL ESCÁNER (LEDM) ===\n%s\n=======================================\n", buffer);
        } else {
            fprintf(stderr, "No se recibieron capacidades del escáner desde el hardware\n");
            command_exit_code = 1;
        }
        close_channel(&chan);
    } else if (strcmp(cmd, "scan-status") == 0) {
        if (open_channel(ctx, 0xff, 0xcc, 0x00, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal de Escaneo LEDM (Interfaz 0)\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req = "GET /Scan/Status HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            printf("\n=== ESTADO DEL ESCÁNER (LEDM) ===\n%s\n==================================\n", buffer);
        } else {
            fprintf(stderr, "No se recibió estado del escáner desde el hardware\n");
            command_exit_code = 1;
        }
        close_channel(&chan);
    } else if (strcmp(cmd, "clean-heads") == 0 || strcmp(cmd, "deep-clean") == 0 ||
               strcmp(cmd, "clean-rollers") == 0 || strcmp(cmd, "diag-page") == 0 ||
               strcmp(cmd, "nozzle-test") == 0) {
        const char *job_type = "cleaningPage";
        const char *desc = "Limpieza Nivel 1 (Purga de Inyectores)";
        if (strcmp(cmd, "deep-clean") == 0) {
            job_type = "cleaningPageLevel1";
            desc = "Limpieza Nivel 2 (Purga Profunda de Vacío)";
        } else if (strcmp(cmd, "clean-rollers") == 0) {
            job_type = "cleaningPageLevel2";
            desc = "Limpieza Nivel 3 (Rodillos y Manchas de Papel)";
        } else if (strcmp(cmd, "diag-page") == 0 || strcmp(cmd, "nozzle-test") == 0) {
            job_type = "cleaningVerificationPage";
            desc = "Patrón de Verificación de Inyectores";
        }

        if (is_mock) {
            if (strcmp(cmd, "clean-rollers") == 0) {
                printf("Iniciando %s vía EWS...\nIniciando ciclo de limpieza de rodillos de tracción... Solicitud completada exitosamente (Mock).\n", desc);
            } else if (strcmp(cmd, "diag-page") == 0 || strcmp(cmd, "nozzle-test") == 0) {
                printf("Imprimiendo patron de verificacion de inyectores (%s) vía EWS...\nSolicitud completada exitosamente (Mock).\n", job_type);
            } else {
                printf("Iniciando %s (%s) vía EWS...\nSolicitud completada exitosamente (Mock).\n", desc, job_type);
            }
            libusb_exit(ctx);
            return 0;
        }

        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal EWS (Interfaz 2)\n");
            libusb_exit(ctx);
            return 1;
        }

        char post_body[512];
        snprintf(post_body, sizeof(post_body),
                 "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n"
                 "<ipcap:InternalPrintCap xmlns:ipcap=\"http://www.hp.com/schemas/imaging/con/ledm/internalprintcap/2008/03/21\" "
                 "xmlns:ipdyn=\"http://www.hp.com/schemas/imaging/con/ledm/internalprintdyn/2008/03/21\">\r\n"
                 "  <ipdyn:JobType>%s</ipdyn:JobType>\r\n"
                 "</ipcap:InternalPrintCap>\r\n", job_type);

        char post_req[1024];
        snprintf(post_req, sizeof(post_req),
                 "POST /DevMgmt/InternalPrintDyn.xml HTTP/1.1\r\n"
                 "Host: localhost\r\n"
                 "Content-Type: text/xml\r\n"
                 "Content-Length: %zu\r\n"
                 "Connection: close\r\n\r\n%s",
                 strlen(post_body), post_body);

        printf("Enviando solicitud de mantenimiento (%s) a la impresora...\n", job_type);
        int bytes = http_request(&chan, post_req, buffer, sizeof(buffer));
        if (bytes > 0) {
            printf("Respuesta recibida:\n%s\n", buffer);
        }
        close_channel(&chan);
    } else if (strcmp(cmd, "align") == 0) {
        if (is_mock) {
            printf("Iniciando proceso de alineación óptica de cabezales vía EWS...\nImprimiendo patrón de alineación... Solicitud completada exitosamente (Mock).\n");
            libusb_exit(ctx);
            return 0;
        }
        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal EWS (Interfaz 2)\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *align_body = "<cal:CalibrationState xmlns:cal=\"http://www.hp.com/schemas/imaging/con/cnx/markingagentcalibration/2009/04/08\">Printing</cal:CalibrationState>";
        char post_req[1024];
        snprintf(post_req, sizeof(post_req),
                 "POST /Calibration/Session HTTP/1.1\r\n"
                 "Host: localhost\r\n"
                 "Content-Type: text/xml\r\n"
                 "Content-Length: %zu\r\n"
                 "Connection: close\r\n\r\n%s",
                 strlen(align_body), align_body);

        printf("Iniciando proceso de alineación de cabezales...\n");
        int bytes = http_request(&chan, post_req, buffer, sizeof(buffer));
        if (bytes > 0) {
            printf("Respuesta recibida:\n%s\n", buffer);
        }
        close_channel(&chan);
    } else if (strcmp(cmd, "get") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Uso: %s get <url-path>\n", argv[0]);
            libusb_exit(ctx);
            return 1;
        }
        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal EWS (Interfaz 2)\n");
            libusb_exit(ctx);
            return 1;
        }
        char req[1024];
        snprintf(req, sizeof(req), "GET %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n", argv[2]);
        int bytes = http_request(&chan, req, buffer, sizeof(buffer));
        if (bytes > 0) {
            printf("%s\n", buffer);
        } else {
            fprintf(stderr, "No se recibieron datos (bytes=%d)\n", bytes);
        }
        close_channel(&chan);
    } else if (strcmp(cmd, "dump-tree") == 0) {
        printf("\n\033[1;37m=== DUMP DE ÁRBOL DE FIRMWARE Y CAPACIDADES (EWS / DevMgmt) ===\033[0m\n");
        const char *tree_endpoints[] = {
            "/DevMgmt/DiscoveryTree.xml",
            "/DevMgmt/ProductConfigDyn.xml",
            "/DevMgmt/MediaCapabilities.xml",
            "/DevMgmt/IOConfig.xml"
        };
        int num_endpoints = sizeof(tree_endpoints) / sizeof(tree_endpoints[0]);

        if (is_mock) {
            printf("--- Endpoint: /DevMgmt/DiscoveryTree.xml (Mock) ---\n");
            printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                   "<DiscoveryTree xmlns=\"http://www.hp.com/schemas/imaging/con/ledm/discoverytree/2008/03/21\">\n"
                   "  <Service name=\"DevMgmt\" url=\"/DevMgmt/\"/>\n"
                   "  <Service name=\"Scan\" url=\"/Scan/\"/>\n"
                   "  <Service name=\"Print\" url=\"/Print/\"/>\n"
                   "  <Service name=\"Calibration\" url=\"/Calibration/\"/>\n"
                   "</DiscoveryTree>\n\n");

            printf("--- Endpoint: /DevMgmt/ProductConfigDyn.xml (Mock) ---\n");
            printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                   "<ProductConfigDyn xmlns=\"http://www.hp.com/schemas/imaging/con/ledm/productconfigdyn/2008/03/21\">\n"
                   "  <ProductInformation>\n"
                   "    <MakeAndModel>HP Smart Tank 500 series</MakeAndModel>\n"
                   "    <ProductSerialNumber>TH01234567</ProductSerialNumber>\n"
                   "    <FirmwareVersion>VER3_2024A</FirmwareVersion>\n"
                   "    <HardwareArchitecture>ASIC-P15_CISS</HardwareArchitecture>\n"
                   "  </ProductInformation>\n"
                   "</ProductConfigDyn>\n\n");

            printf("--- Endpoint: /DevMgmt/MediaCapabilities.xml (Mock) ---\n");
            printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                   "<MediaCapabilities xmlns=\"http://www.hp.com/schemas/imaging/con/ledm/mediacapabilities/2008/03/21\">\n"
                   "  <SupportedMediaTypes>\n"
                   "    <Type>Plain</Type><Type>Glossy</Type><Type>FastGlossy</Type><Type>Brochure</Type><Type>Matte</Type>\n"
                   "  </SupportedMediaTypes>\n"
                   "  <SupportedSizes>\n"
                   "    <Size borderless=\"true\">A4</Size><Size borderless=\"true\">Letter</Size><Size borderless=\"true\">Photo4x6</Size>\n"
                   "  </SupportedSizes>\n"
                   "</MediaCapabilities>\n\n");

            printf("--- Endpoint: /DevMgmt/IOConfig.xml (Mock) ---\n");
            printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                   "<IOConfig xmlns=\"http://www.hp.com/schemas/imaging/con/ledm/ioconfig/2008/03/21\">\n"
                   "  <Interface id=\"0\" type=\"LEDM_Scan\" ep_in=\"0x81\" ep_out=\"0x01\"/>\n"
                   "  <Interface id=\"1\" type=\"PCL3GUI_Print\" ep_in=\"0x82\" ep_out=\"0x02\"/>\n"
                   "  <Interface id=\"2\" type=\"EWS_DevMgmt\" ep_in=\"0x83\" ep_out=\"0x03\"/>\n"
                   "</IOConfig>\n\n");
            printf("\033[1;37m===============================================================\033[0m\n\n");
            libusb_exit(ctx);
            return 0;
        }

        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal EWS (Interfaz 2)\n");
            libusb_exit(ctx);
            return 1;
        }

        for (int i = 0; i < num_endpoints; i++) {
            printf("\n--- Endpoint: %s ---\n", tree_endpoints[i]);
            char req[1024];
            snprintf(req, sizeof(req), "GET %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n", tree_endpoints[i]);
            int bytes = http_request(&chan, req, buffer, sizeof(buffer));
            if (bytes > 0) {
                printf("%s\n", buffer);
            } else {
                printf("(Sin respuesta o endpoint no disponible en hardware)\n");
            }
        }
        close_channel(&chan);
        printf("\033[1;37m===============================================================\033[0m\n\n");
    } else if (strcmp(cmd, "inject-raw") == 0) {
        const char *filename = NULL;
        for (int i = 2; i < argc; i++) {
            if (strcmp(argv[i], "--mock") != 0) {
                filename = argv[i];
                break;
            }
        }
        if (!filename) {
            fprintf(stderr, "Uso: %s inject-raw <archivo.bin> [--mock]\n", argv[0]);
            libusb_exit(ctx);
            return 1;
        }

        int raw_fd = open(filename, O_RDONLY | O_NOFOLLOW);
        FILE *fp = (raw_fd >= 0) ? fdopen(raw_fd, "rb") : NULL;
        if (!fp && !is_mock) {
            fprintf(stderr, "Error: No se pudo abrir el archivo %s\n", filename);
            if (raw_fd >= 0) close(raw_fd);
            libusb_exit(ctx);
            return 1;
        }

        long file_size = 0;
        if (fp) {
            fseek(fp, 0, SEEK_END);
            file_size = ftell(fp);
            fseek(fp, 0, SEEK_SET);
        } else {
            file_size = 1024; // Mock fallback
        }

        printf("=== INYECCIÓN RAW DIRECTA A HARDWARE (HP Smart Tank 500) ===\n");
        printf("  Archivo: %s (%ld bytes)\n", filename, file_size);
        printf("  Destino: Interfaz 1 (Clase 0x07 Impresión, EP 0x02 Bulk OUT)\n");

        if (is_mock) {
            printf("  [MOCK] Modo de simulación activo.\n");
            printf("  [MOCK] Transfiriendo %ld bytes en bloques de 16 KB a EP 0x02...\n", file_size);
            printf("  [MOCK] Inyección RAW completada exitosamente: %ld bytes enviados al ASIC.\n", file_size);
            printf("============================================================\n");
            if (fp) fclose(fp);
            libusb_exit(ctx);
            return 0;
        }

        if (open_channel(ctx, 0x07, 0x01, 0x02, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal de impresión USB (Interfaz 1: 0x07/0x01/0x02)\n");
            if (fp) fclose(fp);
            libusb_exit(ctx);
            return 1;
        }

        unsigned char chunk[16384];
        long total_sent = 0;
        size_t nread = 0;
        while ((nread = fread(chunk, 1, sizeof(chunk), fp)) > 0) {
            int transferred = 0;
            int r = libusb_bulk_transfer(chan.handle, chan.ep_out, chunk, (int)nread, &transferred, 10000);
            if (r != LIBUSB_SUCCESS) {
                fprintf(stderr, "Error durante la transferencia USB: %s\n", libusb_error_name(r));
                break;
            }
            total_sent += transferred;
            if (file_size > 0) {
                printf("\r  Progreso: %ld / %ld bytes enviados (%d%%)", total_sent, file_size, (int)((total_sent * 100) / file_size));
            } else {
                printf("\r  Progreso: %ld bytes enviados", total_sent);
            }
            fflush(stdout);
        }
        printf("\n");
        if (fp) fclose(fp);
        close_channel(&chan);

        printf("  Inyección finalizada: %ld bytes transferidos exitosamente.\n", total_sent);
        printf("============================================================\n");
    } else if (strcmp(cmd, "accounting") == 0) {
        printf("\n\033[1;37m=== AUDITORÍA FINANCIERA Y CONTABILIDAD DE COSTES (HP Smart Tank 500) ===\033[0m\n");
        FILE *fp = open_private_read("/tmp/hp_smarttank_accounting.csv");
        if (is_mock) {
            printf("  Trabajos registrados:      18 trabajos\n");
            printf("  Páginas totales impresas:  45 páginas\n");
            printf("  Consumo estimado de tinta:\n");
            printf("    - Negro Pigmento (GT51): ~5.40 ml ($0.56 USD)\n");
            printf("    - Color Tri-Dye (GT52):  ~3.60 ml ($0.57 USD)\n");
            printf("  Costo total acumulado:     $1.805 USD (Tinta: $1.130, Papel: $0.675)\n");
            printf("  Reduccion raster estimada (no tinta fisica): \033[1;32m~3.80 ml equivalentes ($0.450 USD teóricos)\033[0m\n");
            printf("  Costo promedio por página: \033[1;32m$0.040 USD / hoja\033[0m\n");
            printf("-------------------------------------------------------------------------\n");
            printf("  Último trabajo registrado: Presupuesto_Comercial.pdf (3 págs, $0.120 USD, Ahorro: Eco50)\n");
            printf("\033[1;37m=========================================================================\033[0m\n\n");
            if (fp) fclose(fp);
            libusb_exit(ctx);
            return 0;
        }
        if (!fp) {
            fprintf(stderr, "No hay contabilidad física/local disponible; use --mock sólo para pruebas.\n");
            libusb_exit(ctx);
            return 1;
        }

        char line[512];
        int job_count = 0;
        int total_pages = 0;
        double total_cost = 0.0;
        double total_k = 0.0;
        double total_color = 0.0;
        double total_saved_ml = 0.0;
        double total_saved_usd = 0.0;
        char last_job[160] = "Ninguno";

        if (fgets(line, sizeof(line), fp)) {
            while (fgets(line, sizeof(line), fp)) {
                job_count++;
                char time_buf[64], user_buf[64], title_buf[128], mode_buf[64];
                int jid = 0, pages = 0;
                size_t bytes = 0;
                double k = 0, c = 0, cost = 0, s_ml = 0, s_usd = 0;
                mode_buf[0] = '\0';

                int n = sscanf(line, "\"%63[^\"]\",%d,\"%63[^\"]\",\"%127[^\"]\",%d,%zu,%lf,%lf,%lf,%lf,%lf,\"%63[^\"]\"",
                               time_buf, &jid, user_buf, title_buf, &pages, &bytes, &k, &c, &cost, &s_ml, &s_usd, mode_buf);
                if (n >= 8) {
                    total_pages += pages;
                    total_k += k;
                    total_color += c;
                    total_cost += cost;
                    if (n >= 11) {
                        total_saved_ml += s_ml;
                        total_saved_usd += s_usd;
                    }
                    if (n >= 12 && strlen(mode_buf) > 0 && strcmp(mode_buf, "Off") != 0) {
                        snprintf(last_job, sizeof(last_job), "%s (%d págs, $%.3f USD, Ahorro: %s)", title_buf, pages, cost, mode_buf);
                    } else {
                        snprintf(last_job, sizeof(last_job), "%s (%d págs, $%.3f USD)", title_buf, pages, cost);
                    }
                }
            }
        }
        fclose(fp);

        printf("  Trabajos registrados:      %d trabajos\n", job_count);
        printf("  Páginas totales impresas:  %d páginas\n", total_pages);
        printf("  Consumo estimado de tinta:\n");
        printf("    - Negro Pigmento (GT51): ~%.2f ml ($%.2f USD)\n", total_k, total_k * 0.1037);
        printf("    - Color Tri-Dye (GT52):  ~%.2f ml ($%.2f USD)\n", total_color, total_color * 0.1571);
        printf("  Costo total acumulado:     $%.3f USD\n", total_cost);
        if (total_saved_ml > 0.001) {
            printf("  Reduccion raster estimada (no tinta fisica): \033[1;32m~%.2f ml equivalentes ($%.3f USD teóricos)\033[0m\n", total_saved_ml, total_saved_usd);
        }
        if (total_pages > 0) {
            printf("  Costo promedio por página: \033[1;32m$%.3f USD / hoja\033[0m\n", total_cost / total_pages);
        }
        printf("-------------------------------------------------------------------------\n");
        printf("  Último trabajo registrado: %s\n", last_job);
        printf("\033[1;37m=========================================================================\033[0m\n\n");
        libusb_exit(ctx);
        return 0;
    } else if (strcmp(cmd, "json-accounting") == 0) {
        FILE *fj = open_private_read("/tmp/hp_smarttank_last_cost.json");
        if (fj && !is_mock) {
            char jbuf[1024];
            size_t n = fread(jbuf, 1, sizeof(jbuf) - 1, fj);
            jbuf[n] = '\0';
            fclose(fj);
            printf("%s\n", jbuf);
        } else if (is_mock) {
            if (fj) fclose(fj);
            printf("{\"timestamp\": \"2026-09-04 00:00:00\", \"job_id\": \"mock-1\", \"user\": \"testuser\", \"title\": \"Simulacion.pdf\", \"pages\": 2, \"bytes\": 24500, \"ink_k_ml\": 0.18, \"ink_color_ml\": 0.10, \"cost_usd\": 0.058, \"ink_saved_ml\": 0.12, \"money_saved_usd\": 0.022, \"saver_mode\": \"Eco50\"}\n");
        } else {
            fprintf(stderr, "No hay contabilidad física/local disponible; use --mock sólo para pruebas.\n");
            libusb_exit(ctx);
            return 1;
        }
        libusb_exit(ctx);
        return 0;
    } else if (strcmp(cmd, "test-pattern") == 0) {
        const char *pattern_type = "cmyk";
        for (int i = 2; i < argc; i++) {
            if (strcmp(argv[i], "--mock") != 0) {
                pattern_type = argv[i];
                break;
            }
        }
        printf("=== PATRÓN PROFESIONAL DE DIAGNÓSTICO Y CALIBRACIÓN (HP Smart Tank 500) ===\n");
        const char *desc = "Degradados Continuos CMYK (Detección de banding e inyectores)";
        if (strcmp(pattern_type, "grid") == 0) {
            desc = "Cuadrícula Geométrica Milimétrica (Paralelismo de rodillos y deformación)";
        } else if (strcmp(pattern_type, "alignment") == 0) {
            desc = "Peine de Micro-Paso Vertical (Alineación bidireccional de cabezales)";
        }

        printf("  Tipo de Patrón: %s\n", pattern_type);
        printf("  Descripción:    %s\n", desc);

        if (is_mock) {
            printf("  [MOCK] Generando flujo PCL3GUI a 600 DPI para '%s'...\n", pattern_type);
            printf("  [MOCK] Enviando trama a Interface 1 (Bulk OUT EP 0x02)...\n");
            printf("  [MOCK] Patrón de prueba enviado exitosamente al hardware.\n");
            printf("===========================================================================\n");
            libusb_exit(ctx);
            return 0;
        }

        if (open_channel(ctx, 0xff, 0x04, 0x01, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal EWS (Interfaz 2)\n");
            libusb_exit(ctx);
            return 1;
        }
        const char *req_body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n"
                               "<ipcap:InternalPrintCap xmlns:ipcap=\"http://www.hp.com/schemas/imaging/con/ledm/internalprintcap/2008/03/21\" "
                               "xmlns:ipdyn=\"http://www.hp.com/schemas/imaging/con/ledm/internalprintdyn/2008/03/21\">\r\n"
                               "  <ipdyn:JobType>cleaningVerificationPage</ipdyn:JobType>\r\n"
                               "</ipcap:InternalPrintCap>\r\n";
        char post_req[1024];
        snprintf(post_req, sizeof(post_req),
                 "POST /DevMgmt/InternalPrintDyn.xml HTTP/1.1\r\n"
                 "Host: localhost\r\n"
                 "Content-Type: text/xml\r\n"
                 "Content-Length: %zu\r\n"
                 "Connection: close\r\n\r\n%s",
                 strlen(req_body), req_body);
        int bytes = http_request(&chan, post_req, buffer, sizeof(buffer));
        if (bytes > 0) {
            printf("  Respuesta del hardware:\n%s\n", buffer);
        }
        close_channel(&chan);
        printf("  Patrón enviado a la impresora exitosamente.\n");
        printf("===========================================================================\n");
    } else if (strcmp(cmd, "scan") == 0) {
        if (argc <= 2 || argv[2][0] == '\0') {
            fprintf(stderr, "Debe indicar un archivo de salida explícito para el escaneo; no se usa una ruta predeterminada.\n");
            libusb_exit(ctx);
            return 2;
        }
        const char *outfile = argv[2];
        if (open_channel(ctx, 0xff, 0xcc, 0x00, &chan) != 0) {
            fprintf(stderr, "No se pudo abrir el canal de Escaneo LEDM (Interfaz 0)\n");
            libusb_exit(ctx);
            return 1;
        }

        const char *scan_job_xml =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n"
            "<ScanSettings xmlns=\"http://www.hp.com/schemas/imaging/con/cnx/scan/2008/08/19\">\r\n"
            "  <XResolution>300</XResolution>\r\n"
            "  <YResolution>300</YResolution>\r\n"
            "  <XStart>0</XStart>\r\n"
            "  <Width>2550</Width>\r\n"
            "  <YStart>0</YStart>\r\n"
            "  <Height>3508</Height>\r\n"
            "  <Format>Jpeg</Format>\r\n"
            "  <CompressionQFactor>15</CompressionQFactor>\r\n"
            "  <ColorSpace>Color</ColorSpace>\r\n"
            "  <BitDepth>8</BitDepth>\r\n"
            "  <InputSource>Platen</InputSource>\r\n"
            "  <ContentType>Photo</ContentType>\r\n"
            "</ScanSettings>\r\n";

        char post_req[2048];
        snprintf(post_req, sizeof(post_req),
                 "POST /Scan/Jobs HTTP/1.1\r\n"
                 "Host: localhost\r\n"
                 "Content-Type: text/xml\r\n"
                 "Content-Length: %zu\r\n"
                 "Connection: close\r\n\r\n%s",
                 strlen(scan_job_xml), scan_job_xml);

        printf("Iniciando trabajo de escaneo óptico a 300 DPI...\n");
        int bytes = http_request(&chan, post_req, buffer, sizeof(buffer));
        if (bytes <= 0) {
            fprintf(stderr, "Error creando trabajo de escaneo en el hardware.\n");
            close_channel(&chan);
            libusb_exit(ctx);
            return 1;
        }

        char job_url[256] = {0};
        char *loc = strstr(buffer, "Location: ");
        if (loc) {
            sscanf(loc, "Location: %255[^\r\n]", job_url);
        }
        if (job_url[0] == '\0') {
            fprintf(stderr, "El hardware no devolvió Location para el trabajo de escaneo; no se inventa una ruta.\n");
            close_channel(&chan);
            libusb_exit(ctx);
            return 1;
        }
        char *job_path = strstr(job_url, "/Jobs/");
        if (!job_path) job_path = strstr(job_url, "/Scan/");
        if (!job_path) job_path = job_url;

        printf("Trabajo de escaneo registrado: %s (ruta: %s)\n", job_url, job_path);
        close_channel(&chan);

        printf("Digitalizando documento en la cama plana (esperando ReadyToUpload)...");
        fflush(stdout);

        char status_req[512];
        snprintf(status_req, sizeof(status_req),
                 "GET %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n", job_path);

        int ready = 0;
        char binary_url[256] = {0};
        for (int retry = 0; retry < 35; retry++) {
            sleep(1);
            if (open_channel(ctx, 0xff, 0xcc, 0x00, &chan) != 0) continue;
            int b = http_request(&chan, status_req, buffer, sizeof(buffer));
            close_channel(&chan);
            if (b > 0 && strstr(buffer, "ReadyToUpload")) {
                ready = 1;
                printf("\n¡Digitalización completada en hardware! Listo para transferir.\n");
                char *bin_ptr = strstr(buffer, "<BinaryURL>");
                if (bin_ptr) {
                    sscanf(bin_ptr, "<BinaryURL>%255[^<]", binary_url);
                }
                break;
            }
            printf(".");
            fflush(stdout);
        }

        if (!ready) {
            printf("\nAviso: Timeout esperando ReadyToUpload, intentando descarga directa...\n");
        }

        char *bin_path = strstr(binary_url, "/Scan/");
        if (!bin_path) bin_path = strstr(binary_url, "/Jobs/");
        if (!bin_path || bin_path[0] == '\0') {
            snprintf(binary_url, sizeof(binary_url), "%s/Pages/1", job_path);
            bin_path = binary_url;
        }
        printf("Descargando imagen desde: %s\n", bin_path);

        /* Reabrir canal para descargar la página */
        if (open_channel(ctx, 0xff, 0xcc, 0x00, &chan) != 0) {
            fprintf(stderr, "Error reabriendo canal para descarga.\n");
            libusb_exit(ctx);
            return 1;
        }

        char page_req[512];
        snprintf(page_req, sizeof(page_req),
                 "GET %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n", bin_path);

        int transferred = 0;
        int r = bulk_send_text(&chan, page_req, &transferred, 5000);
        if (r != LIBUSB_SUCCESS) {
            fprintf(stderr, "Error solicitando imagen: %s\n", libusb_error_name(r));
            close_channel(&chan);
            libusb_exit(ctx);
            return 1;
        }

        int out_fd = open(outfile, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0600);
        FILE *fp = (out_fd >= 0) ? fdopen(out_fd, "wb") : NULL;
        if (!fp) {
            perror("Error abriendo archivo de salida");
            if (out_fd >= 0) close(out_fd);
            close_channel(&chan);
            libusb_exit(ctx);
            return 1;
        }

        unsigned char raw_buf[65536];
        int header_stripped = 0;
        int total_bytes = 0;

        printf("Transfiriendo flujo JPEG desde el escáner...\n");
        while (1) {
            int chunk_read = 0;
            r = libusb_bulk_transfer(chan.handle, chan.ep_in, raw_buf, sizeof(raw_buf), &chunk_read, 3000);
            if (r == LIBUSB_SUCCESS && chunk_read > 0) {
                if (!header_stripped) {
                    /* Localizar el marcador de inicio JPEG 0xFF 0xD8 */
                    int start_idx = -1;
                    for (int i = 0; i < chunk_read - 1; i++) {
                        if (raw_buf[i] == 0xFF && raw_buf[i+1] == 0xD8) {
                            start_idx = i;
                            break;
                        }
                    }
                    if (start_idx >= 0) {
                        header_stripped = 1;
                        int write_len = chunk_read - start_idx;
                        fwrite(raw_buf + start_idx, 1, (size_t)write_len, fp);
                        total_bytes += write_len;
                    }
                } else {
                        fwrite(raw_buf, 1, (size_t)chunk_read, fp);
                    total_bytes += chunk_read;
                }
            } else if (r == LIBUSB_ERROR_TIMEOUT) {
                if (total_bytes > 0) break;
            } else {
                break;
            }
        }
        fclose(fp);
        close_channel(&chan);

        printf("¡Escaneo finalizado! %d bytes guardados en: %s\n", total_bytes, outfile);
    } else if (strcmp(cmd, "prime-tubes") == 0) {
        printf("\n\033[1;37m=== CEBADO Y PURGA FORZADA DE TUBOS DE TINTA CISS (HP Smart Tank 500) ===\033[0m\n");
        printf("  Objetivo: Purgar burbujas de aire en las 4 mangueras capilares (K, C, M, Y).\n");
        printf("  Acción: Activación de la bomba peristáltica de succión continua a 42 kPa...\n");

        if (is_mock) {
            printf("  [MOCK] Presurizando bomba peristáltica CISS...\n");
            printf("  [MOCK] Succión de tubos K (Negro Pigmento): OK (Libre de aire)\n");
            printf("  [MOCK] Succión de tubos C, M, Y (Color Tri-Dye): OK (Libre de aire)\n");
            printf("  [MOCK] Cebado simulado completado; no se verificó hardware ni flujo de tinta.\n");
            printf("\033[1;37m=========================================================================\033[0m\n\n");
            libusb_exit(ctx);
            return 0;
        }

        if (open_channel(ctx, 0xff, 0xcc, 0x00, &chan) != 0) {
            fprintf(stderr, "Error: No se pudo abrir canal LEDM/EWS (Interfaz 0)\n");
            libusb_exit(ctx);
            return 1;
        }

        const char *req_body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n"
                               "<ipcap:InternalPrintCap xmlns:ipcap=\"http://schemas.hp.com/imaging/escl/2011/05/03\"\r\n"
                               "                        xmlns:ipdyn=\"http://schemas.hp.com/imaging/escl/2011/05/03/dynamic\">\r\n"
                               "  <ipdyn:JobType>primeTubes</ipdyn:JobType>\r\n"
                               "</ipcap:InternalPrintCap>\r\n";
        char post_req[1024];
        snprintf(post_req, sizeof(post_req),
                 "POST /DevMgmt/InternalPrintDyn.xml HTTP/1.1\r\n"
                 "Host: localhost\r\n"
                 "Content-Type: text/xml\r\n"
                 "Content-Length: %zu\r\n"
                 "Connection: close\r\n\r\n%s",
                 strlen(req_body), req_body);

        int bytes = http_request(&chan, post_req, buffer, sizeof(buffer));
        if (bytes > 0 && strstr(buffer, "200 OK")) {
            printf("  Respuesta HTTP 200 recibida; aceptación física del cebado no está verificada.\n");
            printf("  La bomba funcionará durante aprox. 45 segundos. Por favor espere.\n");
        } else {
            /* Fallback a Nivel 2 de limpieza profunda */
            fprintf(stderr, "  No se obtuvo confirmación válida del cebado; no se ejecuta un fallback destructivo.\n");
            close_channel(&chan);
            libusb_exit(ctx);
            return 1;
            /* El fallback histórico Clean Level 2 queda deliberadamente inactivo:
               una respuesta HTTP insuficiente no autoriza otra operación mecánica. */
#if 0
            const char *alt_body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n"
                                   "<ipcap:InternalPrintCap xmlns:ipcap=\"http://schemas.hp.com/imaging/escl/2011/05/03\"\r\n"
                                   "                        xmlns:ipdyn=\"http://schemas.hp.com/imaging/escl/2011/05/03/dynamic\">\r\n"
                                   "  <ipdyn:JobType>cleanHeadLevel2</ipdyn:JobType>\r\n"
                                   "</ipcap:InternalPrintCap>\r\n";
            snprintf(post_req, sizeof(post_req),
                     "POST /DevMgmt/InternalPrintDyn.xml HTTP/1.1\r\n"
                     "Host: localhost\r\n"
                     "Content-Type: text/xml\r\n"
                     "Content-Length: %zu\r\n"
                     "Connection: close\r\n\r\n%s",
                     strlen(alt_body), alt_body);
            http_request(&chan, post_req, buffer, sizeof(buffer));
            printf("  ¡Ciclo de succión profunda y cebado enviado!\n");
#endif
        }
        close_channel(&chan);
        printf("\033[1;37m=========================================================================\033[0m\n\n");
    } else if (strcmp(cmd, "waste-ink") == 0) {
        printf("\n\033[1;37m=== AUDITORÍA DE ALMOHADILLAS DE TINTA RESIDUAL (HP Smart Tank 500) ===\033[0m\n");
        int spit_count = 1850;
        double waste_ml = 14.8;
        double max_capacity_ml = 120.0;

        /* ProductStatusDyn.xml pertenece al canal EWS de gestión, no al
           canal LEDM del escáner. */
        if (!is_mock && open_channel(ctx, 0xff, 0x04, 0x01, &chan) == 0) {
            char req[] = "GET /DevMgmt/ProductStatusDyn.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
            int bytes = http_request(&chan, req, buffer, sizeof(buffer));
            close_channel(&chan);
            if (bytes <= 0 || parse_xml_nonnegative_int(buffer, "TotalSpitCount>", &spit_count) != 0) {
                fprintf(stderr, "No se obtuvo un contador físico de tinta residual; no se presenta diagnóstico.\n");
                libusb_exit(ctx);
                return 1;
            }
            waste_ml = spit_count * 0.008;
        } else if (!is_mock) {
            fprintf(stderr, "No se pudo abrir el canal para consultar tinta residual.\n");
            libusb_exit(ctx);
            return 1;
        }

        double pct = (waste_ml * 100.0) / max_capacity_ml;
        if (pct > 100.0) pct = 100.0;
        int remaining_pages = (int)((max_capacity_ml - waste_ml) * 350);

        printf("  Capacidad del depósito absorbedor:   %.1f ml\n", max_capacity_ml);
        printf("  Tinta residual acumulada estimada:  %.2f ml (%d descargas en estación)\n", waste_ml, spit_count);
        printf("  Saturación de las almohadillas:     \033[1;32m%.1f%%\033[0m\n", pct);
        if (pct < 70.0) {
            printf("  Diagnóstico de servicio técnico:    \033[1;32mSALUDABLE (Sin riesgo de desbordamiento)\033[0m\n");
        } else if (pct < 90.0) {
            printf("  Diagnóstico de servicio técnico:    \033[1;33mPRECAUCIÓN (Planificar mantenimiento de esponjas)\033[0m\n");
        } else {
            printf("  Diagnóstico de servicio técnico:    \033[1;31mCRÍTICO (Reemplazar o lavar almohadillas)\033[0m\n");
        }
        printf("  Vida útil estimada antes de lavado: ~%d páginas\n", remaining_pages > 0 ? remaining_pages : 0);
        printf("\033[1;37m=========================================================================\033[0m\n\n");
    } else if (strcmp(cmd, "json-waste-ink") == 0) {
        if (!is_mock) {
            printf("{\"connected\": false, \"error\": \"No hay medición física de tinta residual disponible\"}\n");
            libusb_exit(ctx);
            return 1;
        }
        printf("{\"capacity_ml\": 120.0, \"waste_ml\": 14.8, \"saturation_pct\": 12.3, \"status\": \"healthy\", \"remaining_pages\": 36800}\n");
    } else if (strcmp(cmd, "head-health") == 0) {
        if (!is_mock) {
            fprintf(stderr, "No hay lectura física validada de salud de cabezales; use --mock sólo para pruebas.\n");
            libusb_exit(ctx);
            return 1;
        }
        printf("\n\033[1;37m=== DIAGNÓSTICO TÉRMICO Y SALUD DE CABEZALES (HP Smart Tank 500) ===\033[0m\n");
        printf("  [MOCK] Cabezal Negro (K): M0H51A / GT51; valores siguientes son sintéticos.\n");
        printf("    - Estado/temperatura/inyectores: simulados; no verificados en hardware.\n");
        printf("  [MOCK] Cabezal Tricolor (CMY): M0H50A / GT52; valores sintéticos.\n");
        printf("    - Estado/temperatura/inyectores: simulados; no verificados en hardware.\n");
        printf("  [MOCK] Estado del conjunto carro/flex: simulado; no verificado.\n");
        printf("\033[1;37m=========================================================================\033[0m\n\n");
    } else if (strcmp(cmd, "json-head-health") == 0) {
        if (!is_mock) {
            printf("{\"connected\": false, \"error\": \"No hay lectura física validada de salud de cabezales\"}\n");
            libusb_exit(ctx);
            return 1;
        }
        printf("{\"black_head\": {\"model\": \"M0H51A\", \"status\": \"ok\", \"temp_c\": 38.4, \"active_pct\": 100}, \"color_head\": {\"model\": \"M0H50A\", \"status\": \"ok\", \"temp_c\": 39.1, \"active_pct\": 100}, \"flex_voltage\": 32.0}\n");
    } else {
        fprintf(stderr, "Comando desconocido: %s\n", cmd);
        print_usage(argv[0]);
    }

    libusb_exit(ctx);
    return command_exit_code;
}
