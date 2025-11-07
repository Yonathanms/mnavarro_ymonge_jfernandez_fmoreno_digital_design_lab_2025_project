// ============================================================
// CPSR - registro de banderas NZCV
//  - Escribe N,Z,C,V cuando FlagWrite=1 (típicamente DataProc con S=1 o CMP)
//  - Lee siempre para evaluación de condiciones
// ============================================================
module cpsr_flags (
    input  logic clk,
    input  logic rst,
    input  logic FlagWrite,
    input  logic N_in, Z_in, C_in, V_in,
    output logic N, Z, C, V
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            N <= 1'b0; Z <= 1'b0; C <= 1'b0; V <= 1'b0;
        end else if (FlagWrite) begin
            N <= N_in; Z <= Z_in; C <= C_in; V <= V_in;
        end
    end
endmodule
