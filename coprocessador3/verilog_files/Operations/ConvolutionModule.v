module ConvolutionModule (
    input [199:0] matrix_a,     // Pixels da região (valores unsigned 0-255)
    input [199:0] matrix_b,     // Kernel/filtro (valores signed, podem ser negativos)
    input [1:0] matrix_size,    // 00=2x2, 01=3x3, 10=4x4, 11=5x5
    output reg signed [15:0] result_out
);

    // Função para extrair pixel (unsigned)
    function [7:0] get_pixel;
        input [199:0] matrix;
        input [4:0] index;
        begin
            get_pixel = matrix[(index*8) +: 8];
        end
    endfunction

    // Função para extrair valor do kernel (signed)
    function signed [7:0] get_kernel;
        input [199:0] matrix;
        input [4:0] index;
        begin
            get_kernel = matrix[(index*8) +: 8];
        end
    endfunction

    // Função para mapear coordenadas (row, col) para índice linear
    function [4:0] get_index;
        input [2:0] row;
        input [2:0] col;
        begin
            get_index = row * 5 + col; // Sempre mapeia como 5x5
        end
    endfunction

    // Função para verificar se coordenada está dentro dos limites
    function is_valid_coord;
        input [2:0] row;
        input [2:0] col;
        input [1:0] size;
        begin
            case (size)
                2'b00: is_valid_coord = (row < 2) && (col < 2); // 2x2
                2'b01: is_valid_coord = (row < 3) && (col < 3); // 3x3
                2'b10: is_valid_coord = (row < 4) && (col < 4); // 4x4
                2'b11: is_valid_coord = (row < 5) && (col < 5); // 5x5
                default: is_valid_coord = 0;
            endcase
        end
    endfunction

    // Função de convolução otimizada
    function signed [15:0] optimized_convolution;
        input [199:0] pixels;
        input [199:0] kernel;
        input [1:0] size;
        reg signed [19:0] sum; // Aumentado para evitar overflow
        reg [7:0] pixel_val;
        reg signed [7:0] kernel_val;
        reg [2:0] row, col;
        reg [4:0] idx;
        begin
            sum = 20'sb0;
            
            // Loop otimizado através das posições válidas
            for (row = 0; row < 5; row = row + 1) begin
                for (col = 0; col < 5; col = col + 1) begin
                    if (is_valid_coord(row, col, size)) begin
                        idx = get_index(row, col);
                        pixel_val = get_pixel(pixels, idx);
                        kernel_val = get_kernel(kernel, idx);
                        
                        // Multiplica pixel unsigned por kernel signed
                        sum = sum + ($signed({1'b0, pixel_val}) * kernel_val);
                    end
                end
            end
            
            // Saturação na saída
            if (sum > 20'sd32767) 
                optimized_convolution = 16'sd32767;
            else if (sum < -20'sd32768)
                optimized_convolution = -16'sd32768;
            else
                optimized_convolution = sum[15:0];
        end
    endfunction

    always @(*) begin
        result_out = optimized_convolution(matrix_a, matrix_b, matrix_size);
    end

endmodule