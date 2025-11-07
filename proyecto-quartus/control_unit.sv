// ============================================================
// CONTROL UNIT (single-cycle, minimal)
// Entradas: tipo, opcode, S, cond_ok
// Salidas: RegWrite, MemWrite, MemToReg, Branch, FlagWrite, ALUSrcB
// Convenciones en este subset:
//   - DataProc: RegWrite=1 excepto CMP (opcode=1010).
//               FlagWrite=S || (opcode==CMP)
//               ALUSrcB=0 (usa shifter de Rm)
//   - LDR/STR : opcode[0]==1 => LDR ; ==0 => STR
//               ALUSrcB=1 (usa imm12 como offset), ALU=ADD
//   - Branch  : Branch=1 (PC <- PC + imm24<<2) si cond_ok
// ============================================================
module control_unit (
    input  logic        cond_ok,
    input  logic [1:0]  type,
    input  logic [3:0]  opcode,
    input  logic        S,          // solo válido en DataProc
    output logic        RegWrite,
    output logic        MemWrite,
    output logic        MemToReg,
    output logic        Branch,
    output logic        FlagWrite,
    output logic        ALUSrcB     // 0: shifter(Rm), 1: imm12 (para LDR/STR)
);
    // Defaults
    always_comb begin
        RegWrite = 1'b0;
        MemWrite = 1'b0;
        MemToReg = 1'b0;
        Branch   = 1'b0;
        FlagWrite= 1'b0;
        ALUSrcB  = 1'b0;

        if (!cond_ok) begin
            // ninguna acción si la condición falla
        end else begin
            unique case (type)
                2'd0: begin // DataProc
                    // CMP (1010) no escribe registro
                    RegWrite = (opcode != 4'b1010);
                    FlagWrite= (S == 1'b1) || (opcode == 4'b1010);
                    ALUSrcB  = 1'b0; // operando2 = shifter(Rm)
                    MemWrite = 1'b0;
                    MemToReg = 1'b0;
                    Branch   = 1'b0;
                end
                2'd1: begin // Load/Store
                    // En ARM LDR/STR distinguen con bit L (=S aquí, mismo bit físico 20)
                    // Pero nuestro DEC ya da S=instr[20], que en L/S significa L.
                    if (S) begin
                        // LDR
                        RegWrite = 1'b1;
                        MemToReg = 1'b1;
                        MemWrite = 1'b0;
                    end else begin
                        // STR
                        RegWrite = 1'b0;
                        MemToReg = 1'b0;
                        MemWrite = 1'b1;
                    end
                    FlagWrite= 1'b0;
                    ALUSrcB  = 1'b1; // offset inmediato
                    Branch   = 1'b0;
                end
                2'd2: begin // Branch
                    Branch   = 1'b1;
                    // demás señales desactivadas
                end
                default: ; // otros no implementados
            endcase
        end
    end
endmodule
