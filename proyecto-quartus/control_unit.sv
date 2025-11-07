// ============================================================
// CONTROL UNIT (single-cycle, minimal)
//   instr_type: 0=DataProc, 1=Load/Store, 2=Branch, 3=Otro
// ============================================================
module control_unit (
    input  logic        cond_ok,
    input  logic [1:0]  instr_type,
    input  logic [3:0]  opcode,
    input  logic        S,          // solo válido en DataProc
    output logic        RegWrite,
    output logic        MemWrite,
    output logic        MemToReg,
    output logic        Branch,
    output logic        FlagWrite,
    output logic        ALUSrcB     // 0: shifter(Rm), 1: imm12 (para LDR/STR)
);

    always_comb begin
        // defaults
        RegWrite = 1'b0;
        MemWrite = 1'b0;
        MemToReg = 1'b0;
        Branch   = 1'b0;
        FlagWrite= 1'b0;
        ALUSrcB  = 1'b0;

        if (!cond_ok) begin
            // no-op
        end
        else begin
            unique case (instr_type)

                // ============================
                // DATA-PROCESSING
                // ============================
                2'd0: begin
                    // CMP opcode = 1010 → no escribe Rd
                    RegWrite  = (opcode != 4'b1010);
                    FlagWrite = (S == 1'b1) || (opcode == 4'b1010);
                    ALUSrcB   = 1'b0;     // usa shifter(Rm)
                end

                // ============================
                // LOAD / STORE
                // L:bit (instr[20]) se mapeó en S
                // ============================
                2'd1: begin
                    ALUSrcB = 1'b1;       // inm12
                    FlagWrite = 1'b0;
                    if (S) begin
                        // LDR
                        RegWrite = 1'b1;
                        MemToReg = 1'b1;
                    end else begin
                        // STR
                        MemWrite = 1'b1;
                    end
                end

                // ============================
                // BRANCH
                // ============================
                2'd2: begin
                    Branch = 1'b1;
                end

                default: ;   // otros no soportados
            endcase
        end
    end

endmodule
