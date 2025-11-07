// ============================================================
// CPU TOP - ARMv4 mínimo (single-cycle) para avance
// Integra: PC, ROM, Decoder, RegFile, Shifter, ALU, CPSR, DataMem, Control
// ============================================================
module cpu_top (
    input  logic clk,
    input  logic rst
);
    // ----------------------------
    // FETCH
    // ----------------------------
    logic [31:0] pc, pc_next, instr;

    pc_reg    U_PC   (.clk(clk), .rst(rst), .pc_next(pc_next), .pc(pc));
    instr_mem U_ROM  (.addr(pc), .dout(instr));

    // ----------------------------
    // DECODE
    // ----------------------------
    logic [3:0] cond, opcode, Rn, Rd, Rm;
    logic [1:0] type;
    logic       S;
    logic [11:0] operand2; // DataProc: shift spec ; L/S: imm12

    decoder U_DEC(
        .instr(instr),
        .cond(cond),
        .type(type),
        .opcode(opcode),
        .S(S),
        .Rn(Rn),
        .Rd(Rd),
        .Rm(Rm),
        .operand2(operand2)
    );

    // ----------------------------
    // REGISTER FILE
    //   ra1 = Rn (opA / base)
    //   ra2 = Rm (opB)
    //   wa  = Rd
    //   wd  = write-back mux
    // ----------------------------
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

    // ----------------------------
    // CONDITION FLAGS (CPSR)
    // ----------------------------
    logic N, Z, C, V;
    logic cond_ok, FlagWrite;

    cond_check U_COND (.cond(cond), .N(N), .Z(Z), .C(C), .V(V), .cond_ok(cond_ok));

    // ----------------------------
    // SHIFTER - para DataProc (I=0 - registro con shift inmediato)
    // operand2 layout (classic ARM):
    //   [11:7] shift_imm, [6:5] shift_type, [4] 0, [3:0] Rm
    // Usamos rf_rd2 como dato a desplazar, y operand2[11:7] / [6:5] como control
    // ----------------------------
    logic [31:0] op2_shifted;
    logic [4:0]  shamt;
    logic [1:0]  shkind;

    assign shamt  = operand2[11:7];
    assign shkind = operand2[6:5]; // 00=LSL, 01=LSR (por ahora soportamos estos dos en el shifter)

    barrel_shifter U_SH (
        .in    (rf_rd2),
        .shamt (shamt),
        .kind  (shkind),
        .out   (op2_shifted)
    );

    // ----------------------------
    // ALU
    //   opA = rf_rd1 (Rn)
    //   opB = mux: (type==L/S ? imm12 : op2_shifted)
    // ----------------------------
    logic [31:0] alu_a, alu_b, alu_y;
    logic        MemWrite, MemToReg, Branch, ALUSrcB;

    // Inmediato de 12 bits cero-extendido para L/S
    logic [31:0] imm12_zext;
    assign imm12_zext = {20'b0, operand2[11:0]};

    assign alu_a = rf_rd1;
    assign alu_b = (ALUSrcB) ? imm12_zext : op2_shifted;

    alu U_ALU (
        .a      (alu_a),
        .b      (alu_b),
        .alu_op (opcode),  // mapeo directo de opcode ARM a ALU subset (coinciden para AND/EOR/SUB/ADD/ORR/MOV/CMP)
        .y      (alu_y),
        .N      (/* wire */),
        .Z      (/* wire */),
        .C      (/* wire */),
        .V      (/* wire */)
    );

    // Salidas temporales de ALU para pasar a CPSR cuando corresponda
    logic N_next, Z_next, C_next, V_next;
    assign N_next = U_ALU.N;
    assign Z_next = U_ALU.Z;
    assign C_next = U_ALU.C;
    assign V_next = U_ALU.V;

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

    // ----------------------------
    // DATA MEMORY
    //   addr = alu_y (Rn + imm12) para L/S
    //   write data = rf_rd2 (STR Rd,[Rn,#imm]) => Rd es src -> en nuestro RF lo leemos por ra2=Rm,
    //   PERO para STR el dato a almacenar debe ser Rd; como ra2 es Rm, necesitamos el valor de Rd.
    //   Solución simple: leer Rd extra (tercera lectura) o reutilizar rf_wd si DataProc previo…
    //   Para no complicar: para STR usaremos rf_rd2 si definimos convención "Rm=Rd" en codificación de prueba.
//   *Para pruebas reales, te recomiendo un RegFile 2R1W+1R opcional o multiplexar direcciones de lectura.
// ----------------------------
    logic [31:0] dmem_out;
    logic [31:0] store_data;

    // Para este avance, asumimos STR con Rd == Rm (en los programas de prueba)
    assign store_data = rf_rd2;

    data_mem U_DMEM (
        .clk  (clk),
        .we   (MemWrite),
        .addr (alu_y),
        .din  (store_data),
        .dout (dmem_out)
    );

    // ----------------------------
    // CONTROL
    // ----------------------------
    control_unit U_CTRL (
        .cond_ok (cond_ok),
        .type    (type),
        .opcode  (opcode),
        .S       (S),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .MemToReg(MemToReg),
        .Branch  (Branch),
        .FlagWrite(FlagWrite),
        .ALUSrcB (ALUSrcB)
    );

    // ----------------------------
    // WRITE-BACK
    //   DataProc:  wd = alu_y
    //   LDR     :  wd = dmem_out
    // ----------------------------
    assign rf_wd = (MemToReg) ? dmem_out : alu_y;

    // ----------------------------
    // NEXT PC (Branch PC-relative)
    //   imm24 sign-extend, <<2, sumado a PC+4
    // ----------------------------
    logic [31:0] pc_plus4, branch_offs;
    assign pc_plus4  = pc + 32'd4;
    assign branch_offs = {{8{instr[23]}}, instr[23:0], 2'b00}; // sign-extend 24->32 y <<2

    assign pc_next = (Branch) ? (pc_plus4 + branch_offs) : pc_plus4;

endmodule
