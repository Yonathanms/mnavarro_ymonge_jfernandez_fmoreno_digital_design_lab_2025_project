

module regfile (
    input  logic        clk,
    input  logic        rst,
    input  logic        we,
    input  logic [3:0]  ra1, ra2,
    input  logic [3:0]  wa,
    input  logic [31:0] wd,
    output logic [31:0] rd1, rd2
);

    logic [31:0] regs [15:0];

    assign rd1 = regs[ra1];
    assign rd2 = regs[ra2];

    always_ff @(posedge clk or posedge rst) begin
        integer i;
        if (rst) begin
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 32'h0000_0000;
        end else if (we) begin
            regs[wa] <= wd;
        end
    end

endmodule
