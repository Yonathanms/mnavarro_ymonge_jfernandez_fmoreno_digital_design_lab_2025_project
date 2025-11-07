//ROM

module instr_mem (
    input  logic [31:0] addr,
    output logic [31:0] dout
);

    logic [31:0] mem [0:1023];   // 4 KB

    assign dout = mem[addr[11:2]];   // word aligned

endmodule
