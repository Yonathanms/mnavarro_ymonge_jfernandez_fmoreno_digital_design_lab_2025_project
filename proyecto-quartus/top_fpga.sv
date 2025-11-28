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

    // Divisor de frecuencia para ralentizar LED[4] a velocidad visible
    // Dividimos 50 MHz por 2^24 para obtener parpadeo visible (~3 Hz)
    logic [24:0] freq_counter;
    logic debug_pc_visible;

    always_ff @(posedge CLOCK_50 or posedge rst) begin
        if (rst)
            freq_counter <= 25'b0;
        else
            freq_counter <= freq_counter + 1'b1;
    end

    // Usar bit [24] del contador para obtener parpadeo visible a ~1.5 Hz
    assign debug_pc_visible = freq_counter[24] & debug_pc[4];

    // LED0: se ejecutó al menos una instrucción aritmética (ADD)
    // LED1: se ejecutó al menos una instrucción de memoria (STR/LDR)
    // LED2: se ejecutó al menos un branch (salto)
    // LED4: PC bit[4] ralentizado a velocidad visible

    assign LEDR[0] = dbg_alu;
    assign LEDR[1] = dbg_mem;
    assign LEDR[2] = dbg_br;
    assign LEDR[4] = debug_pc_visible;

    // LEDs no utilizados
    assign LEDR[3]  = 1'b0;
    assign LEDR[5]  = 1'b0;
    assign LEDR[6]  = 1'b0;
    assign LEDR[7]  = 1'b0;
    assign LEDR[8]  = 1'b0;
    assign LEDR[9]  = 1'b0;

endmodule
