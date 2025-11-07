module top_fpga (
    input  logic CLOCK_50,
    input  logic [0:0] KEY,
    output logic [9:0] LEDR
);

    logic rst;
    logic [31:0] debug_pc;

    assign rst = ~KEY[0];  // presionar = reset

    cpu_top U_CPU (
        .clk      (CLOCK_50),
        .rst      (rst),
        .debug_pc (debug_pc)
    );

    // Mostrar bits bajos del PC
    assign LEDR[9:0] = debug_pc[9:0];

endmodule
