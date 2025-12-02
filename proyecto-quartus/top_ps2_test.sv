// ============================================================
// Test standalone para validación de hardware PS/2
// ============================================================
// - Muestra último scancode en LEDR[7:0]
// - LED[8] = new_data recibido
// - LED[9] = error (paridad o timeout)
// ============================================================

module top_ps2_test (
    input  logic       CLOCK_50,
    input  logic [0:0] KEY,
    input  logic       PS2_CLK,
    input  logic       PS2_DAT,
    output logic [9:0] LEDR
);

    logic rst;
    assign rst = ~KEY[0];

    // Señales sincronizadas
    logic ps2_clk_sync, ps2_data_sync;

    // Señales del receptor
    logic [7:0] scancode;
    logic scancode_ready;
    logic error;

    // Instancia del sincronizador
    ps2_sync U_SYNC (
        .clk           (CLOCK_50),
        .rst           (rst),
        .ps2_clk       (PS2_CLK),
        .ps2_data      (PS2_DAT),
        .ps2_clk_sync  (ps2_clk_sync),
        .ps2_data_sync (ps2_data_sync)
    );

    // Instancia del receptor
    ps2_receiver U_RECEIVER (
        .clk            (CLOCK_50),
        .rst            (rst),
        .ps2_clk_sync   (ps2_clk_sync),
        .ps2_data_sync  (ps2_data_sync),
        .scancode       (scancode),
        .scancode_ready (scancode_ready),
        .error          (error)
    );

    // Registro para capturar último scancode
    logic [7:0] last_scancode;
    logic error_sticky;

    always_ff @(posedge CLOCK_50 or posedge rst) begin
        if (rst) begin
            last_scancode <= 8'h00;
            error_sticky  <= 1'b0;
        end else begin
            if (scancode_ready)
                last_scancode <= scancode;
            if (error)
                error_sticky <= 1'b1;
        end
    end

    // Asignación a LEDs
    assign LEDR[7:0] = last_scancode;
    assign LEDR[8]   = scancode_ready;
    assign LEDR[9]   = error_sticky;

endmodule
