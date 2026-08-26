module p_add_const (
    input  logic [319:0] s_in,
    input  logic [3:0]   round_i,
    output logic [319:0] s_out
);
    logic [11:0][63:0] cr;
    assign cr[0]  = 64'h00000000000000f0;
    assign cr[1]  = 64'h00000000000000e1;
    assign cr[2]  = 64'h00000000000000d2;
    assign cr[3]  = 64'h00000000000000c3;
    assign cr[4]  = 64'h00000000000000b4;
    assign cr[5]  = 64'h00000000000000a5;
    assign cr[6]  = 64'h0000000000000096;
    assign cr[7]  = 64'h0000000000000087;
    assign cr[8]  = 64'h0000000000000078;
    assign cr[9]  = 64'h0000000000000069;
    assign cr[10] = 64'h000000000000005a;
    assign cr[11] = 64'h000000000000004b;

    logic [63:0] x0, x1, x2, x3, x4, x2_out;

    assign x0 = s_in[ 63:  0];
    assign x1 = s_in[127: 64];
    assign x2 = s_in[191:128];
    assign x3 = s_in[255:192];
    assign x4 = s_in[319:256];

    always_comb begin
        x2_out = x2 ^ cr[round_i];
    end

    assign s_out = {x4, x3, x2_out, x1, x0};
endmodule