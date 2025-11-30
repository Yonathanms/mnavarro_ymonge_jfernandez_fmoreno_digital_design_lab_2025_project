module vga_pattern (
    input  logic [9:0] h_cnt,        // contador horizontal (0..799)
    input  logic [9:0] v_cnt,        // contador vertical   (0..524)
    input  logic       video_on,     // 1 dentro de 640x480 visible
    input  logic [3:0] sel_key,      // tecla seleccionada (0-9)
    input  logic [31:0] display_value, // valor a mostrar (futuro)

    output logic [7:0] vga_r,
    output logic [7:0] vga_g,
    output logic [7:0] vga_b
);

    // ---------------------------------------------------------
    // Fondo general (azul oscuro)
    // ---------------------------------------------------------
    logic [7:0] r_bg, g_bg, b_bg;

    always_comb begin
        r_bg = 8'h00;
        g_bg = 8'h10;
        b_bg = 8'h40;
    end

    // ---------------------------------------------------------
    // Área de DISPLAY (pantalla de la calculadora)
    // ---------------------------------------------------------
    localparam int DISP_X0 = 40;
    localparam int DISP_X1 = 600;
    localparam int DISP_Y0 = 20;
    localparam int DISP_Y1 = 80;

    logic in_disp;

    assign in_disp =
        (h_cnt >= DISP_X0) && (h_cnt < DISP_X1) &&
        (v_cnt >= DISP_Y0) && (v_cnt < DISP_Y1);

    // Por ahora solo pintamos la franja, luego ahí se dibujan dígitos
    // usando display_value.

    // ---------------------------------------------------------
    // Rejilla de botones tipo calculadora (4x4)
    // ---------------------------------------------------------

    localparam int COLS    = 4;
    localparam int ROWS    = 4;
    localparam int BTN_W   = 80;    // ancho de cada botón
    localparam int BTN_H   = 80;    // alto de cada botón
    localparam int GRID_X0 = 80;    // origen X de la rejilla
    localparam int GRID_Y0 = 120;   // origen Y de la rejilla (debajo del display)

    // Comprobar si estamos dentro de la “zona” de la rejilla completa
    logic in_grid;
    assign in_grid =
        (h_cnt >= GRID_X0) &&
        (h_cnt <  GRID_X0 + COLS*BTN_W) &&
        (v_cnt >= GRID_Y0) &&
        (v_cnt <  GRID_Y0 + ROWS*BTN_H);

    // Coordenadas relativas dentro de la rejilla
    logic [9:0] x_rel, y_rel;
    assign x_rel = h_cnt - GRID_X0;
    assign y_rel = v_cnt - GRID_Y0;

    // Columna y fila del botón actual
    logic [1:0] col, row;  // 0..3
    assign col = x_rel / BTN_W;
    assign row = y_rel / BTN_H;

    // Índice del botón (0..15) = row*4 + col
    logic [4:0] btn_index;
    assign btn_index = row * COLS + col;

    // ¿Es el botón seleccionado según sel_key? (solo nos interesan 0..9)
    logic is_selected_btn;
    assign is_selected_btn =
        in_grid && (btn_index[3:0] == sel_key);

    // Margen interno para el “cuerpo” del botón
    localparam int MARGIN = 4;
    logic in_btn_body;

    assign in_btn_body =
        in_grid &&
        ((x_rel % BTN_W) >= MARGIN) &&
        ((x_rel % BTN_W) <  (BTN_W - MARGIN)) &&
        ((y_rel % BTN_H) >= MARGIN) &&
        ((y_rel % BTN_H) <  (BTN_H - MARGIN));

    // ---------------------------------------------------------
    // Lógica de color final
    // ---------------------------------------------------------
    always_comb begin
        // Por defecto: negro fuera de video_on
        vga_r = 8'h00;
        vga_g = 8'h00;
        vga_b = 8'h00;

        if (video_on) begin
            // Fondo base
            vga_r = r_bg;
            vga_g = g_bg;
            vga_b = b_bg;

            // Pantalla de la calculadora (barra superior)
            if (in_disp) begin
                vga_r = 8'h60;
                vga_g = 8'h60;
                vga_b = 8'h80;  // gris oscuro
            end

            // Cuerpo de los botones (gris claro)
            if (in_btn_body) begin
                vga_r = 8'hC0;
                vga_g = 8'hC0;
                vga_b = 8'hC0;
            end

            // Botón seleccionado → amarillo brillante
            if (in_btn_body && is_selected_btn) begin
                vga_r = 8'hFF;
                vga_g = 8'hFF;
                vga_b = 8'h00;
            end
        end
    end

endmodule
