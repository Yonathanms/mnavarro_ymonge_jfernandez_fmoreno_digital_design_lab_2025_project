// ============================================================
// DECODER - ARMv4 (subset) - expone Rm y operand2 (shift spec)
//   type: 0=DataProc, 1=Load/Store, 2=Branch, 3=Otro
//   NOTA: Soportamos DataProc con operando2 REG-shift (I=0).
// ============================================================
module decoder (
    input  logic [31:0] instr,
    output logic [3:0]  cond,
    output logic [1:0]  type,
    output logic [3:0]  opcode,   // DataProc opcode
    output logic        S,        // DataProc: set flags
    output logic [3:0]  Rn,       // reg base / opA
    output logic [3:0]  Rd,       // destino (DataProc/LDR)
    output logic [3:0]  Rm,       // opB registro (DataProc) o base para shift
    output logic [11:0] operand2  // shift spec (DataProc) o imm12 (LS)
);
    assign cond     = instr[31:28];
    assign opcode   = instr[24:21];
    assign S        = instr[20];
    assign Rn       = instr[19:16];
    assign Rd       = instr[15:12];
    assign Rm       = instr[3:0];
    assign operand2 = instr[11:0];

    // Clasificación simple por los bits [27:25]
    always_comb begin
        if      (instr[27:26] == 2'b00)        type = 2'd0; // DataProc
        else if (instr[27:26] == 2'b01)        type = 2'd1; // LDR/STR
        else if (instr[27:25] == 3'b101)       type = 2'd2; // Branch/BL
        else                                   type = 2'd3; // otro
    end
endmodule
