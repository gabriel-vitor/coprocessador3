#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "header.h"

// Define a dimensão total da matriz quadrada (5x5)
#define MATRIX_SIZE 25

/**
 * Imprime uma matriz formatada com delimitação de linhas e colunas.
 * @param label   Etiqueta que será exibida antes da matriz.
 * @param matrix  Ponteiro para o buffer linear contendo os elementos.
 * @param size    Ordem da matriz (ex.: 3 para 3x3, 0..3 permitido).
 */
void print_matrix(const char* label, const int8_t* matrix, int size) {
    // n = ordem da matriz + 2
    uint8_t n = (uint8_t)size + 2;
    uint8_t total = n * n;
    printf("%s (ordem=%u):\n", label, n);

    // Itera por todos os slots do buffer linear
    for (uint8_t idx = 0; idx < total; ++idx) {
        // A cada início de nova linha, imprime o delimitador esquerdo
        if (idx % n == 0) {
            printf("| ");
        }
        // Exibe valor com largura fixa para alinhamento
        printf("%4d", matrix[idx]);
        // Se não for fim de linha, separa com vírgula
        if ((idx + 1) % n != 0) {
            printf(",");
        } else {
            // Delimitador direito ao fim da linha
            printf(" |\n");
        }
    }
    printf("\n");
}

/**
 * Valida se o código de operação e tamanho da matriz estão dentro dos limites suportados.
 * @param op_code     Código da operação (0..7 válido).
 * @param matrix_size Ordem da matriz (0..3 válido).
 * @return HW_SUCCESS se tudo for válido, HW_SEND_FAIL caso contrário.
 */
int validate_operation(uint32_t op_code, uint32_t matrix_size) {
    if (op_code > 7) {
        fprintf(stderr, "Erro: código de operação inválido (%u). Deve estar entre 0 e 7.\n", op_code);
        return HW_SEND_FAIL;
    }
    if (matrix_size > 3) {
        fprintf(stderr, "Erro: tamanho de matriz inválido (%u). Deve estar entre 0 e 3.\n", matrix_size);
        return HW_SEND_FAIL;
    }
    return HW_SUCCESS;
}

int main(void) {
    // Inicializa comunicação com a FPGA
    printf(">> Iniciando módulo de hardware FPGA...\n");
    if (begin_hw() != HW_SUCCESS) {
        fprintf(stderr, "Erro: falha ao inicializar hardware.\n");
        return EXIT_FAILURE;
    }

    // Loop principal
    while (1) {
        // Matrizes e buffers
        int8_t matrix_a[MATRIX_SIZE] = {
            10, 15, 20, 25, 5,
            6, 7, 8, 9, 10,
            10, 12, 10, 20, 15,
            4, 5, 6, 7, 8,
            9, 1, 2, 3, 4
        };

        int8_t matrix_b[MATRIX_SIZE] = {
            1, 1, 1, 1, 1,
            1, 1, 1, 1, 1,
            1, 1, 1, 1, 1,
            1, 1, 1, 1, 1,
            1, 1, 1, 1, 1
        };

        int8_t matrix_result[MATRIX_SIZE] = {0};
        uint8_t overflow_flag = 0;

        uint32_t op_code = 0;
        uint32_t matrix_size = 0;
        uint32_t scalar = 2;

        // Menu de entrada
        printf("=== Menu de Operações Aritméticas entre Matrizes ===\n");
        printf("0 -> Adição\n");
        printf("1 -> Subtração\n");
        printf("2 -> Multiplicação matricial\n");
        printf("3 -> Multiplicação por escalar\n");
        printf("4 -> Não escolha! (É determinante)\n");
        printf("5 -> Matriz transposta\n");
        printf("6 -> Matriz oposta\n");

        printf("Informe o código da operação [0 a 6], ou [9] para sair: ");
        if (scanf("%u", &op_code) != 1 || op_code == 9) {
            printf("Saindo do programa...\n");
            break;
        }

        printf("0 -> Matriz 2x2\n");
        printf("1 -> Matriz 3x3\n");
        printf("2 -> Matriz 4x4\n");
        printf("3 -> Matriz 5x5\n");
        printf("Informe a ordem da matriz: ");
        if (scanf("%u", &matrix_size) != 1) {
            fprintf(stderr, "Entrada inválida.\n");
            continue;
        }

        if (validate_operation(op_code, matrix_size) != HW_SUCCESS) {
            printf("Por favor, tente novamente.\n\n");
            continue;
        }

        struct Params params = {
            .a = matrix_a,
            .b = matrix_b,
            .opcode = op_code,
            .size = matrix_size,
            .scalar = scalar
        };

        printf(">> Enviando matrizes e configuração (opcode=%u, tamanho=%u)...\n", op_code, matrix_size);
        if (send_data(&params) != HW_SUCCESS) {
            fprintf(stderr, "Erro: falha ao enviar dados à FPGA.\n");
            break;
        }

        // Zera buffers antes da leitura
        for (int i = 0; i < MATRIX_SIZE; ++i) {
            matrix_result[i] = 0;
        }
        overflow_flag = 0;

        printf(">> Aguardando conclusão da operação na FPGA...\n");
        if (read_results(matrix_result, &overflow_flag) != HW_SUCCESS) {
            fprintf(stderr, "Erro: falha ao ler resultados da FPGA.\n");
            break;
        }

        // Exibe os resultados
        print_matrix("Matriz A", matrix_a, matrix_size);
        print_matrix("Matriz B", matrix_b, matrix_size);
        print_matrix("Resultado da FPGA", matrix_result, matrix_size);
        printf("Overflow detectado: %s\n\n", (overflow_flag & 0x1) ? "SIM" : "NÃO");

        // Espera para repetir
        printf("Pressione ENTER para continuar...\n");
        getchar(); // consome \n anterior
        getchar(); // espera novo ENTER
    }

    // Finaliza comunicação com hardware
    end_hw();
    return EXIT_SUCCESS;
}
