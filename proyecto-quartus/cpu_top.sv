// =====================================================================
// cpu_top.sv
// ARMv4 subset — Single-cycle CPU mínimo
// =====================================================================

module cpu_top (
    input  logic        clk,
    input  logic        rst,
    output logic [31:0] debug_pc      // para debug en FPGA
);

    // ================================================================
    // ========================   FETCH   ==============================
    // ================================================================

    logic [31:0] pc, pc_next, instr;

    pc_reg U_PC (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    instr_mem U_ROM (
        .addr (pc),
        .dout (instr)
    );

    // ================================================================
    // ========================   DECODE   =============================
    // ================================================================

    logic [3:0] cond;
    logic [1:0] instr_type;
    logic [3:0] opcode;
    logic       S;
    logic [3:0] Rn, Rd, Rm;
    logic [11:0] operand2;

    decoder U_DEC (
        .instr      (instr),
        .cond       (cond),
        .instr_type (instr_type),
        .opcode     (opcode),
        .S          (S),
        .Rn         (Rn),
        .Rd         (Rd),
        .Rm         (Rm),
        .operand2   (operand2)
    );

    // ================================================================
    // =====================   REGISTER FILE   ========================
    // ================================================================

    logic [31:0] rf_rd1, rf_rd2, rf_wd;
    logic        RegWrite;

    regfile U_RF (
        .clk (clk),
        .we  (RegWrite),
        .ra1 (Rn),
        .ra2 (Rm),
        .wa  (Rd),
        .wd  (rf_wd),
        .rd1 (rf_rd1),
        .rd2 (rf_rd2)
    );

    // ================================================================
    // ======================   CPSR / COND   =========================
    // ================================================================

    logic N, Z, C, V;
    logic N_next, Z_next, C_next, V_next;
    logic FlagWrite, cond_ok;

    cond_check U_COND (
        .cond    (cond),
        .N       (N),
        .Z       (Z),
        .C       (C),
        .V       (V),
        .cond_ok (cond_ok)
    );

    cpsr_flags U_CPSR (
        .clk       (clk),
        .rst       (rst),
        .FlagWrite (FlagWrite),
        .N_in      (N_next),
        .Z_in      (Z_next),
        .C_in      (C_next),
        .V_in      (V_next),
        .N         (N),
        .Z         (Z),
        .C         (C),
        .V         (V)
    );

    // ================================================================
    // =======================   SHIFTER   ============================
    // ================================================================

    logic [31:0] op2_shifted;
    logic [4:0]  shamt;
    logic [1:0]  shkind;

    assign shamt  = operand2[11:7];
    assign shkind = operand2[6:5];     // 00=LSL, 01=LSR

    barrel_shifter U_SH (
        .in    (rf_rd2),
        .shamt (shamt),
        .kind  (shkind),
        .out   (op2_shifted)
    );

    // ================================================================
    // ==========================   ALU   =============================
    // ================================================================

    logic [31:0] alu_a, alu_b, alu_y;
    logic        ALUSrcB;
    logic [31:0] imm12_zext;
    logic [3:0]  alu_ctrl;

    assign imm12_zext = {20'b0, operand2[11:0]};
    assign alu_a      = rf_rd1;
    assign alu_b      = (ALUSrcB) ? imm12_zext : op2_shifted;

    // Para LDR/STR (instr_type=1) usamos siempre ADD
    // Para DataProc usamos opcode directo.
    assign alu_ctrl = (instr_type == 2'd1) ? 4'b0100 : opcode;

    alu U_ALU (
        .a      (alu_a),
        .b      (alu_b),
        .alu_op (alu_ctrl),
        .y      (alu_y),
        .N      (N_next),
        .Z      (Z_next),
        .C      (C_next),
        .V      (V_next)
    );

    // ================================================================
    // ==========================   DMEM   ============================
    // ================================================================

    logic [31:0] dmem_out;
    logic        MemWrite, MemToReg;

    data_mem U_DMEM (
        .clk  (clk),
        .we   (MemWrite),
        .addr (alu_y),
        .din  (rf_rd2),     // STORE usa rf_rd2
        .dout (dmem_out)
    );

    // ================================================================
    // =====================   CONTROL UNIT   =========================
    // ================================================================

    logic Branch;
    logic ALUSrcB_int;

    control_unit U_CTRL (
        .cond_ok    (cond_ok),
        .instr_type (instr_type),
        .opcode     (opcode),
        .S          (S),
        .RegWrite   (RegWrite),
        .MemWrite   (MemWrite),
        .MemToReg   (MemToReg),
        .Branch     (Branch),
        .FlagWrite  (FlagWrite),
        .ALUSrcB    (ALUSrcB_int)
    );

    // selector ALUSrcB desde control
    assign ALUSrcB = ALUSrcB_int;

    // ================================================================
    // =======================   WRITE-BACK   =========================
    // ================================================================

    assign rf_wd = (MemToReg) ? dmem_out : alu_y;

    // ================================================================
    // ======================   NEXT PC LOGIC   =======================
    // ================================================================

    logic [31:0] pc_plus4, branch_offs;

    assign pc_plus4    = pc + 32'd4;

    // Sign-extend correcto de imm24 << 2
    assign branch_offs = {{6{instr[23]}}, instr[23:0], 2'b00};

    assign pc_next = (Branch) ? (pc_plus4 + branch_offs)
                              : pc_plus4;

    // ================================================================
    // =========================   DEBUG   =============================
    // ================================================================

    assign debug_pc = pc;

endmodule
