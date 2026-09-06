#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

static uint32_t next_u32(uint32_t *state) {
    *state = *state * 1664525U + 1013904223U;
    return *state;
}

int main(void) {
    uint8_t input[256];
    uint32_t state = 20260904U;
    for (unsigned int round = 0; round < 100000U; ++round) {
        const size_t size = (size_t)(next_u32(&state) % sizeof(input));
        for (size_t i = 0; i < size; ++i) {
            input[i] = (uint8_t)next_u32(&state);
            if ((round % 11U) == 0U && i > 0U) input[i] = input[i - 1U];
            if ((round % 17U) == 0U) input[i] = (uint8_t)(i * 13U);
        }
        (void)LLVMFuzzerTestOneInput(input, size);
    }
    puts("MODE10_SANITIZER_MUTATION_ROUNDS=100000 PASS");
    return 0;
}
