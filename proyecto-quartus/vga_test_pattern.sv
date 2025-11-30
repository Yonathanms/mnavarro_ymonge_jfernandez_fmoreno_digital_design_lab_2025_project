// Genera un patron de barras de color para validar el cableado VGA.
// Divide la pantalla en 8 columnas y asigna un color distinto a cada una.
module vga_test_pattern (
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    input  logic       video_on,
    output logic [7:0] vga_r,
    output logic [7:0] vga_g,
    output logic [7:0] vga_b
);

    typedef enum int unsigned {
        BAR_RED = 0,
        BAR_YELLOW,
        BAR_GREEN,
        BAR_CYAN,
        BAR_BLUE,
        BAR_MAGENTA,
        BAR_WHITE,
        BAR_GRAY
    } bar_t;

    bar_t bar_sel;

    always_comb begin
        // 640 / 8 = 80 pixeles por barra vertical
        if      (pixel_x < 10'd80)   bar_sel = BAR_RED;
        else if (pixel_x < 10'd160)  bar_sel = BAR_YELLOW;
        else if (pixel_x < 10'd240)  bar_sel = BAR_GREEN;
        else if (pixel_x < 10'd320)  bar_sel = BAR_CYAN;
        else if (pixel_x < 10'd400)  bar_sel = BAR_BLUE;
        else if (pixel_x < 10'd480)  bar_sel = BAR_MAGENTA;
        else if (pixel_x < 10'd560)  bar_sel = BAR_WHITE;
        else                         bar_sel = BAR_GRAY;
    end

    always_comb begin
        if (!video_on) begin
            vga_r = 8'd0;
            vga_g = 8'd0;
            vga_b = 8'd0;
        end else begin
            unique case (bar_sel)
                BAR_RED: begin
                    vga_r = 8'hFF;
                    vga_g = 8'd0;
                    vga_b = 8'd0;
                end
                BAR_YELLOW: begin
                    vga_r = 8'hFF;
                    vga_g = 8'hFF;
                    vga_b = 8'd0;
                end
                BAR_GREEN: begin
                    vga_r = 8'd0;
                    vga_g = 8'hFF;
                    vga_b = 8'd0;
                end
                BAR_CYAN: begin
                    vga_r = 8'd0;
                    vga_g = 8'hFF;
                    vga_b = 8'hFF;
                end
                BAR_BLUE: begin
                    vga_r = 8'd0;
                    vga_g = 8'd0;
                    vga_b = 8'hFF;
                end
                BAR_MAGENTA: begin
                    vga_r = 8'hFF;
                    vga_g = 8'd0;
                    vga_b = 8'hFF;
                end
                BAR_WHITE: begin
                    vga_r = 8'hFF;
                    vga_g = 8'hFF;
                    vga_b = 8'hFF;
                end
                default: begin
                    vga_r = 8'h7F;
                    vga_g = 8'h7F;
                    vga_b = 8'h7F;
                end
            endcase
        end
    end

endmodule
