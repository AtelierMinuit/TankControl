/* Offline libFuzzer harness for the native Mode10 row encoder.
 * No USB, CUPS device, filesystem, or maintenance operation is touched.
 */
#define main rastertopcl3gui_program_main
#include "rastertopcl3gui.c"
#undef main

#include <stdint.h>
#include <stdlib.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (data == NULL || size < 2U) return 0;

    const int width = 1 + (int)(data[0] % 64U);
    const size_t row_bytes = (size_t)width * 3U;
    unsigned char cur[64U * 3U] = {0};
    unsigned char seed[64U * 3U] = {0};
    unsigned char encoded[4096U] = {0};

    for (size_t i = 0; i < row_bytes; ++i) {
        const uint8_t v = data[1U + (i % (size - 1U))];
        cur[i] = v;
        seed[i] = (uint8_t)(v ^ (uint8_t)(i * 17U));
    }

    const int encoded_size = encode_mode10_row(cur, seed, width, encoded);
    if (encoded_size < 0 || encoded_size > (int)sizeof(encoded)) abort();
    return 0;
}
