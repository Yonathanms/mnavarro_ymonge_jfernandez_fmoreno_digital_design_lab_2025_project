

module regfile (
    input  logic        clk,
    input  logic        we,
    input  logic [3:0]  ra1, ra2,
    input  logic [3:0]  wa,
    input  logic [31:0] wd,
    output logic [31:0] rd1, rd2
);

    logic [31:0] regs [15:0];

    assign rd1 = regs[ra1];
    assign rd2 = regs[ra2];

    always_ff @(posedge clk) begin
        if (we)
            regs[wa] <= wd;
    end

endmodule
