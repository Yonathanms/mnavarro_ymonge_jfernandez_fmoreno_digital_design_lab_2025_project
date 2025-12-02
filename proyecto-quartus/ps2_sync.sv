// ============================================================
// Sincronizador PS/2 con filtro anti-rebote
// ============================================================
// - Doble flip-flop para prevenir metaestabilidad
// - Filtro de 3 muestras para eliminar glitches
// ============================================================

module ps2_sync (
    input  logic clk,           // Reloj del sistema (50 MHz)
    input  logic rst,
    input  logic ps2_clk,       // Señal PS/2 CLK asíncrona
    input  logic ps2_data,      // Señal PS/2 DATA asíncrona
    output logic ps2_clk_sync,  // PS/2 CLK sincronizada
    output logic ps2_data_sync  // PS/2 DATA sincronizada
);

    // ========================================
    // Doble flip-flop para sincronización
    // ========================================
    logic ps2_clk_ff1, ps2_clk_ff2;
    logic ps2_data_ff1, ps2_data_ff2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ps2_clk_ff1  <= 1'b1;
            ps2_clk_ff2  <= 1'b1;
            ps2_data_ff1 <= 1'b1;
            ps2_data_ff2 <= 1'b1;
        end else begin
            ps2_clk_ff1  <= ps2_clk;
            ps2_clk_ff2  <= ps2_clk_ff1;
            ps2_data_ff1 <= ps2_data;
            ps2_data_ff2 <= ps2_data_ff1;
        end
    end

    // ========================================
    // Filtro anti-rebote de 3 muestras
    // ========================================
    logic [2:0] ps2_clk_filter;
    logic [2:0] ps2_data_filter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ps2_clk_filter  <= 3'b111;
            ps2_data_filter <= 3'b111;
        end else begin
            ps2_clk_filter  <= {ps2_clk_filter[1:0], ps2_clk_ff2};
            ps2_data_filter <= {ps2_data_filter[1:0], ps2_data_ff2};
        end
    end

    // Salida estable: todas las muestras deben coincidir
    assign ps2_clk_sync  = (ps2_clk_filter == 3'b111) ? 1'b1 :
                           (ps2_clk_filter == 3'b000) ? 1'b0 : ps2_clk_sync;
    assign ps2_data_sync = (ps2_data_filter == 3'b111) ? 1'b1 :
                           (ps2_data_filter == 3'b000) ? 1'b0 : ps2_data_sync;

endmodule
