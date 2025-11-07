//instr_type: 0=DataProc, 1=Load/Store, 2=Branch, 3=Otro

module control_unit (
    input  logic        cond_ok,
    input  logic [1:0]  instr_type,
    input  logic [3:0]  opcode,
    input  logic        S,          
    output logic        RegWrite,
    output logic        MemWrite,
    output logic        MemToReg,
    output logic        Branch,
    output logic        FlagWrite,
    output logic        ALUSrcB     
);

    always_comb begin
        
        RegWrite = 1'b0;
        MemWrite = 1'b0;
        MemToReg = 1'b0;
        Branch   = 1'b0;
        FlagWrite= 1'b0;
        ALUSrcB  = 1'b0;

        if (!cond_ok) begin
       
        end
        else begin
            unique case (instr_type)

                // data proccessing
                2'd0: begin
                    RegWrite  = (opcode != 4'b1010);
                    FlagWrite = (S == 1'b1) || (opcode == 4'b1010);
                    ALUSrcB   = 1'b0;    
                end
					 
                // load/store 
                2'd1: begin
                    ALUSrcB = 1'b1;      
                    FlagWrite = 1'b0;
                    if (S) begin
                        // ldr
                        RegWrite = 1'b1;
                        MemToReg = 1'b1;
                    end else begin
                        // str
                        MemWrite = 1'b1;
                    end
                end

                // branch
                2'd2: begin
                    Branch = 1'b1;
                end

                default: ;   
            endcase
        end
    end

endmodule
