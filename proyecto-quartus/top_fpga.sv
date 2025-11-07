module top_fpga (
    input  logic CLOCK_50,
    input  logic [0:0] KEY,
    output logic [9:0] LEDR
);

    logic rst;
    logic [31:0] debug_pc;
    logic dbg_alu, dbg_mem, dbg_br;

    assign rst = ~KEY[0];  

    cpu_top U_CPU (
        .clk      (CLOCK_50),
        .rst      (rst),
        .debug_pc (debug_pc),
        .dbg_alu  (dbg_alu),
        .dbg_mem  (dbg_mem),
        .dbg_br   (dbg_br)
    );

    // LED0: se ejecutó al menos una instrucción aritmética (ADD)
    // LED1: se ejecutó al menos una instrucción de memoria (STR/LDR)
    // LED2: se ejecutó al menos un branch (salto)
    // LED4: PC en loop

    assign LEDR[0] = dbg_alu;
    assign LEDR[1] = dbg_mem;
    assign LEDR[2] = dbg_br;
    assign LEDR[4] = debug_pc[4];

 
    assign LEDR[3]  = 1'b0;
    assign LEDR[5]  = 1'b0;
    assign LEDR[6]  = 1'b0;
    assign LEDR[7]  = 1'b0;
    assign LEDR[8]  = 1'b0;
    assign LEDR[9]  = 1'b0;

endmodule
