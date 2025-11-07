module cond_check (
    input  logic [3:0] cond,
    input  logic N, Z, C, V,
    output logic cond_ok
);

    always_comb begin
        case (cond)
            4'h0: cond_ok =  Z;               // EQ
            4'h1: cond_ok = !Z;               // NE
            4'h2: cond_ok =  C;               // CS
            4'h3: cond_ok = !C;               // CC
            4'h4: cond_ok =  N;               // MI
            4'h5: cond_ok = !N;               // PL
            4'h6: cond_ok =  V;               // VS
            4'h7: cond_ok = !V;               // VC
            4'h8: cond_ok =  C && !Z;         // HI
            4'h9: cond_ok = !C ||  Z;         // LS
            4'hA: cond_ok = (N == V);         // GE
            4'hB: cond_ok = (N != V);         // LT
            4'hC: cond_ok = (Z==0) && (N==V); // GT
            4'hD: cond_ok = (Z==1) || (N!=V); // LE
            4'hE: cond_ok = 1'b1;             // AL
            default: cond_ok = 1'b1;
        endcase
    end

endmodule
