module cpu_top (
    input  logic        clk,
    input  logic        rst,
    // Interfaz VRAM puerto B para el subsistema VGA
    input  logic        vram_clk_b,
    input  logic [9:0]  vram_addr_b,
    output logic [31:0] vram_q_b,
    // Interfaz PS/2
    input  logic        ps2_clk,
    input  logic        ps2_data,

    output logic [31:0] debug_pc,
    output logic        dbg_alu,
    output logic        dbg_mem,
    output logic        dbg_br
);


    // ========================================
    // Módulos PS/2
    // ========================================
    logic ps2_clk_sync, ps2_data_sync;
    logic [7:0] ps2_scancode;
    logic ps2_scancode_ready;
    logic ps2_error;

    ps2_sync U_PS2_SYNC (
        .clk           (clk),
        .rst           (rst),
        .ps2_clk       (ps2_clk),
        .ps2_data      (ps2_data),
        .ps2_clk_sync  (ps2_clk_sync),
        .ps2_data_sync (ps2_data_sync)
    );

    ps2_receiver U_PS2_RECEIVER (
        .clk            (clk),
        .rst            (rst),
        .ps2_clk_sync   (ps2_clk_sync),
        .ps2_data_sync  (ps2_data_sync),
        .scancode       (ps2_scancode),
        .scancode_ready (ps2_scancode_ready),
        .error          (ps2_error)
    );

    // fetch
    logic [31:0] pc, pc_next, instr;
    logic [31:0] pc_plus4, pc_plus8;

    pc_reg U_PC (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    // Sistema de memoria centralizado: lee instrucciones desde ROM (región 0x0)
    logic [31:0] mem_read_data;
    mem_system #(
        .INCLUDE_VRAM(1'b0),
        .INCLUDE_PS2 (1'b0)
    ) U_MEM (
        .clk               (clk),
        .addr              (pc),                    // PC se usa como dirección de lectura
        .write_data        (32'h0000_0000),         // No escribe en fetch
        .MemWrite          (1'b0),                  // No escribe en fetch
        .read_data         (mem_read_data),
        .vram_clk_b        (1'b0),
        .vram_addr_b       (10'd0),
        .vram_q_b          (),
        .ps2_scancode      (8'h00),
        .ps2_scancode_ready(1'b0),
        .ps2_error         (1'b0)
    );

    assign instr    = mem_read_data;
    assign pc_plus4 = pc + 32'd4;
    assign pc_plus8 = pc + 32'd8;

    // decode
    logic [3:0] cond;
    logic [1:0] instr_type;
    logic [3:0] opcode;
    logic       S;
    logic [3:0] Rn, Rd, Rm;
    logic [11:0] operand2;
    logic        op2_is_imm;

    decoder U_DEC (
        .instr      (instr),
        .cond       (cond),
        .instr_type (instr_type),
        .opcode     (opcode),
        .S          (S),
        .Rn         (Rn),
        .Rd         (Rd),
        .Rm         (Rm),
        .operand2   (operand2),
        .op2_is_imm (op2_is_imm)
    );

    // register file
    logic [31:0] rf_rd1_raw, rf_rd2_raw;
    logic [31:0] rf_rd1, rf_rd2, rf_wd, rf_wd_final;
    logic        RegWrite, rf_we;
    logic [3:0]  rf_wa;

    logic [3:0] rf_ra2;
    assign rf_ra2 = (instr_type == 2'd1) ? Rd : Rm; // En LDR/STR necesitamos acceder a Rd para STR

    regfile U_RF (
        .clk (clk),
        .rst (rst),
        .we  (rf_we),
        .ra1 (Rn),
        .ra2 (rf_ra2),
        .wa  (rf_wa),
        .wd  (rf_wd_final),
        .rd1 (rf_rd1_raw),
        .rd2 (rf_rd2_raw)
    );

    assign rf_rd1 = (Rn == 4'd15) ? pc_plus8 : rf_rd1_raw;
    assign rf_rd2 = (Rm == 4'd15) ? pc_plus8 : rf_rd2_raw;

    // cpsr / cond

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


    // shifter
    logic [31:0] op2_shifted;
    logic [4:0]  shamt;
    logic [1:0]  shkind;

    assign shamt  = operand2[11:7];
    assign shkind = operand2[6:5];
    barrel_shifter U_SH (
        .in    (rf_rd2),
        .shamt (shamt),
        .kind  (shkind),
        .out   (op2_shifted)
    );


    // alu
    logic [31:0] alu_a, alu_b, alu_y;
    logic        ALUSrcB;
    logic [31:0] imm12_zext;
    logic [3:0]  alu_ctrl;
    logic [31:0] op2_immediate;
    logic [31:0] op2_mux;

    function automatic [31:0] expand_arm_imm(input logic [7:0] imm8, input logic [3:0] rot);
        logic [31:0] value;
        logic [4:0]  shift;
        begin
            value = {24'b0, imm8};
            shift = {rot, 1'b0};
            if (shift == 5'd0)
                expand_arm_imm = value;
            else
                expand_arm_imm = (value >> shift) | (value << (32 - shift));
        end
    endfunction

    assign imm12_zext = {20'b0, operand2[11:0]};
    assign alu_a      = rf_rd1;
    assign op2_immediate = expand_arm_imm(operand2[7:0], operand2[11:8]);
    assign op2_mux      = (instr_type == 2'd0 && op2_is_imm) ? op2_immediate
                                                             : op2_shifted;
    assign alu_b        = (ALUSrcB) ? imm12_zext : op2_mux;

    // Para LDR/STR (instr_type=1) siempre ADD
    // Para DataProc opcode directo.
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


    // dmem: ahora el CPU escribe/lee a través de mem_system
    logic [31:0] dmem_out;
    logic        MemWrite, MemToReg;

    // El CPU escribe/lee datos en dirección calculada por ALU a través de mem_system
    mem_system #(
        .INCLUDE_VRAM(1'b1),
        .INCLUDE_PS2 (1'b1)
    ) U_MEM_DATA (
        .clk               (clk),
        .addr              (alu_y),                 // Dirección de datos calculada por ALU
        .write_data        (rf_rd2),                // Datos a escribir (desde rf_rd2)
        .MemWrite          (MemWrite),              // Señal de escritura
        .read_data         (dmem_out),              // Datos leídos
        .vram_clk_b        (vram_clk_b),
        .vram_addr_b       (vram_addr_b),
        .vram_q_b          (vram_q_b),
        .ps2_scancode      (ps2_scancode),
        .ps2_scancode_ready(ps2_scancode_ready),
        .ps2_error         (ps2_error)
    );


    // control unit
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


    // write back

    assign rf_wd = (MemToReg) ? dmem_out : alu_y;

    // Escrituras especiales (BL y escritura en PC)
    logic do_link;
    assign do_link = (instr_type == 2'd2) && instr[24] && cond_ok;

    assign rf_we       = (do_link) ? 1'b1 : RegWrite;
    assign rf_wa       = (do_link) ? 4'd14 : Rd;
    assign rf_wd_final = (do_link) ? pc_plus4 : rf_wd;


    // next pc logic
    logic [31:0] branch_offs;
    logic        write_back_updates_pc;

    // Sign-extend correcto de imm24 << 2
    assign branch_offs = {{6{instr[23]}}, instr[23:0], 2'b00};
    assign write_back_updates_pc = (rf_we && (rf_wa == 4'd15));

    assign pc_next = (write_back_updates_pc) ? rf_wd_final
                                             : (Branch ? (pc_plus4 + branch_offs)
                                                       : pc_plus4);


    // debug flags
    // Estas banderas se ponen en 1 cuando al menos una vez se ejecuta cada tipo de instrucción. Solo para demo en FPGA.

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dbg_alu <= 1'b0;
            dbg_mem <= 1'b0;
            dbg_br  <= 1'b0;
        end else begin
            // Data Processing (ALU)
            if (instr_type == 2'd0 && cond_ok)
                dbg_alu <= 1'b1;

            // Load / Store
            if (instr_type == 2'd1 && cond_ok)
                dbg_mem <= 1'b1;

            // Branch
            if (instr_type == 2'd2 && cond_ok)
                dbg_br <= 1'b1;
        end
    end

    // debug del PC
    assign debug_pc = pc;

endmodule
