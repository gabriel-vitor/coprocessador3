module sqrt (
    input  wire [31:0] in,
    output reg  [15:0] out  // Raiz de 32 bits cabe em 16 bits
);
    integer i;
    reg [15:0] x;
    reg [31:0] temp;

    always @(*) begin
        x = 16'h0;
        
        // Algoritmo de raiz quadrada por aproximação binária
        for (i = 15; i >= 0; i = i - 1) begin
            temp = (x | (1 << i));
            if ((temp * temp) <= in) begin
                x = temp;
            end
        end
        out = x;
    end
endmodule