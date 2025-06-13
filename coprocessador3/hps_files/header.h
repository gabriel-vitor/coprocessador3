#ifndef HEADER_H
#define HEADER_H
#include <stdint.h>

//CONSTANTES
#define HW_SUCCESS      0
#define HW_INIT_FAIL   -1
#define HW_SEND_FAIL   -2
#define HW_READ_FAIL   -3

//ESTRUTURAS
struct Params {
    const int8_t* a;
    const int8_t* b;
    uint32_t opcode;
    uint32_t size;
    int32_t scalar;
};

//FUNÇÕES DO ASSEMBLY
extern int begin_hw(void);

extern int end_hw(void);

extern int send_data(const struct Params* p);

extern int read_results(int8_t* result, uint8_t* overflow_flag);

#endif
