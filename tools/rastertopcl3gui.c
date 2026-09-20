/*
 * rastertopcl3gui.c
 * Filtro CUPS nativo e independiente para HP Smart Tank 500 series en macOS Apple Silicon.
 * Convierte application/vnd.cups-raster en PCL3GUI Mode 10 sin HPLIP ni
 * dependencias Homebrew en runtime; utiliza libcups/libSystem del sistema.
 * Licencia: MIT
 */

#include <cups/cups.h>
#include <cups/raster.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#define UEL "\033%-12345X"
#define PJL_HEADER "@PJL SET STRINGCODESET=UTF8\n@PJL ENTER LANGUAGE=PCL3GUI\n"
#define PCL_RESET "\033E"
#define MEDIA_PRELOAD "\033&l-2H"
#define GRAPHICS_START "\033*r1A"
#define GRAPHICS_END "\033*rC"
#define PAGE_EJECT "\033&l0H\x0c"
#define PJL_EXIT "\033%-12345X@PJL EOJ\n\033%-12345X"

/* Tabla de fuentes bitmap 8x8 optimizada para marcas de agua RIP */
static const unsigned char font_letters[27][8] = {
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* ' ' (espacio) */
    {0x18,0x3C,0x66,0x66,0x7E,0x66,0x66,0x00}, /* A */
    {0x7C,0x66,0x66,0x7C,0x66,0x66,0x7C,0x00}, /* B */
    {0x3C,0x66,0x06,0x06,0x06,0x66,0x3C,0x00}, /* C */
    {0x78,0x6C,0x66,0x66,0x66,0x6C,0x78,0x00}, /* D */
    {0x7E,0x06,0x06,0x3E,0x06,0x06,0x7E,0x00}, /* E */
    {0x7E,0x06,0x06,0x3E,0x06,0x06,0x06,0x00}, /* F */
    {0x3C,0x66,0x06,0x76,0x66,0x66,0x3C,0x00}, /* G */
    {0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00}, /* H */
    {0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00}, /* I */
    {0x78,0x30,0x30,0x30,0x33,0x33,0x1E,0x00}, /* J */
    {0x66,0x36,0x1E,0x0E,0x1E,0x36,0x66,0x00}, /* K */
    {0x06,0x06,0x06,0x06,0x06,0x06,0x7E,0x00}, /* L */
    {0xC6,0xEE,0xFE,0xD6,0xC6,0xC6,0xC6,0x00}, /* M */
    {0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x00}, /* N */
    {0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00}, /* O */
    {0x7C,0x66,0x66,0x7C,0x06,0x06,0x06,0x00}, /* P */
    {0x3C,0x66,0x66,0x66,0x66,0x3C,0x78,0x00}, /* Q */
    {0x7C,0x66,0x66,0x7C,0x1E,0x36,0x66,0x00}, /* R */
    {0x3C,0x66,0x06,0x3C,0x60,0x66,0x3C,0x00}, /* S */
    {0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00}, /* T */
    {0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00}, /* U */
    {0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00}, /* V */
    {0xC6,0xC6,0xC6,0xD6,0xFE,0xEE,0xC6,0x00}, /* W */
    {0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00}, /* X */
    {0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x00}, /* Y */
    {0x7E,0x60,0x30,0x18,0x0C,0x06,0x7E,0x00}  /* Z */
};

/* Evalúa si el punto (x, y) pertenece a la marca de agua diagonal centrada */
static inline int is_watermark_pixel(int x, int y, int width, int height, const char *text) {
    if (!text || !text[0]) return 0;
    int len = (int)strlen(text);
    if (len == 0) return 0;

    int xc = width / 2;
    int yc = height / 2;
    int dx = x - xc;
    int dy = y - yc;

    /* Rotación diagonal a ~35 grados: cos(35) ~ 0.819, sin(35) ~ 0.573 */
    int u = (int)((float)dx * 0.819f + (float)dy * 0.573f);
    int v = (int)(-(float)dx * 0.573f + (float)dy * 0.819f);

    int scale = width / (len * 12);
    if (scale < 8) scale = 8;
    if (scale > 50) scale = 50;

    int half_height = 4 * scale;
    if (v < -half_height || v >= half_height) return 0;

    int total_width = len * 9 * scale;
    int half_width = total_width / 2;
    if (u < -half_width || u >= half_width) return 0;

    int u_offset = u + half_width;
    int char_idx = u_offset / (9 * scale);
    if (char_idx < 0 || char_idx >= len) return 0;

    int char_u = u_offset % (9 * scale);
    if (char_u >= 8 * scale) return 0; /* Espacio interletra */

    int font_col = char_u / scale;
    int font_row = (v + half_height) / scale;
    if (font_row < 0 || font_row >= 8 || font_col < 0 || font_col >= 8) return 0;

    char ch = text[char_idx];
    int font_char_idx = 0;
    if (ch >= 'A' && ch <= 'Z') font_char_idx = ch - 'A' + 1;
    else if (ch >= 'a' && ch <= 'z') font_char_idx = ch - 'a' + 1;

    return (font_letters[font_char_idx][font_row] & (0x80 >> font_col)) != 0;
}

/* Construye tabla de mapeo (LUT) para modulación de volumen, curvas tonales TRC y densidad */
static void build_advanced_lut(float scale, int curve_mode, unsigned char *lut) {
    if (scale <= 0.05f) scale = 1.0f;
    for (int i = 0; i < 256; i++) {
        double x = (double)i / 255.0;
        double tone = x;

        if (curve_mode == 1) {
            /* ShadowBoost: Levanta detalles en sombras profundas con curvatura en raíz */
            tone = 0.65 * x + 0.35 * sqrt(x);
        } else if (curve_mode == 2) {
            /* HighContrast: Curva sigmoidal S-Curve */
            if (x < 0.5) {
                tone = 2.0 * x * x;
            } else {
                tone = 1.0 - 2.0 * (1.0 - x) * (1.0 - x);
            }
            tone = 0.45 * x + 0.55 * tone;
        }

        /* Modulación de densidad de tinta */
        int ink = (int)((1.0 - tone) * 255.0 + 0.5);
        int new_ink;
        if (fabsf(scale - 1.0f) < 0.001f) {
            new_ink = ink;
        } else if (scale < 1.0f) {
            new_ink = (int)((float)ink * scale);
        } else {
            double normalized = (double)ink / 255.0;
            double boosted = pow(normalized, 1.0 / (double)scale);
            new_ink = (int)(boosted * 255.0 + 0.5);
        }
        if (new_ink < 0) new_ink = 0;
        if (new_ink > 255) new_ink = 255;
        lut[i] = (unsigned char)(255 - new_ink);
    }
}

/* Procesa un píxel aplicando Negro Puro (K), UCR, saturación y límite TAC */
static inline void process_pixel_pro(unsigned char *r, unsigned char *g, unsigned char *b,
                                     int pure_black_mode, int tac_limit, int is_vivid) {
    int R = *r, G = *g, B = *b;

    /* 1. Negro Puro K & UCR */
    if (pure_black_mode == 1) {
        /* TextOnly: Detectar tonos oscuros cuasi-neutros y forzar a K puro */
        int diff1 = abs(R - G);
        int diff2 = abs(G - B);
        if (diff1 <= 12 && diff2 <= 12 && R <= 40 && G <= 40 && B <= 40) {
            *r = 0; *g = 0; *b = 0;
            return;
        }
    } else if (pure_black_mode == 2) {
        /* AggressiveK con sustitución UCR */
        int c = 255 - R;
        int m = 255 - G;
        int y = 255 - B;
        int min_cmy = c;
        if (m < min_cmy) min_cmy = m;
        if (y < min_cmy) min_cmy = y;
        if (min_cmy > 35) {
            int ucr = (int)(min_cmy * 0.5);
            c -= ucr;
            m -= ucr;
            y -= ucr;
            R = 255 - c;
            G = 255 - m;
            B = 255 - y;
        }
    }

    /* 2. Expansión selectiva de Gamut VividLandscape */
    if (is_vivid) {
        if (G > R + 15 && G > B + 15) {
            G = (G * 115) / 100;
            if (G > 255) G = 255;
        } else if (B > R + 15 && B > G) {
            B = (B * 115) / 100;
            if (B > 255) B = 255;
        }
    }

    /* 3. Limitador de Cobertura Total de Tinta (TAC Limit) */
    if (tac_limit > 0) {
        int c = 255 - R;
        int m = 255 - G;
        int y = 255 - B;
        int total_ink = c + m + y;
        int max_allowed = (tac_limit * 765) / 300;
        if (total_ink > max_allowed && total_ink > 0) {
            float factor = (float)max_allowed / (float)total_ink;
            c = (int)((float)c * factor);
            m = (int)((float)m * factor);
            y = (int)((float)y * factor);
            R = 255 - c;
            G = 255 - m;
            B = 255 - y;
        }
    }

    *r = (unsigned char)R;
    *g = (unsigned char)G;
    *b = (unsigned char)B;
}

/* Motor InkSaver continuo: micro-perforación dot-gain, preservación de contornos y eliminación de fondo */
static void apply_ink_saver_pro(unsigned char *cur_row, const unsigned char *seed_row,
                                int width, int y, int saver_percent, int saver_mode, int color_drop_mode,
                                unsigned long long *input_units, unsigned long long *saved_units) {
    if (!cur_row || width <= 0) return;
    int prev_orig_r = cur_row[0];
    int prev_orig_g = cur_row[1];
    int prev_orig_b = cur_row[2];

    for (int x = 0; x < width; x++) {
        int orig_r = cur_row[x * 3];
        int orig_g = cur_row[x * 3 + 1];
        int orig_b = cur_row[x * 3 + 2];
        int r = orig_r;
        int g = orig_g;
        int b = orig_b;

        int ink_r = 255 - r;
        int ink_g = 255 - g;
        int ink_b = 255 - b;
        int ink_total = ink_r + ink_g + ink_b;

        if (ink_total == 0) {
            prev_orig_r = orig_r;
            prev_orig_g = orig_g;
            prev_orig_b = orig_b;
            continue;
        }
        if (input_units) *input_units += (unsigned long long)ink_total;

        /* 1. Filtro ecológico de color */
        if (color_drop_mode == 1) {
            /* DropColorBg: Detectar fondos tenues/pasteles de páginas web o diapositivas y llevarlos a blanco */
            if (r >= 165 && g >= 165 && b >= 165 && ink_total >= 10) {
                int left_diff = 0;
                if (x > 0) {
                    left_diff = abs(r - prev_orig_r) +
                                abs(g - prev_orig_g) +
                                abs(b - prev_orig_b);
                }
                if (left_diff <= 25) {
                    cur_row[x * 3] = 255;
                    cur_row[x * 3 + 1] = 255;
                    cur_row[x * 3 + 2] = 255;
                    if (saved_units) *saved_units += (unsigned long long)ink_total;
                    prev_orig_r = orig_r;
                    prev_orig_g = orig_g;
                    prev_orig_b = orig_b;
                    continue;
                }
            }
        } else if (color_drop_mode == 2) {
            /* EcoGrayscale: Reemplazar tintas CMY por canal K optimizado con -30% de atenuación */
            int Y = (299 * r + 587 * g + 114 * b) / 1000;
            int ink_k = 255 - Y;
            int eco_k = (ink_k * 70) / 100;
            int new_val = 255 - eco_k;
            r = new_val;
            g = new_val;
            b = new_val;
            if (ink_total > eco_k && saved_units) {
                *saved_units += (unsigned long long)(ink_total - eco_k);
            }
        }

        /* 2. Modos de ahorro InkSaver */
        int orig_px_ink = (255 - r) + (255 - g) + (255 - b);
        if (saver_mode == 4) {
            /* EdgePreserve: preserva bordes y atenúa el relleno en el raster. */
            int r_left = (x > 0) ? prev_orig_r : r;
            int g_left = (x > 0) ? prev_orig_g : g;
            int b_left = (x > 0) ? prev_orig_b : b;

            int r_right = (x < width - 1) ? cur_row[(x + 1) * 3] : r;
            int g_right = (x < width - 1) ? cur_row[(x + 1) * 3 + 1] : g;
            int b_right = (x < width - 1) ? cur_row[(x + 1) * 3 + 2] : b;

            int r_top = (seed_row) ? seed_row[x * 3] : r;
            int g_top = (seed_row) ? seed_row[x * 3 + 1] : g;
            int b_top = (seed_row) ? seed_row[x * 3 + 2] : b;

            int delta = abs(r - r_left) + abs(r - r_right) +
                        abs(g - g_left) + abs(g - g_right) +
                        abs(b - b_left) + abs(b - b_right) +
                        abs(r - r_top)  + abs(g - g_top)   + abs(b - b_top);

            if (delta > 45) {
                /* Contorno de letra o trazo vectorial fino: preservar nitidez raster. */
            } else {
                /* Relleno plano o interior: atenuar 48% de tinta */
                r = 255 - ((255 - r) * 52) / 100;
                g = 255 - ((255 - g) * 52) / 100;
                b = 255 - ((255 - b) * 52) / 100;
            }
        } else if (saver_mode == 5) {
            /* DotGainGrid: Micro-perforación explotando la ganancia de punto capilar del papel */
            if (orig_px_ink > 90) {
                if ((x + y) % 2 == 1) {
                    /* Atenuar punto alterno al 50%; el dot gain capilar cubre la micro-brecha */
                    r = 255 - ((255 - r) * 50) / 100;
                    g = 255 - ((255 - g) * 50) / 100;
                    b = 255 - ((255 - b) * 50) / 100;
                }
            }
        } else if (saver_percent > 0) {
            /* Motor InkSaver continuo (0% a 75%):
             * - Para texto y gráficos vectoriales: detección de bordes (delta > 45) para preservar contornos oscuros y nítidos.
             * - Para los interiores/rellenos: aplica la atenuación exacta correspondiente al porcentaje: 255 - ((255 - val) * (100 - percent)) / 100.
             */
            int r_left = (x > 0) ? prev_orig_r : r;
            int g_left = (x > 0) ? prev_orig_g : g;
            int b_left = (x > 0) ? prev_orig_b : b;

            int r_right = (x < width - 1) ? cur_row[(x + 1) * 3] : r;
            int g_right = (x < width - 1) ? cur_row[(x + 1) * 3 + 1] : g;
            int b_right = (x < width - 1) ? cur_row[(x + 1) * 3 + 2] : b;

            int r_top = (seed_row) ? seed_row[x * 3] : r;
            int g_top = (seed_row) ? seed_row[x * 3 + 1] : g;
            int b_top = (seed_row) ? seed_row[x * 3 + 2] : b;

            int delta = abs(r - r_left) + abs(r - r_right) +
                        abs(g - g_left) + abs(g - g_right) +
                        abs(b - b_left) + abs(b - b_right) +
                        abs(r - r_top)  + abs(g - g_top)   + abs(b - b_top);

            if (delta > 45) {
                /* Contorno de letra o trazo vectorial fino: preservar contornos oscuros y nítidos */
            } else {
                /* Atenuación nominal directa según porcentaje continuo en interiores y rellenos */
                r = 255 - ((255 - r) * (100 - saver_percent)) / 100;
                g = 255 - ((255 - g) * (100 - saver_percent)) / 100;
                b = 255 - ((255 - b) * (100 - saver_percent)) / 100;
            }
        }

        prev_orig_r = orig_r;
        prev_orig_g = orig_g;
        prev_orig_b = orig_b;

        cur_row[x * 3]     = (unsigned char)r;
        cur_row[x * 3 + 1] = (unsigned char)g;
        cur_row[x * 3 + 2] = (unsigned char)b;

        int new_px_ink = (255 - r) + (255 - g) + (255 - b);
        if (orig_px_ink > new_px_ink && saved_units) {
            *saved_units += (unsigned long long)(orig_px_ink - new_px_ink);
        }
    }
}

/* CRD sRGB Mode 10 */
static const unsigned char crd_color_mode10[18] = {
    0x1b, '*', 'g', '1', '2', 'W',
    0x06, 0x07, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x00,
    0x0a, 0x01, 0x20, 0x01
};

static void emit_vli(unsigned char **out, int val) {
    while (val >= 0) {
        if (val >= 255) {
            *(*out)++ = 255;
            val -= 255;
        } else {
            *(*out)++ = (unsigned char)val;
            break;
        }
    }
}

static inline void emit_raw_pixel(unsigned char **out, const unsigned char *px) {
    unsigned int r = px[0], g = px[1], b = px[2] & 0xFE;
    unsigned int packed = (r << 16) | (g << 8) | b;
    packed >>= 1;
    *(*out)++ = (unsigned char)(packed >> 16);
    *(*out)++ = (unsigned char)(packed >> 8);
    *(*out)++ = (unsigned char)(packed & 0xFF);
}

static inline void emit_short_delta(unsigned char **out, int dr, int dg, int db) {
    unsigned short val = (unsigned short)(0x8000U | ((unsigned int)(dr & 0x1F) << 10) |
                                          ((unsigned int)(dg & 0x1F) << 5) |
                                          ((unsigned int)(db / 2) & 0x1FU));
    *(*out)++ = (unsigned char)(val >> 8);
    *(*out)++ = (unsigned char)(val & 0xFF);
}

/* Compresión Mode 10 de una fila */
static int encode_mode10_row(const unsigned char *cur, const unsigned char *seed, int width, unsigned char *out) {
    if (memcmp(cur, seed, (size_t)width * 3U) == 0) return 0;

    unsigned char *p = out;
    int x = 0;

    while (x < width) {
        /* 1. Contar pixeles idénticos a la fila semilla */
        int seed_copy = 0;
        while (x < width && cur[x * 3] == seed[x * 3] && cur[x * 3 + 1] == seed[x * 3 + 1] && cur[x * 3 + 2] == seed[x * 3 + 2]) {
            seed_copy++;
            x++;
        }

        if (x >= width) break;

        /* 2. Comprobar racha RLE de pixeles iguales */
        const unsigned char *cur_px = &cur[x * 3];
        int rle_run = 1;
        while (x + rle_run < width &&
               cur[(x + rle_run) * 3] == cur_px[0] &&
               cur[(x + rle_run) * 3 + 1] == cur_px[1] &&
               cur[(x + rle_run) * 3 + 2] == cur_px[2]) {
            rle_run++;
        }

        const unsigned char *seed_px = &seed[x * 3];
        int dr = (int)cur_px[0] - (int)seed_px[0];
        int dg = (int)cur_px[1] - (int)seed_px[1];
        int db = (int)cur_px[2] - (int)seed_px[2];
        int is_sdelta = (-16 <= dr && dr <= 15 && -16 <= dg && dg <= 15 && -32 <= db && db <= 30 && (db % 2 == 0));

        if (rle_run >= 2) {
            int sc_field = (seed_copy > 3) ? 3 : seed_copy;
            int rc_field = (rle_run - 2 > 7) ? 7 : (rle_run - 2);
            *p++ = (unsigned char)(0x80U | ((unsigned int)sc_field << 3) | (unsigned int)rc_field);

            if (seed_copy >= 3) emit_vli(&p, seed_copy - 3);

            if (is_sdelta) emit_short_delta(&p, dr, dg, db);
            else emit_raw_pixel(&p, cur_px);

            if ((rle_run - 2) >= 7) emit_vli(&p, (rle_run - 2) - 7);

            x += rle_run;
        } else {
            int sc_field = (seed_copy > 3) ? 3 : seed_copy;
            *p++ = (unsigned char)((unsigned int)sc_field << 3);

            if (seed_copy >= 3) emit_vli(&p, seed_copy - 3);

            if (is_sdelta) emit_short_delta(&p, dr, dg, db);
            else emit_raw_pixel(&p, cur_px);

            x += 1;
        }
    }

    return (int)(p - out);
}

int main(int argc, char *argv[]) {
    if (argc < 6 || argc > 7) {
        fprintf(stderr, "ERROR: Uso: %s job-id user title copies options [file]\n", argv[0]);
        return 1;
    }

    int fd = 0; /* stdin */
    cups_raster_t *ras = NULL;
    cups_page_header2_t header;

    if (argc == 7) {
        fd = open(argv[6], O_RDONLY);
        if (fd < 0) {
            perror("ERROR: No se pudo abrir el archivo de entrada");
            return 1;
        }
    }

    ras = cupsRasterOpen(fd, CUPS_RASTER_READ);
    if (!ras) {
        fprintf(stderr, "ERROR: No se pudo inicializar CUPS Raster\n");
        if (fd > 0) close(fd);
        return 1;
    }

    /* Cabecera inicial de trabajo */
    fwrite(UEL, 1, strlen(UEL), stdout);
    fwrite(PJL_HEADER, 1, strlen(PJL_HEADER), stdout);

    /* Opciones globales de trabajo */
    const char *options = (argc >= 6) ? argv[5] : "";
    float default_density = 1.0f;
    int default_dry_time = 0;

    if (strstr(options, "HPDensity=Economy") || strstr(options, "density=economy") || strstr(options, "density=0.8")) default_density = 0.80f;
    else if (strstr(options, "HPDensity=Light") || strstr(options, "density=light") || strstr(options, "density=0.9")) default_density = 0.90f;
    else if (strstr(options, "HPDensity=Normal") || strstr(options, "density=normal") || strstr(options, "density=1.0")) default_density = 1.00f;
    else if (strstr(options, "HPDensity=High") || strstr(options, "density=high") || strstr(options, "density=1.1")) default_density = 1.10f;
    else if (strstr(options, "HPDensity=VeryHigh") || strstr(options, "density=veryhigh") || strstr(options, "density=1.2")) default_density = 1.20f;
    else if (strstr(options, "HPDensity=MaxTransfer") || strstr(options, "density=transfer") || strstr(options, "density=1.3")) default_density = 1.30f;

    if (strstr(options, "HPDryTime=Short") || strstr(options, "dry_time=5")) default_dry_time = 5;
    else if (strstr(options, "HPDryTime=Medium") || strstr(options, "dry_time=10")) default_dry_time = 10;
    else if (strstr(options, "HPDryTime=Long") || strstr(options, "dry_time=20")) default_dry_time = 20;
    else if (strstr(options, "HPDryTime=Maximum") || strstr(options, "dry_time=40")) default_dry_time = 40;

    int pure_black_mode = 0;
    if (strstr(options, "HPPureBlack=TextOnly") || strstr(options, "pure_black=textonly")) pure_black_mode = 1;
    else if (strstr(options, "HPPureBlack=AggressiveK") || strstr(options, "pure_black=aggressivek")) pure_black_mode = 2;

    int tac_limit = 0;
    if (strstr(options, "HPTACLimit=TAC240") || strstr(options, "tac=240")) tac_limit = 240;
    else if (strstr(options, "HPTACLimit=TAC280") || strstr(options, "tac=280")) tac_limit = 280;
    else if (strstr(options, "HPTACLimit=TAC300") || strstr(options, "tac=300")) tac_limit = 300;

    int gamma_curve_mode = 0;
    if (strstr(options, "HPGammaCurve=ShadowBoost") || strstr(options, "gamma=shadowboost")) gamma_curve_mode = 1;
    else if (strstr(options, "HPGammaCurve=HighContrast") || strstr(options, "gamma=highcontrast")) gamma_curve_mode = 2;
    else if (strstr(options, "HPGammaCurve=VividLandscape") || strstr(options, "gamma=vivid")) gamma_curve_mode = 3;

    const char *watermark_text = NULL;
    if (strstr(options, "HPWatermark=Draft") || strstr(options, "watermark=draft")) watermark_text = "BORRADOR";
    else if (strstr(options, "HPWatermark=Confidential") || strstr(options, "watermark=confidential")) watermark_text = "CONFIDENCIAL";
    else if (strstr(options, "HPWatermark=Copy") || strstr(options, "watermark=copy")) watermark_text = "COPIA";
    else if (strstr(options, "HPWatermark=Sample") || strstr(options, "watermark=sample")) watermark_text = "MUESTRA";

    int cli_output_mode = -1; /* -1 = auto de raster header; 1 = Draft, 2 = Normal, 3 = Best, 4 = Photo */
    if (strstr(options, "OutputMode=FastDraft") || strstr(options, "outputmode=fastdraft") ||
        strstr(options, "OutputMode=Draft") || strstr(options, "outputmode=draft") ||
        strstr(options, "quality=draft") || strstr(options, "quality=fastdraft")) cli_output_mode = 1;
    else if (strstr(options, "OutputMode=Normal") || strstr(options, "outputmode=normal")) cli_output_mode = 2;
    else if (strstr(options, "OutputMode=Best") || strstr(options, "outputmode=best")) cli_output_mode = 3;
    else if (strstr(options, "OutputMode=PhotoMaster") || strstr(options, "outputmode=photomaster") ||
             strstr(options, "OutputMode=Photo") || strstr(options, "outputmode=photo") ||
             strstr(options, "quality=photo")) cli_output_mode = 4;

    int ink_saver_mode = 0;
    int ink_saver_percent = 0;
    char ink_saver_label[32] = "Off";
    char ink_saver_desc[64] = "Desactivado";

    const char *p_saver = NULL;
    if ((p_saver = strstr(options, "HPInkSaver=")) != NULL) p_saver += 11;
    else if ((p_saver = strstr(options, "hpinksaver=")) != NULL) p_saver += 11;
    else if ((p_saver = strstr(options, "ink_saver=")) != NULL) p_saver += 10;
    else if ((p_saver = strstr(options, "InkSaver=")) != NULL) p_saver += 9;
    else if ((p_saver = strstr(options, "inksaver=")) != NULL) p_saver += 9;

    if (p_saver) {
        if (strncasecmp(p_saver, "Off", 3) == 0 || strncmp(p_saver, "0", 1) == 0) {
            ink_saver_mode = 0;
            ink_saver_percent = 0;
            snprintf(ink_saver_label, sizeof(ink_saver_label), "Off");
            snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Desactivado");
        } else if (strncasecmp(p_saver, "EdgePreserve", 12) == 0 || strncasecmp(p_saver, "edge", 4) == 0) {
            ink_saver_mode = 4;
            ink_saver_percent = 35;
            snprintf(ink_saver_label, sizeof(ink_saver_label), "EdgePreserve");
            snprintf(ink_saver_desc, sizeof(ink_saver_desc), "EdgePreserve (bordes preservados)");
        } else if (strncasecmp(p_saver, "DotGainGrid", 11) == 0 || strncasecmp(p_saver, "dotgain", 7) == 0) {
            ink_saver_mode = 5;
            ink_saver_percent = 50;
            snprintf(ink_saver_label, sizeof(ink_saver_label), "DotGainGrid");
            snprintf(ink_saver_desc, sizeof(ink_saver_desc), "DotGainGrid (Micro-perforado Dot-Gain)");
        } else if (strncasecmp(p_saver, "Eco", 3) == 0) {
            long val = strtol(p_saver + 3, NULL, 10);
            if (val < 0) val = 0;
            else if (val > 75) val = 75;
            ink_saver_percent = (int)val;
            if (val == 0) {
                ink_saver_mode = 0;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Off");
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Desactivado");
            } else if (val == 25) {
                ink_saver_mode = 1;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Eco25");
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Eco25 (nivel raster 1)");
            } else if (val == 50) {
                ink_saver_mode = 2;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Eco50");
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Eco50 (nivel raster 2)");
            } else if (val == 75) {
                ink_saver_mode = 3;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Eco75");
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Eco75 (nivel raster 3)");
            } else {
                ink_saver_mode = 6;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Eco%d", ink_saver_percent);
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Eco%d (%d%% ahorro)", ink_saver_percent, ink_saver_percent);
            }
        } else if (*p_saver == '-' || (*p_saver >= '0' && *p_saver <= '9')) {
            long val = strtol(p_saver, NULL, 10);
            if (val < 0) val = 0;
            else if (val > 75) val = 75;
            ink_saver_percent = (int)val;
            if (val == 0) {
                ink_saver_mode = 0;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Off");
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Desactivado");
            } else if (val == 25) {
                ink_saver_mode = 1;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Eco25");
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Eco25 (nivel raster 1)");
            } else if (val == 50) {
                ink_saver_mode = 2;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Eco50");
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Eco50 (nivel raster 2)");
            } else if (val == 75) {
                ink_saver_mode = 3;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Eco75");
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Eco75 (nivel raster 3)");
            } else {
                ink_saver_mode = 6;
                snprintf(ink_saver_label, sizeof(ink_saver_label), "Eco%d", ink_saver_percent);
                snprintf(ink_saver_desc, sizeof(ink_saver_desc), "Eco%d (%d%% ahorro)", ink_saver_percent, ink_saver_percent);
            }
        }
    }

    int eco_color_drop = 0;
    if (strstr(options, "HPEcoColorDrop=DropColorBg") || strstr(options, "color_drop=bg")) eco_color_drop = 1;
    else if (strstr(options, "HPEcoColorDrop=EcoGrayscale") || strstr(options, "color_drop=gray")) eco_color_drop = 2;

    int page_count = 0;
    int processing_error = 0;
    unsigned char *cur_row = NULL;
    unsigned char *seed_row = NULL;
    unsigned char *comp_buf = NULL;
    unsigned char *in_buf = NULL;
    size_t alloc_row_bytes = 0;
    size_t alloc_comp_bytes = 0;
    size_t alloc_in_bytes = 0;

    while (cupsRasterReadHeader2(ras, &header)) {
        page_count++;
        if (header.cupsWidth > (unsigned int)INT_MAX || header.cupsHeight > (unsigned int)INT_MAX) {
            fprintf(stderr, "ERROR: [rastertopcl3gui] Dimensiones fuera de rango\n");
            processing_error = 1;
            break;
        }
        int width = (int)header.cupsWidth;
        int height = (int)header.cupsHeight;
        int dpi = (header.HWResolution[0] > 0U && header.HWResolution[0] <= (unsigned int)INT_MAX) ?
                  (int)header.HWResolution[0] : 600;

        float page_density = (header.cupsReal[0] >= 0.5f && header.cupsReal[0] <= 2.0f) ? header.cupsReal[0] : default_density;
        int page_dry_time = (header.cupsInteger[7] > 0) ? (int)header.cupsInteger[7] : default_dry_time;

        unsigned char density_lut[256];
        build_advanced_lut(page_density, gamma_curve_mode, density_lut);
        int apply_density = (fabsf(page_density - 1.0f) >= 0.001f || gamma_curve_mode == 1 || gamma_curve_mode == 2);
        int is_vivid = (gamma_curve_mode == 3);

        const char *sm_dbg = ink_saver_label;
        const char *cd_dbg = (eco_color_drop == 1) ? "DropColorBg" :
                             (eco_color_drop == 2) ? "EcoGrayscale" : "None";

        fprintf(stderr, "DEBUG: [rastertopcl3gui] Procesando Pagina %d: %dx%d a %d DPI (Densidad: %.2fx, Secado: %ds, NegroPuro: %d, TAC: %d, Gamma: %d, MarcaAgua: %s, InkSaver: %s, ColorDrop: %s)\n",
                page_count, width, height, dpi, page_density, page_dry_time,
                pure_black_mode, tac_limit, gamma_curve_mode, watermark_text ? watermark_text : "Ninguna",
                sm_dbg, cd_dbg);

        if (width <= 0 || height <= 0 || width > 30000 || height > 60000) {
            fprintf(stderr, "ERROR: [rastertopcl3gui] Dimensiones de pagina invalidas (%dx%d)\n", width, height);
            processing_error = 1;
            break;
        }

        int is_gray = (header.cupsBitsPerPixel == 8 ||
                       header.cupsColorSpace == CUPS_CSPACE_K ||
                       header.cupsColorSpace == CUPS_CSPACE_W ||
                       header.cupsColorSpace == CUPS_CSPACE_SW);
        int is_cmyk = (header.cupsBitsPerPixel == 32 &&
                       (header.cupsColorSpace == CUPS_CSPACE_CMYK ||
                        header.cupsColorSpace == CUPS_CSPACE_KCMY));
        int is_rgbw = (header.cupsBitsPerPixel == 32 &&
                       (header.cupsColorSpace == CUPS_CSPACE_RGBW ||
                        header.cupsColorSpace == CUPS_CSPACE_RGBA));

        if (!is_gray && !is_cmyk && !is_rgbw && header.cupsBitsPerPixel != 24) {
            fprintf(stderr, "ERROR: [rastertopcl3gui] Profundidad de color no soportada (%d bpp, colorspace %d). Se requiere 8-bit Gray, 24-bit sRGB, 32-bit RGBW o 32-bit CMYK.\n",
                    header.cupsBitsPerPixel, header.cupsColorSpace);
            processing_error = 1;
            break;
        }

        if (header.cupsBytesPerLine > 300000) {
            fprintf(stderr, "ERROR: [rastertopcl3gui] cupsBytesPerLine excesivo (%u)\n", header.cupsBytesPerLine);
            processing_error = 1;
            break;
        }

        if (is_gray && header.cupsBytesPerLine < (unsigned int)width) {
            fprintf(stderr, "ERROR: [rastertopcl3gui] cupsBytesPerLine (%u) < width (%d)\n",
                    header.cupsBytesPerLine, width);
            processing_error = 1;
            break;
        }

        if (is_cmyk && header.cupsBytesPerLine < (unsigned int)width * 4) {
            fprintf(stderr, "ERROR: [rastertopcl3gui] cupsBytesPerLine (%u) < width * 4 (%d)\n",
                    header.cupsBytesPerLine, width * 4);
            processing_error = 1;
            break;
        }

        if (is_rgbw && header.cupsBytesPerLine < (unsigned int)width * 4) {
            fprintf(stderr, "ERROR: [rastertopcl3gui] cupsBytesPerLine (%u) < width * 4 (%d)\n",
                    header.cupsBytesPerLine, width * 4);
            processing_error = 1;
            break;
        }

        /* Determinar ID de medio PCL según PPD cupsInteger0 o dimensiones de página de CUPS */
        int media_id = 26; /* A4 por defecto */
        if (header.cupsInteger[0] > 0 && header.cupsInteger[0] <= 200) {
            media_id = (int)header.cupsInteger[0];
        } else if (header.PageSize[1] > 1050) {
            media_id = 101;   /* Custom / Continuous Roll Banner (hasta 44" / 1117mm) */
        } else if (header.PageSize[1] >= 1000 && header.PageSize[1] <= 1020) {
            media_id = 3;     /* Legal / Oficio Americano (8.5 x 14 in / 1008 pt) */
        } else if (header.PageSize[1] >= 925 && header.PageSize[1] <= 950) {
            media_id = 10;    /* Oficio Chile / LATAM / Folio (8.5 x 13 in / 936 pt) */
        } else if (header.PageSize[1] >= 835 && header.PageSize[1] <= 850) {
            media_id = 26;    /* A4 (210 x 297 mm / 841.68 pt) */
        } else if (header.PageSize[1] >= 780 && header.PageSize[1] <= 800) {
            media_id = 2;     /* Carta / Letter (8.5 x 11 in / 792 pt) */
        } else if (header.PageSize[1] >= 710 && header.PageSize[1] <= 745) {
            media_id = 100;   /* B5 / JB5 */
        } else if (header.PageSize[1] >= 585 && header.PageSize[1] <= 605) {
            media_id = 25;    /* A5 (148 x 210 mm / 595.44 pt) */
        } else if (header.PageSize[1] >= 495 && header.PageSize[1] <= 515) {
            media_id = 122;   /* 5x7 in (13 x 18 cm / 504 pt) */
        } else if (header.PageSize[1] >= 410 && header.PageSize[1] <= 445) {
            media_id = (header.PageSize[0] < 310 && header.PageSize[1] < 430) ? 24 : 74;  /* A6 (297.84x419.52 pt) o 4x6 in (288x432 pt) */
        }

        /* 1. Detección de impresión fotográfica sin bordes (.FB) */
        int is_borderless = 0;
        if (header.cupsImagingBBox[0] == 0.0f && header.cupsImagingBBox[1] == 0.0f &&
            (header.cupsImagingBBox[2] == (float)header.PageSize[0] || strstr(header.cupsPageSizeName, "FB") != NULL)) {
            is_borderless = 1;
        }
        if (strstr(header.cupsPageSizeName, ".FB") != NULL || strstr(header.cupsPageSizeName, "Borderless") != NULL) {
            is_borderless = 1;
        }

        /* 2. Determinar calidad de impresión PCL (Draft=1, Normal=2, Best=3, Photo=4) */
        int quality_cmd = 2; /* Normal */
        if (cli_output_mode > 0) {
            quality_cmd = cli_output_mode;
        } else if (header.OutputType[0] == '3' || dpi <= 300) {
            quality_cmd = 1; /* Draft / Borrador Rápido */
        } else if (header.OutputType[0] == '1') {
            quality_cmd = 3; /* Best */
        } else if (header.OutputType[0] == '2' || dpi >= 1200 || header.cupsMediaType == 5 || header.cupsMediaType == 8) {
            quality_cmd = 4; /* Photo */
        }

        /* 3. Determinar tipo y subtipo de medio (P15_CISS) */
        int media_type = (header.cupsMediaType > 0) ? (int)header.cupsMediaType : 0;
        int media_subtype = (header.cupsInteger[5] > 0) ? (int)header.cupsInteger[5] : 1084;
        if (media_type == 5 && media_subtype == 1084) media_subtype = 1069; /* HP Photo Papers */

        /* 4. Emisión de cabecera de página PCL3GUI */
        fwrite(PCL_RESET, 1, strlen(PCL_RESET), stdout);
        printf("\033&l1H\033&l%dM\033&l%dA\033*o%dM", media_type, media_id, quality_cmd);
        fprintf(stderr, "DEBUG: [rastertopcl3gui] PageSize: %ux%u pt, media_id: %d, media_type: %d\n",
                header.PageSize[0], header.PageSize[1], media_id, media_type);

        /* Media Subtype Seq: Esc*o5W 0D 03 00 [hi] [lo] */
        unsigned char subtype_seq[10] = {0x1b, '*', 'o', '5', 'W', 0x0D, 0x03, 0x00,
                                         (unsigned char)((media_subtype >> 8) & 0xFF),
                                         (unsigned char)(media_subtype & 0xFF)};
        fwrite(subtype_seq, 1, 10, stdout);

        /* GrayscaleSeq: transformación de salida; no demuestra control exclusivo de inyectores. */
        if (is_gray || header.cupsRowStep > 0) {
            unsigned char gray_mode = (header.cupsRowStep == 2) ? 0x01 :
                                      ((header.cupsRowStep == 1) ? 0x02 :
                                      ((header.cupsColorSpace == CUPS_CSPACE_K) ? 0x01 : 0x02));
            unsigned char gray_seq[10] = {0x1b, '*', 'o', '5', 'W', 0x0B, 0x01, 0x00, 0x00, gray_mode};
            fwrite(gray_seq, 1, 10, stdout);
        }

        /* Top Edge Overspray para SPD (HPSPDClass == 1): Esc*o5W 0E 0D 00 00 01 */
        if (is_borderless) {
            unsigned char top_overspray[10] = {0x1b, 0x2A, 0x6F, 0x35, 0x57, 0x0E, 0x0D, 0x00, 0x00, 0x01};
            fwrite(top_overspray, 1, 10, stdout);
        }

        /* Extra Dry Time PML sequence: Esc & b 16 W P M L [11 bytes] [1 byte sec] */
        if (page_dry_time > 0) {
            unsigned char dry_cmd[22] = {0x1b, '&', 'b', '1', '6', 'W', 'P', 'M', 'L', ' ',
                                         0x04, 0x00, 0x06, 0x01, 0x04, 0x01, 0x04, 0x01, 0x06,
                                         0x08, 0x01, (unsigned char)(page_dry_time & 0xFF)};
            fwrite(dry_cmd, 1, sizeof(dry_cmd), stdout);
            fprintf(stderr, "DEBUG: [rastertopcl3gui] Tiempo de secado PML activo: %d seg\n", page_dry_time);
        }

        /* CRD sRGB Mode 10 con resolucion horizontal y vertical correcta */
        unsigned char crd[18];
        memcpy(crd, crd_color_mode10, 18);
        crd[10] = (unsigned char)((dpi >> 8) & 0xFF);
        crd[11] = (unsigned char)(dpi & 0xFF);
        crd[12] = (unsigned char)((dpi >> 8) & 0xFF);
        crd[13] = (unsigned char)(dpi & 0xFF);
        fwrite(crd, 1, sizeof(crd), stdout);

        printf("\033&u%dD\033*t%dR\033*r%dS", dpi, dpi, width);
        fwrite(MEDIA_PRELOAD, 1, strlen(MEDIA_PRELOAD), stdout);
        fwrite(GRAPHICS_START, 1, strlen(GRAPHICS_START), stdout);

        size_t row_bytes = (size_t)width * 3;
        size_t comp_needed = (size_t)width * 5 + 2048;
        size_t in_needed = header.cupsBytesPerLine;

        if (row_bytes > alloc_row_bytes) {
            unsigned char *n_cur = (unsigned char *)realloc(cur_row, row_bytes);
            unsigned char *n_seed = (unsigned char *)realloc(seed_row, row_bytes);
            if (!n_cur || !n_seed) {
                fprintf(stderr, "ERROR: [rastertopcl3gui] Error reasignando memoria de fila\n");
                if (n_cur) cur_row = n_cur;
                if (n_seed) seed_row = n_seed;
                processing_error = 1;
                break;
            }
            cur_row = n_cur;
            seed_row = n_seed;
            alloc_row_bytes = row_bytes;
        }

        if (comp_needed > alloc_comp_bytes) {
            unsigned char *n_comp = (unsigned char *)realloc(comp_buf, comp_needed);
            if (!n_comp) {
                fprintf(stderr, "ERROR: [rastertopcl3gui] Error reasignando memoria comp_buf\n");
                processing_error = 1;
                break;
            }
            comp_buf = n_comp;
            alloc_comp_bytes = comp_needed;
        }

        if (in_needed > alloc_in_bytes && in_needed > 0) {
            unsigned char *n_in = (unsigned char *)realloc(in_buf, in_needed);
            if (!n_in) {
                fprintf(stderr, "ERROR: [rastertopcl3gui] Error reasignando memoria in_buf\n");
                processing_error = 1;
                break;
            }
            in_buf = n_in;
            alloc_in_bytes = in_needed;
        }

        memset(seed_row, 0xFF, row_bytes);
        int blank_rows = 0;
        unsigned long long page_input_ink = 0;
        unsigned long long page_saved_ink = 0;

        for (int y = 0; y < height; y++) {
            if (is_gray && in_buf) {
                if (cupsRasterReadPixels(ras, in_buf, header.cupsBytesPerLine) == 0) {
                    fprintf(stderr, "ERROR: [rastertopcl3gui] Lectura raster incompleta\n");
                    processing_error = 1;
                    break;
                }
                // Expandir escala de grises de 8 bits a sRGB de 24 bits
                for (int x = 0; x < width; x++) {
                    unsigned char val = in_buf[x];
                    if (header.cupsColorSpace == CUPS_CSPACE_K) {
                        val = 255 - val; // CUPS_CSPACE_K: 0=blanco, 255=negro
                    }
                    cur_row[x * 3]     = val;
                    cur_row[x * 3 + 1] = val;
                    cur_row[x * 3 + 2] = val;
                }
            } else if (is_cmyk && in_buf) {
                if (cupsRasterReadPixels(ras, in_buf, header.cupsBytesPerLine) == 0) {
                    fprintf(stderr, "ERROR: [rastertopcl3gui] Lectura raster incompleta\n");
                    processing_error = 1;
                    break;
                }
                // Transformar CMYK de 32 bits a sRGB de 24 bits con compensación de negro K
                for (int x = 0; x < width; x++) {
                    int c = in_buf[x * 4];
                    int m = in_buf[x * 4 + 1];
                    int y_c = in_buf[x * 4 + 2];
                    int k = in_buf[x * 4 + 3];

                    int r = 255 - ((c * (255 - k)) / 255 + k);
                    int g = 255 - ((m * (255 - k)) / 255 + k);
                    int b = 255 - ((y_c * (255 - k)) / 255 + k);

                    cur_row[x * 3]     = (unsigned char)(r < 0 ? 0 : (r > 255 ? 255 : r));
                    cur_row[x * 3 + 1] = (unsigned char)(g < 0 ? 0 : (g > 255 ? 255 : g));
                    cur_row[x * 3 + 2] = (unsigned char)(b < 0 ? 0 : (b > 255 ? 255 : b));
                }
            } else if (is_rgbw && in_buf) {
                if (cupsRasterReadPixels(ras, in_buf, header.cupsBytesPerLine) == 0) {
                    fprintf(stderr, "ERROR: [rastertopcl3gui] Lectura raster incompleta\n");
                    processing_error = 1;
                    break;
                }
                // Desempaquetar RGBW / RGBA de 32 bits a sRGB de 24 bits con composición sobre papel blanco
                for (int x = 0; x < width; x++) {
                    int r = in_buf[x * 4];
                    int g = in_buf[x * 4 + 1];
                    int b = in_buf[x * 4 + 2];
                    int fourth = in_buf[x * 4 + 3];

                    if (header.cupsColorSpace == CUPS_CSPACE_RGBA) {
                        /* RGBA: Alfa sobre fondo blanco de papel */
                        if (fourth < 255) {
                            r = (r * fourth + 255 * (255 - fourth)) / 255;
                            g = (g * fourth + 255 * (255 - fourth)) / 255;
                            b = (b * fourth + 255 * (255 - fourth)) / 255;
                        }
                    } else if (header.cupsColorSpace == CUPS_CSPACE_RGBW) {
                        /* RGBW: Componente W (White). En sustracción sobre papel blanco,
                           el blanco adicional modula hacia el blanco del sustrato */
                        if (fourth > 0) {
                            r = (r * (255 - fourth) + 255 * fourth) / 255;
                            g = (g * (255 - fourth) + 255 * fourth) / 255;
                            b = (b * (255 - fourth) + 255 * fourth) / 255;
                        }
                    }

                    cur_row[x * 3]     = (unsigned char)(r < 0 ? 0 : (r > 255 ? 255 : r));
                    cur_row[x * 3 + 1] = (unsigned char)(g < 0 ? 0 : (g > 255 ? 255 : g));
                    cur_row[x * 3 + 2] = (unsigned char)(b < 0 ? 0 : (b > 255 ? 255 : b));
                }
            } else {
                if (row_bytes > (size_t)UINT_MAX || cupsRasterReadPixels(ras, cur_row, (unsigned int)row_bytes) == 0) {
                    fprintf(stderr, "ERROR: [rastertopcl3gui] Lectura raster incompleta\n");
                    processing_error = 1;
                    break;
                }
            }

            /* Procesamiento profesional por píxel: Negro Puro, TAC limit, Gamma/Vivid */
            if (pure_black_mode > 0 || tac_limit > 0 || is_vivid) {
                for (int x = 0; x < width; x++) {
                    process_pixel_pro(&cur_row[x * 3], &cur_row[x * 3 + 1], &cur_row[x * 3 + 2],
                                      pure_black_mode, tac_limit, is_vivid);
                }
            }

            /* Procesamiento ecológico InkSaver & ColorDrop */
            if (ink_saver_percent > 0 || ink_saver_mode > 0 || eco_color_drop > 0) {
                apply_ink_saver_pro(cur_row, (y > 0) ? seed_row : NULL, width, y,
                                    ink_saver_percent, ink_saver_mode, eco_color_drop,
                                    &page_input_ink, &page_saved_ink);
            }

            if (apply_density) {
                for (size_t i = 0; i < row_bytes; i++) {
                    cur_row[i] = density_lut[cur_row[i]];
                }
            }

            /* Marca de agua RIP translúcida en la pasada */
            if (watermark_text) {
                for (int x = 0; x < width; x++) {
                    if (is_watermark_pixel(x, y, width, height, watermark_text)) {
                        cur_row[x * 3]     = (unsigned char)((cur_row[x * 3]     * 82 + 215 * 18) / 100);
                        cur_row[x * 3 + 1] = (unsigned char)((cur_row[x * 3 + 1] * 82 + 215 * 18) / 100);
                        cur_row[x * 3 + 2] = (unsigned char)((cur_row[x * 3 + 2] * 82 + 215 * 18) / 100);
                    }
                }
            }

            /* Comprobar si la fila es blanca (fondo) con aceleración para Borrador (Draft) */
            int is_white = 1;
            int white_thresh = (quality_cmd == 1) ? 250 : 255;
            for (size_t i = 0; i < row_bytes; i++) {
                if (cur_row[i] < (unsigned char)white_thresh) {
                    is_white = 0;
                    break;
                }
            }

            if (is_white) {
                blank_rows++;
                continue;
            }

            if (blank_rows > 0) {
                printf("\033*b%dY", blank_rows);
                blank_rows = 0;
                memset(seed_row, 0xFF, row_bytes); /* En PCL3GUI, el salto vertical reinicia la semilla del hardware a blanco */
            }

            int payload_len = encode_mode10_row(cur_row, seed_row, width, comp_buf);
            printf("\033*b%dW", payload_len);
            if (payload_len > 0) {
                fwrite(comp_buf, 1, (size_t)payload_len, stdout);
            }
            memcpy(seed_row, cur_row, row_bytes);
        }

        fwrite(GRAPHICS_END, 1, strlen(GRAPHICS_END), stdout);
        fwrite(PAGE_EJECT, 1, strlen(PAGE_EJECT), stdout);

        if (ink_saver_percent > 0 || ink_saver_mode > 0 || eco_color_drop > 0) {
            double pct = (page_input_ink > 0) ? ((double)page_saved_ink * 100.0 / (double)page_input_ink) : 0.0;
            const char *sm_name = ink_saver_desc;
            const char *cd_name = (eco_color_drop == 1) ? "DropColorBg (Fondo Web/Diapositivas Eliminado)" :
                                  (eco_color_drop == 2) ? "EcoGrayscale (Escala Grises Eco)" : "Ninguno";
            fprintf(stderr, "INFO: [rastertopcl3gui] InkSaver: Pagina %d (Modo: %s, ColorDrop: %s) -> Reduccion raster estimada (no tinta fisica): %.1f%%\n",
                    page_count, sm_name, cd_name, pct);
        }
    }

    /* Liberación global de memoria */
    free(cur_row);
    free(seed_row);
    free(comp_buf);
    free(in_buf);

    fwrite(PJL_EXIT, 1, strlen(PJL_EXIT), stdout);
    fflush(stdout);

    cupsRasterClose(ras);
    if (fd > 0) close(fd);

    if (processing_error) {
        fprintf(stderr, "ERROR: [rastertopcl3gui] Trabajo rechazado tras %d paginas procesadas.\n", page_count);
        return 1;
    }
    fprintf(stderr, "INFO: [rastertopcl3gui] Finalizado exitosamente. %d paginas procesadas.\n", page_count);
    return 0;
}
