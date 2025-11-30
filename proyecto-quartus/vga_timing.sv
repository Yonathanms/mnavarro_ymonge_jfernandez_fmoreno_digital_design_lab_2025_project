// Generador de temporizacion VGA 640x480@60Hz con polaridad negativa en HS/VS.
// Produce coordenadas de pixel y senal video_on para que otro bloque pinte el color.
module vga_timing (
    input  logic       clk_pix,   // Reloj de pixeles (25 MHz)
    input  logic       rst,       // Reset sincronico activo alto
    output logic       hsync,     // Senal HSYNC activa en bajo
    output logic       vsync,     // Senal VSYNC activa en bajo
    output logic       video_on,  // Indica region visible
    output logic [9:0] pixel_x,   // Coordenada X (0-639)
    output logic [9:0] pixel_y    // Coordenada Y (0-479)
);

    // Parametros estandar VGA 640x480@60Hz (ver tinyvga.com)
    localparam int H_VISIBLE = 640;
    localparam int H_FRONT   = 16;
    localparam int H_SYNC    = 96;
    localparam int H_BACK    = 48;
    localparam int H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800

    localparam int V_VISIBLE = 480;
    localparam int V_FRONT   = 10;
    localparam int V_SYNC    = 2;
    localparam int V_BACK    = 33;
    localparam int V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    logic [9:0] h_count;  // 0-799
    logic [9:0] v_count;  // 0-524

    // Contador horizontal
    always_ff @(posedge clk_pix or posedge rst) begin
        if (rst)
            h_count <= 10'd0;
        else if (h_count == H_TOTAL - 1)
            h_count <= 10'd0;
        else
            h_count <= h_count + 10'd1;
    end

    // Contador vertical
    always_ff @(posedge clk_pix or posedge rst) begin
        if (rst)
            v_count <= 10'd0;
        else if (h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1)
                v_count <= 10'd0;
            else
                v_count <= v_count + 10'd1;
        end
    end

    assign pixel_x = h_count;
    assign pixel_y = v_count;

    // Zona visible
    assign video_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    // Pulsos activos en bajo segun especificacion VGA
    assign hsync = ~((h_count >= H_VISIBLE + H_FRONT) &&
                     (h_count <  H_VISIBLE + H_FRONT + H_SYNC));

    assign vsync = ~((v_count >= V_VISIBLE + V_FRONT) &&
                     (v_count <  V_VISIBLE + V_FRONT + V_SYNC));

endmodule
