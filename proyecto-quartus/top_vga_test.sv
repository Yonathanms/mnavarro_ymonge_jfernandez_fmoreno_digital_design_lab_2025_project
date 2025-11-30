// Top de prueba independiente para mapeo de pines VGA.
// Genera 640x480@60Hz con un divisor simple y muestra barras verticales de color.
module top_vga_test (
    input  logic        CLOCK_50,
    input  logic [0:0]  KEY,
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
    assign rst = ~KEY[0]; // El pulsador KEY0 es activo bajo en la DE10-Standard

    // Divisor de reloj 50 MHz -> 25 MHz para el dominio VGA
    logic clk_25;
    always_ff @(posedge CLOCK_50 or posedge rst) begin
        if (rst)
            clk_25 <= 1'b0;
        else
            clk_25 <= ~clk_25;
    end
    assign VGA_CLK = clk_25;

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

    vga_test_pattern U_VGA_PATTERN (
        .pixel_x (pixel_x),
        .pixel_y (pixel_y),
        .video_on(video_on),
        .vga_r   (VGA_R),
        .vga_g   (VGA_G),
        .vga_b   (VGA_B)
    );

    // Salidas adicionales requeridas por el conector VGA de la DE10-Standard
    assign VGA_BLANK_N = video_on; // Activo alto durante región visible
    assign VGA_SYNC_N  = 1'b0;     // No se usa en monitores modernos

endmodule
