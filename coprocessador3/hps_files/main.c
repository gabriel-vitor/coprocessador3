#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define WIDTH 3201
#define HEIGHT 240

unsigned char image[HEIGHT][WIDTH][3];
unsigned char gray[HEIGHT][WIDTH];
unsigned char output[HEIGHT][WIDTH];

// Lê imagem .ppm P6 (RGB binário)
int load_ppm_image(const char *filename) {
    FILE *fin = fopen(filename, "rb");
    if (!fin) {
        perror("Erro ao abrir imagem PPM");
        return 0;
    }

    char header[3];
    int width, height, maxval;

    fscanf(fin, "%2s", header);
    if (strcmp(header, "P6") != 0) {
        fprintf(stderr, "Formato PPM inválido (esperado P6)\n");
        fclose(fin);
        return 0;
    }

    // Pular comentários
    int c;
    do {
        c = fgetc(fin);
        if (c == '#') while (fgetc(fin) != '\n');
        else {
            ungetc(c, fin);
            break;
        }
    } while (1);

    fscanf(fin, "%d %d %d", &width, &height, &maxval);
    fgetc(fin); // pula '\n'
    if (width != WIDTH || height != HEIGHT || maxval != 255) {
        fprintf(stderr, "Dimensões ou intensidade inválidas\n");
        fclose(fin);
        return 0;
    }

    size_t read = fread(image, 1, WIDTH * HEIGHT * 3, fin);
    fclose(fin);
    return read == WIDTH * HEIGHT * 3;
}

// Converte para tons de cinza (8 bits)
void convert_to_grayscale() {
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            unsigned char r = image[y][x][0];
            unsigned char g = image[y][x][1];
            unsigned char b = image[y][x][2];
            gray[y][x] = (unsigned char)(0.299 * r + 0.587 * g + 0.114 * b);
        }
    }
}

// Aplica filtro genérico de dimensão ksize
void apply_filter(const int *kernel, int ksize) {
    int k = ksize / 2;
    memset(output, 0, sizeof(output));
    for (int y = k; y < HEIGHT - k; y++) {
        for (int x = k; x < WIDTH - k; x++) {
            int sum = 0;
            for (int i = -k; i <= k; i++) {
                for (int j = -k; j <= k; j++) {
                    sum += gray[y + i][x + j] * kernel[(i + k) * ksize + (j + k)];
                }
            }
            output[y][x] = (unsigned char)fmin(fmax(sum, 0), 255);
        }
    }
}

// Aplica filtro do tipo gradiente (Sobel, Prewitt, Roberts)
void gradient_filter(const int *kx, const int *ky, int ksize) {
    int k = ksize / 2;
    memset(output, 0, sizeof(output));
    for (int y = k; y < HEIGHT - k; y++) {
        for (int x = k; x < WIDTH - k; x++) {
            int gx = 0, gy = 0;
            for (int i = -k; i <= k; i++) {
                for (int j = -k; j <= k; j++) {
                    gx += gray[y + i][x + j] * kx[(i + k) * ksize + (j + k)];
                    gy += gray[y + i][x + j] * ky[(i + k) * ksize + (j + k)];
                }
            }
            int mag = (int)sqrt((double)(gx * gx + gy * gy));
            output[y][x] = (unsigned char)(mag > 255 ? 255 : mag);
        }
    }
}

// Kernels
int sobel3x3_x[9] = {-1, 0, 1, -2, 0, 2, -1, 0, 1};
int sobel3x3_y[9] = {-1, -2, -1, 0, 0, 0, 1, 2, 1};
int prewitt3x3_x[9] = {-1, 0, 1, -1, 0, 1, -1, 0, 1};
int prewitt3x3_y[9] = {-1, -1, -1, 0, 0, 0, 1, 1, 1};
int roberts_x[4]  = {1, 0, 0, -1};
int roberts_y[4]  = {0, 1, -1, 0};
int laplacian5x5[25] = {0, 0, -1, 0, 0,
                       0, -1, -2, -1, 0,
                       -1, -2, 16, -2, -1,
                       0, -1, -2, -1, 0,
                       0, 0, -1, 0, 0};
int sobel5x5_x[25] = {-2, -1, 0, 1, 2,
                      -2, -1, 0, 1, 2,
                      -4, -2, 0, 2, 4,
                      -2, -1, 0, 1, 2,
                      -2, -1, 0, 1, 2};
int sobel5x5_y[25] = {-2, -2, -4, -2, -2,
                      -1, -1, -2, -1, -1,
                      0, 0, 0, 0, 0,
                      1, 1, 2, 1, 1,
                      2, 2, 4, 2, 2};

// Salva imagem PGM
void save_output(const char *filename) {
    FILE *f = fopen(filename, "wb");
    fprintf(f, "P5\n%d %d\n255\n", WIDTH, HEIGHT);
    fwrite(output, 1, WIDTH * HEIGHT, f);
    fclose(f);
    printf("Imagem salva como: %s\n", filename);
}

// Menu interativo
void menu() {
    int opcao;
    do {
        printf("\n=== Filtros de Borda ===\n");
        printf("1. Sobel 3x3\n");
        printf("2. Sobel 5x5\n");
        printf("3. Prewitt 3x3\n");
        printf("4. Roberts 2x2\n");
        printf("5. Laplaciano 5x5\n");
        printf("0. Sair\n");
        printf("Escolha a opção: ");
        scanf("%d", &opcao);

        switch (opcao) {
            case 1: gradient_filter(sobel3x3_x, sobel3x3_y, 3); save_output("saida_sobel3x3.pgm"); break;
            case 2: gradient_filter(sobel5x5_x, sobel5x5_y, 5); save_output("saida_sobel5x5.pgm"); break;
            case 3: gradient_filter(prewitt3x3_x, prewitt3x3_y, 3); save_output("saida_prewitt.pgm"); break;
            case 4: gradient_filter(roberts_x, roberts_y, 2); save_output("saida_roberts.pgm"); break;
            case 5: apply_filter(laplacian5x5, 5); save_output("saida_laplaciano.pgm"); break;
            case 0: printf("Saindo...\n"); break;
            default: printf("Opção inválida.\n");
        }
    } while (opcao != 0);
}

int main() {
    if (!load_ppm_image("imagem.ppm")) return 1;
    convert_to_grayscale();
    printf("Imagem convertida para tons de cinza.\n");
    menu();
    return 0;
}
