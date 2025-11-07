//RAM

module data_mem (
    input  logic        clk,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] din,
    output logic [31:0] dout
);

    logic [31:0] mem [0:1023];

    assign dout = mem[addr[11:2]];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr[11:2]] <= din;
    end

endmodule
