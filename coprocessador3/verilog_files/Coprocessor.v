module Coprocessor (
    input [2:0] op_code,                    // Código da operação a ser executada
    input [1:0] matrix_size,                // Tamanho da matriz (2x2, 3x3, 4x4, 5x5)
    input [199:0] matrix_a,                 // Matriz A de entrada
    input [199:0] matrix_b,                 // Matriz B de entrada (Kernel Gx)
    input [199:0] matrix_c,                 // Matriz C de entrada (Kernel Gy)
    output reg process_Done,                
    output reg [199:0] result_final                                  
);

    // Resultados das convoluções - mantém como signed
    wire signed [15:0] conv_gx, conv_gy;
    wire signed [15:0] conv_laplacian;
    
    // Instâncias das convoluções para gradiente (Gx e Gy)
    ConvolutionModule conv_gx_unit (
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .matrix_size(matrix_size),
        .result_out(conv_gx)
    );
    
    ConvolutionModule conv_gy_unit (
        .matrix_a(matrix_a),
        .matrix_b(matrix_c),
        .matrix_size(matrix_size),
        .result_out(conv_gy)
    );
    
    // Instância da convolução para Laplaciano
    ConvolutionModule conv_laplacian_unit (
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .matrix_size(matrix_size),
        .result_out(conv_laplacian)
    );
    
    // Variáveis para cálculo do gradiente
    wire signed [31:0] gx_squared, gy_squared, sum_squares;
    wire signed [15:0] sqrt_result;
    wire [7:0] saturated_result_gradient, saturated_result_laplacian;
    
    // Cálculo do gradiente: |Gx|² + |Gy|²
    assign gx_squared = conv_gx * conv_gx;
    assign gy_squared = conv_gy * conv_gy; 
    assign sum_squares = gx_squared + gy_squared;
    
    // Instância do módulo ALTSQRT de 32 bits para gradiente
    sqrt sqrt_unit (
        .in(sum_squares),
        .out(sqrt_result)           
    );
    
    // Saturação para gradiente (resultado da raiz quadrada)
    assign saturated_result_gradient = (sqrt_result > 16'd255) ? 8'd255 : 
                                      (sqrt_result < 16'd0) ? 8'd0 : 
                                      sqrt_result[7:0];
    
    // Saturação para Laplaciano (resultado direto da convolução)
    assign saturated_result_laplacian = (conv_laplacian > 16'd255) ? 8'd255 : 
                                       (conv_laplacian < -16'd255) ? 8'd0 :
                                       (conv_laplacian < 16'd0) ? 8'd0 :
                                       conv_laplacian[7:0];
    
    // Lógica de controle principal
    always @(*) begin
        case (op_code)
            3'b110: begin // op_code == 6: Filtro Laplaciano
                result_final = {192'b0, saturated_result_laplacian};   
                process_Done = 1'b1;                     
            end
            3'b111: begin // op_code == 7: Filtros de gradiente (Sobel, Prewitt, Roberts)
                result_final = {192'b0, saturated_result_gradient};   
                process_Done = 1'b1;                     
            end
            default: begin 
                result_final = 200'b0;
                process_Done = 1'b0;
            end
        endcase
    end

endmodule