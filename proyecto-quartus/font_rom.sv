// ROM de caracteres 8x16 (256 caracteres)
// Cada acceso entrega una fila (8 bits) del glifo solicitado.
module font_rom (
    input  logic       clk,
    input  logic [7:0] char_code,  // Código ASCII a mostrar
    input  logic [3:0] row_index,  // Fila dentro del glifo (0-15)
    output logic [7:0] glyph_row   // Bits de la fila (MSB = pixel izquierdo)
);

    logic [11:0] rd_addr;
    assign rd_addr = {char_code, row_index};

    altsyncram font_rom_component (
        .address_a (rd_addr),
        .clock0    (clk),
        .q_a       (glyph_row),
        .aclr0     (1'b0),
        .aclr1     (1'b0),
        .address_b (1'b0),
        .clock1    (1'b1),
        .clocken0  (1'b1),
        .clocken1  (1'b1),
        .clocken2  (1'b1),
        .clocken3  (1'b1),
        .data_a    (8'b0),
        .data_b    (8'b0),
        .eccstatus (),
        .q_b       (),
        .rden_a    (1'b1),
        .rden_b    (1'b1),
        .wren_a    (1'b0),
        .wren_b    (1'b0)
    );

    defparam
        font_rom_component.clock_enable_input_a = "BYPASS",
        font_rom_component.clock_enable_output_a = "BYPASS",
        font_rom_component.init_file = "font_8x16.mif",
        font_rom_component.intended_device_family = "Cyclone V",
        font_rom_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
        font_rom_component.lpm_type = "altsyncram",
        font_rom_component.numwords_a = 4096,
        font_rom_component.operation_mode = "ROM",
        font_rom_component.outdata_aclr_a = "NONE",
        font_rom_component.outdata_reg_a = "UNREGISTERED",
        font_rom_component.widthad_a = 12,
        font_rom_component.width_a = 8,
        font_rom_component.width_byteena_a = 1;

endmodule
