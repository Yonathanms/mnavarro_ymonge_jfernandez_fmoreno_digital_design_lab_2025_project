// Renderer de texto para 640x480@60 que lee caracteres de la VRAM
// y consulta la ROM de fuente 8x16 para generar RGB.
module vga_renderer #(
    parameter int TEXT_COLS   = 40,
    parameter int TEXT_ROWS   = 25,
    parameter int H_OFFSET_PIX = 32,  // margen horizontal en píxeles
    parameter int V_OFFSET_PIX = 32,  // margen vertical en píxeles
    parameter logic [7:0] FG_R = 8'hFF,
    parameter logic [7:0] FG_G = 8'hFF,
    parameter logic [7:0] FG_B = 8'hFF,
    parameter logic [7:0] BG_R = 8'h00,
    parameter logic [7:0] BG_G = 8'h00,
    parameter logic [7:0] BG_B = 8'h20
) (
    input  logic        clk_pix,
    input  logic        rst,
    input  logic        video_on,
    input  logic [9:0]  pixel_x,
    input  logic [9:0]  pixel_y,

    // Interfaz al puerto B de la VRAM (lectura)
    output logic [9:0]  vram_addr_b,
    input  logic [31:0] vram_q_b,

    output logic [7:0]  vga_r,
    output logic [7:0]  vga_g,
    output logic [7:0]  vga_b
);

    localparam int CELL_SIZE = 16;
    localparam int ACTIVE_W  = TEXT_COLS * CELL_SIZE;
    localparam int ACTIVE_H  = TEXT_ROWS * CELL_SIZE;

    logic inside_window;
    logic [9:0] adj_x;
    logic [9:0] adj_y;
    logic [5:0] text_col;
    logic [5:0] text_row;

    always_comb begin
        inside_window = (pixel_x >= H_OFFSET_PIX) && (pixel_x < (H_OFFSET_PIX + ACTIVE_W)) &&
                        (pixel_y >= V_OFFSET_PIX) && (pixel_y < (V_OFFSET_PIX + ACTIVE_H));
        if (pixel_x >= H_OFFSET_PIX)
            adj_x = pixel_x - H_OFFSET_PIX;
        else
            adj_x = 10'd0;

        if (pixel_y >= V_OFFSET_PIX)
            adj_y = pixel_y - V_OFFSET_PIX;
        else
            adj_y = 10'd0;

        text_col = adj_x[9:4];
        text_row = adj_y[9:4];
    end

    logic [3:0] row_in_char_s0, subcol_s0;
    logic       video_on_s0, active_text_s0;
    logic [9:0] next_vram_addr;

    // Cálculo de índice en VRAM (row*40 + col) mediante shift-add.
    function automatic logic [9:0] calc_index(input logic [5:0] row, input logic [5:0] col);
        logic [9:0] mul32;
        logic [9:0] mul8;
        logic [10:0] tmp;
        begin
            mul32 = {row, 5'b0};       // row * 32
            mul8  = {row[4:0], 3'b0};  // row * 8
            tmp   = mul32 + mul8 + {{5{1'b0}}, col[4:0]};
            calc_index = tmp[9:0];
        end
    endfunction

    always_comb begin
        if (text_row < TEXT_ROWS && text_col < TEXT_COLS)
            next_vram_addr = calc_index(text_row, text_col);
        else
            next_vram_addr = 10'd0;
    end

    // Registros de etapa 0 (sincronizados a clk_pix)
    always_ff @(posedge clk_pix or posedge rst) begin
        if (rst) begin
            vram_addr_b   <= 10'd0;
            row_in_char_s0 <= 4'd0;
            subcol_s0      <= 4'd0;
            video_on_s0    <= 1'b0;
            active_text_s0 <= 1'b0;
        end else begin
            vram_addr_b   <= next_vram_addr;
            row_in_char_s0 <= pixel_y[3:0];
            subcol_s0      <= pixel_x[3:0];
            video_on_s0    <= video_on;
            active_text_s0 <= inside_window && video_on;
        end
    end

    // Etapa 1: datos provenientes de la VRAM (registrados internamente en el IP)
    logic [3:0] row_in_char_s1, subcol_s1;
    logic       video_on_s1, active_text_s1;
    logic [7:0] ascii_s1;

    always_ff @(posedge clk_pix or posedge rst) begin
        if (rst) begin
            row_in_char_s1 <= 4'd0;
            subcol_s1      <= 4'd0;
            video_on_s1    <= 1'b0;
            active_text_s1 <= 1'b0;
            ascii_s1       <= 8'h20;
        end else begin
            row_in_char_s1 <= row_in_char_s0;
            subcol_s1      <= subcol_s0;
            video_on_s1    <= video_on_s0;
            active_text_s1 <= active_text_s0;
            ascii_s1       <= active_text_s0 ? vram_q_b[7:0] : 8'h20;
        end
    end

    // ROM de fuente (1 ciclo de latencia)
    logic [7:0] glyph_row_s2;
    font_rom U_FONT (
        .clk       (clk_pix),
        .char_code (ascii_s1),
        .row_index (row_in_char_s1),
        .glyph_row (glyph_row_s2)
    );

    // Etapa 2: selección del bit correspondiente y generación de color
    logic [3:0] subcol_s2;
    logic       video_on_s2, active_text_s2;
    always_ff @(posedge clk_pix or posedge rst) begin
        if (rst) begin
            subcol_s2      <= 4'd0;
            video_on_s2    <= 1'b0;
            active_text_s2 <= 1'b0;
        end else begin
            subcol_s2      <= subcol_s1;
            video_on_s2    <= video_on_s1;
            active_text_s2 <= active_text_s1;
        end
    end

    wire [2:0] font_bit_index = 3'd7 - subcol_s2[3:1]; // Duplicamos horizontalmente (2 pixeles por bit)
    wire       pixel_on = video_on_s2 && active_text_s2 && glyph_row_s2[font_bit_index];

    always_comb begin
        if (pixel_on) begin
            vga_r = FG_R;
            vga_g = FG_G;
            vga_b = FG_B;
        end else begin
            vga_r = BG_R;
            vga_g = BG_G;
            vga_b = BG_B;
        end
    end

endmodule
