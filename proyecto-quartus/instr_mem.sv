// ROM de instrucciones simple
module instr_mem (
    input  logic [31:0] addr,
    output logic [31:0] dout
);
    always_comb begin
        case (addr[11:2])
            10'd0: dout = 32'he0801000; // ADD R1, R0, R0
            10'd1: dout = 32'he0811001; // ADD R1, R1, R1
            10'd2: dout = 32'he5801000; // STR R1, [R0, #0]
            10'd3: dout = 32'he5902000; // LDR R2, [R0, #0]
            10'd4: dout = 32'heaffffff; // B -1, loop en la misma dirección con pc_plus4

            default: dout = 32'h00000000;
        endcase
    end
endmodule
