// Sistema centralizado de memoria con decodificador de 4 regiones
// ROM[0x0000_0000 - 0x0000_03FF]: ROM de instrucciones (1024 palabras)
// RAM[0x1000_0000 - 0x1000_03FF]: RAM de datos (1024 palabras)
// PS2[0x2000_0000 - 0x2000_00FF]: Registros PS/2 (reservado)
// VRAM[0x3000_0000 - 0x3000_03FF]: VRAM dual-puerto (1024 palabras)

module mem_system #(
    parameter bit INCLUDE_VRAM = 1'b0
) (
    input  logic        clk,
    input  logic [31:0] addr,          // Dirección completa (32 bits)
    input  logic [31:0] write_data,    // Datos a escribir
    input  logic        MemWrite,      // Señal de escritura
    output logic [31:0] read_data,     // Datos leídos

    // Interfaz del puerto B de la VRAM (solo se usa si INCLUDE_VRAM=1)
    input  logic        vram_clk_b,
    input  logic [9:0]  vram_addr_b,
    output logic [31:0] vram_q_b
);

    // Señales de ROM
    logic [9:0]  rom_addr;
    logic [31:0] rom_data;

    // Señales de RAM
    logic [9:0]  ram_addr;
    logic [31:0] ram_data;
    logic        ram_we;

    // Señales de VRAM (solo válidas si INCLUDE_VRAM=1)
    logic [9:0]  vram_addr_a;
    logic [31:0] vram_q_a;
    logic        vram_we;

    // Decodificar región según bits [31:28] de dirección
    logic [3:0] region;
    assign region = addr[31:28];

    // Decodificar dirección local de 10 bits desde bits [11:2]
    assign rom_addr   = addr[11:2];
    assign ram_addr   = addr[11:2];
    assign vram_addr_a = addr[11:2];

    // Instanciar ROM de instrucciones (módulo generado por IP Catalog)
    rom_module U_ROM (
        .address (rom_addr),
        .clock   (clk),
        .q       (rom_data)
    );

    // Instanciar RAM de datos (módulo generado por IP Catalog)
    ram_module U_RAM (
        .address (ram_addr),
        .clock   (clk),
        .data    (write_data),
        .wren    (ram_we),
        .q       (ram_data)
    );

    // Lógica de escritura a RAM: solo cuando región es 0x1 (RAM) y MemWrite es 1
    assign ram_we = (region == 4'h1 && MemWrite) ? 1'b1 : 1'b0;

    assign vram_we = (INCLUDE_VRAM && region == 4'h3 && MemWrite) ? 1'b1 : 1'b0;

    // Generación condicional de la VRAM dual-port
    generate
        if (INCLUDE_VRAM) begin : g_vram
            vram_2puertos U_VRAM (
                .clock_a   (clk),
                .clock_b   (vram_clk_b),
                .address_a (vram_addr_a),
                .address_b (vram_addr_b),
                .data_a    (write_data),
                .data_b    (32'h0000_0000),
                .wren_a    (vram_we),
                .wren_b    (1'b0),
                .q_a       (vram_q_a),
                .q_b       (vram_q_b)
            );
        end else begin : g_no_vram
            assign vram_q_a = 32'h0000_0000;
            assign vram_q_b = 32'h0000_0000;
        end
    endgenerate

    // Multiplexor de lectura según región decodificada
    always_comb begin
        case (region)
            4'h0: read_data = rom_data;      // ROM: 0x0000_0000
            4'h1: read_data = ram_data;      // RAM: 0x1000_0000
            4'h2: read_data = 32'h0000_0000; // PS2: 0x2000_0000 (reservado)
            4'h3: read_data = vram_q_a;      // VRAM: 0x3000_0000
            default: read_data = 32'h0000_0000;
        endcase
    end

endmodule
