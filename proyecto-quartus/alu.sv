// ============================================================
// ALU ARMv4 subset — PURAMENTE COMBINACIONAL
// ============================================================
module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,
    output logic [31:0] y,
    output logic        N, Z, C, V
);

    logic [32:0] tmp;

    always_comb begin
        // ===== default =====
        y = 32'h00000000;
        N = 1'b0;
        Z = 1'b0;
        C = 1'b0;
        V = 1'b0;
        tmp = 33'h000000000;

        // ===== operations =====
        unique case (alu_op)

            4'b0000: begin                // AND
                y = a & b;
            end

            4'b0001: begin                // EOR/XOR
                y = a ^ b;
            end

            4'b0010: begin                // SUB
                tmp = {1'b0,a} - {1'b0,b};
                y   = tmp[31:0];
                C   = ~tmp[32];                     // ARM = ~borrow
                V   = (a[31] != b[31]) && (y[31] != a[31]);
            end

            4'b0100: begin                // ADD
                tmp = {1'b0,a} + {1'b0,b};
                y   = tmp[31:0];
                C   = tmp[32];                      // carry out
                V   = (a[31] == b[31]) && (y[31] != a[31]);
            end

            4'b1100: begin                // ORR
                y = a | b;
            end

            4'b1101: begin                // MOV
                y = b;
            end

            4'b1010: begin                // CMP (ALU returns y but RegWrite=0)
                tmp = {1'b0,a} - {1'b0,b};
                y   = tmp[31:0];
                C   = ~tmp[32];
                V   = (a[31] != b[31]) && (y[31] != a[31]);
            end

            default: begin
                y = 32'h00000000;
            end

        endcase

        // ===== flags =====
        N = y[31];
        Z = (y == 32'h00000000);
    end

endmodule
