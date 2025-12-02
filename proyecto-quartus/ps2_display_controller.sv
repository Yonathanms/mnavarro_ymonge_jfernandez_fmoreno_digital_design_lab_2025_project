// ============================================================
// Controlador auxiliar para display de scancodes PS/2
// (Reservado para expansión futura)
// ============================================================

module ps2_display_controller (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] scancode,
    input  logic       new_data,
    output logic [7:0] display_out
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            display_out <= 8'h00;
        else if (new_data)
            display_out <= scancode;
    end

endmodule
