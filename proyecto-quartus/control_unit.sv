module control_unit (
    input  logic        cond_ok,
    input  logic [1:0]  type,
    input  logic [3:0]  opcode,
    output logic        RegWrite,
    output logic        MemWrite,
    output logic        MemToReg,
    output logic        Branch
);

    always_comb begin
        RegWrite = 0;
        MemWrite = 0;
        MemToReg = 0;
        Branch   = 0;

        if (!cond_ok) begin
            // Do nothing
        end
        else begin
            case (type)
                2'd0: RegWrite = 1;           // DataProc
                2'd1: begin
                    if (opcode[0]) begin
                        RegWrite = 1;         // LDR
                        MemToReg = 1;
                    end else begin
                        MemWrite = 1;         // STR
                    end
                end
                2'd2: Branch = 1;             // B
            endcase
        end
    end

endmodule
