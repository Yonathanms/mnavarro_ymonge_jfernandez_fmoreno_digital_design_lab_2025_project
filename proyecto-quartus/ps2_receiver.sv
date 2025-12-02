// ============================================================
// Receptor PS/2 con FSM de 11 bits
// ============================================================
// - Detecta flanco descendente en ps2_clk_sync
// - Lee 11 bits: start + 8 data + parity + stop
// - Verifica paridad impar
// - Timeout de 2ms para frames incompletos
// ============================================================

module ps2_receiver (
    input  logic       clk,             // Reloj del sistema (50 MHz)
    input  logic       rst,
    input  logic       ps2_clk_sync,    // PS/2 CLK sincronizado
    input  logic       ps2_data_sync,   // PS/2 DATA sincronizado
    output logic [7:0] scancode,        // Scancode recibido
    output logic       scancode_ready,  // Pulso de 1 ciclo
    output logic       error            // Error de paridad o timeout
);

    // ========================================
    // Detector de flanco descendente
    // ========================================
    logic ps2_clk_prev;
    logic ps2_clk_negedge;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            ps2_clk_prev <= 1'b1;
        else
            ps2_clk_prev <= ps2_clk_sync;
    end

    assign ps2_clk_negedge = ps2_clk_prev && !ps2_clk_sync;

    // ========================================
    // FSM de recepción
    // ========================================
    typedef enum logic [3:0] {
        IDLE,
        START_BIT,
        DATA_BIT_0,
        DATA_BIT_1,
        DATA_BIT_2,
        DATA_BIT_3,
        DATA_BIT_4,
        DATA_BIT_5,
        DATA_BIT_6,
        DATA_BIT_7,
        PARITY_BIT,
        STOP_BIT
    } state_t;

    state_t state;
    logic [7:0] shift_reg;
    logic parity_bit;

    // Timeout: 2ms @ 50MHz = 100,000 ciclos
    logic [16:0] timeout_counter;
    localparam TIMEOUT_MAX = 17'd100_000;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= IDLE;
            shift_reg       <= 8'h00;
            parity_bit      <= 1'b0;
            scancode        <= 8'h00;
            scancode_ready  <= 1'b0;
            error           <= 1'b0;
            timeout_counter <= 17'd0;
        end else begin
            scancode_ready <= 1'b0;  // Pulso de 1 ciclo

            case (state)
                IDLE: begin
                    timeout_counter <= 17'd0;
                    if (ps2_clk_negedge && !ps2_data_sync) begin
                        // Start bit detectado (debe ser 0)
                        state <= DATA_BIT_0;
                    end
                end

                DATA_BIT_0, DATA_BIT_1, DATA_BIT_2, DATA_BIT_3,
                DATA_BIT_4, DATA_BIT_5, DATA_BIT_6, DATA_BIT_7: begin
                    timeout_counter <= timeout_counter + 1;
                    if (timeout_counter >= TIMEOUT_MAX) begin
                        state <= IDLE;
                        error <= 1'b1;
                    end else if (ps2_clk_negedge) begin
                        shift_reg <= {ps2_data_sync, shift_reg[7:1]};
                        state <= state_t'(state + 1);
                    end
                end

                PARITY_BIT: begin
                    timeout_counter <= timeout_counter + 1;
                    if (timeout_counter >= TIMEOUT_MAX) begin
                        state <= IDLE;
                        error <= 1'b1;
                    end else if (ps2_clk_negedge) begin
                        parity_bit <= ps2_data_sync;
                        state <= STOP_BIT;
                    end
                end

                STOP_BIT: begin
                    timeout_counter <= timeout_counter + 1;
                    if (timeout_counter >= TIMEOUT_MAX) begin
                        state <= IDLE;
                        error <= 1'b1;
                    end else if (ps2_clk_negedge) begin
                        // Verificar paridad impar y stop bit = 1
                        if (ps2_data_sync && ((^shift_reg) ^ parity_bit)) begin
                            scancode       <= shift_reg;
                            scancode_ready <= 1'b1;
                            error          <= 1'b0;
                        end else begin
                            error <= 1'b1;
                        end
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
