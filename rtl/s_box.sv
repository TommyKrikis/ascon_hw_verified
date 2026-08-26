module s_box #(parameter WIDTH = 5) (
    input logic [WIDTH-1:0] s_in,
    output logic [WIDTH-1:0] s_out
);  
    logic a0, a1, a2, a3, a4;   
    logic n0, n1, n2, n3, n4;

    always_comb begin
        a0 = s_in[0] ^ s_in[4];
        a1 = s_in[1];
        a2 = s_in[2] ^ s_in[1];
        a3 = s_in[3];
        a4 = s_in[4] ^ s_in[3];

        n0 = a0 ^ (~a1 & a2);
        n1 = a1 ^ (~a2 & a3);
        n2 = a2 ^ (~a3 & a4);
        n3 = a3 ^ (~a4 & a0);
        n4 = a4 ^ (~a0 & a1);

        s_out[1] = n1 ^ n0;
        s_out[0] = n0 ^ n4;
        s_out[3] = n3 ^ n2;
        s_out[2] = ~n2;
        s_out[4] = n4;
    end
endmodule
