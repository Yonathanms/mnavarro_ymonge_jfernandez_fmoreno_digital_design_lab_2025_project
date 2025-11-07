// LSL/LSR

module barrel_shifter (
    input  logic [31:0] in,
    input  logic [4:0]  shamt,
    input  logic [1:0]  kind,   // 00 LSL, 01 LSR
    output logic [31:0] out
);

    always_comb begin
        case (kind)
            2'b00: out = in << shamt;
            2'b01: out = in >> shamt;
            default: out = in;
        endcase
    end

endmodule
