module top_fpga (
    input  logic        CLOCK_50,
    input  logic [0:0]  KEY,
    input  logic        PS2_CLK,
    input  logic        PS2_DAT,
    output logic [9:0]  LEDR,
    output logic        VGA_CLK,
    output logic        VGA_BLANK_N,
    output logic        VGA_SYNC_N,
    output logic        VGA_HS,
    output logic        VGA_VS,
    output logic [7:0]  VGA_R,
    output logic [7:0]  VGA_G,
    output logic [7:0]  VGA_B
);

    logic rst;
    logic [31:0] debug_pc;
    logic dbg_alu, dbg_mem, dbg_br;

    assign rst = ~KEY[0];

    // Reloj 25 MHz para el dominio VGA (señal ya validada en top_vga_test)
    logic clk_25;
    always_ff @(posedge CLOCK_50 or posedge rst) begin
        if (rst)
            clk_25 <= 1'b0;
        else
            clk_25 <= ~clk_25;
    end
    assign VGA_CLK = clk_25;

    logic [9:0] vram_addr_b;
    logic [31:0] vram_q_b;

    cpu_top U_CPU (
        .clk         (CLOCK_50),
        .rst         (rst),
        .vram_clk_b  (clk_25),
        .vram_addr_b (vram_addr_b),
        .vram_q_b    (vram_q_b),
        .ps2_clk     (PS2_CLK),
        .ps2_data    (PS2_DAT),
        .debug_pc    (debug_pc),
        .dbg_alu     (dbg_alu),
        .dbg_mem     (dbg_mem),
        .dbg_br      (dbg_br)
    );

    // Controlador VGA: temporización + renderer de texto
    logic [9:0] pixel_x;
    logic [9:0] pixel_y;
    logic       video_on;

    vga_timing U_VGA_TIMING (
        .clk_pix  (clk_25),
        .rst      (rst),
        .hsync    (VGA_HS),
        .vsync    (VGA_VS),
        .video_on (video_on),
        .pixel_x  (pixel_x),
        .pixel_y  (pixel_y)
    );

    vga_renderer U_VGA_RENDERER (
        .clk_pix    (clk_25),
        .rst        (rst),
        .video_on   (video_on),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .vram_addr_b(vram_addr_b),
        .vram_q_b   (vram_q_b),
        .vga_r      (VGA_R),
        .vga_g      (VGA_G),
        .vga_b      (VGA_B)
    );

    assign VGA_BLANK_N = video_on;
    assign VGA_SYNC_N  = 1'b0;

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
