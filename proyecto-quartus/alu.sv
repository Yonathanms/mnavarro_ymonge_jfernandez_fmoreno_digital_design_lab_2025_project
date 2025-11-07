module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,
    output logic [31:0] y,
    output logic        N, Z, C, V
);

    logic [32:0] tmp;

    always_comb begin
        y = 32'h0;
        C = 1'b0;
        V = 1'b0;

        case (alu_op)
            4'b0000: y = a & b;   // AND
            4'b0001: y = a ^ b;   // XOR
            4'b0010: begin        // SUB
                tmp = {1'b0,a} - {1'b0,b};
                y = tmp[31:0];
                C = ~tmp[32];
                V = (a[31]!=b[31]) && (y[31]!=a[31]);
            end
            4'b0100: begin        // ADD
                tmp = {1'b0,a} + {1'b0,b};
                y = tmp[31:0];
                C = tmp[32];
                V = (a[31]==b[31]) && (y[31]!=a[31]);
            end
            4'b1100: y = a | b;   // ORR
            4'b1101: y = b;       // MOV
            4'b1010: begin        // CMP
                tmp = {1'b0,a} - {1'b0,b};
                y = tmp[31:0];
                C = ~tmp[32];
                V = (a[31]!=b[31]) && (y[31]!=a[31]);
            end
            default: y = 32'h0;
        endcase
        N = y[31];
        Z = (y == 32'h0);
    end

endmodule
