module p_add_const #(parameter WIDTH = 64) (
    input logic [WIDTH-1:0] x2_in,
    input logic [3:0] round_i,
    output logic [WIDTH-1:0] x2_out
);
    logic [11:0][WIDTH-1:0] cr;
    assign cr[0] = 64'h00000000000000f0;
    assign cr[1] = 64'h00000000000000e1;
    assign cr[2] = 64'h00000000000000d2;
    assign cr[3] = 64'h00000000000000c3;
    assign cr[4] = 64'h00000000000000b4;
    assign cr[5] = 64'h00000000000000a5;
    assign cr[6] = 64'h0000000000000096;
    assign cr[7] = 64'h0000000000000087;
    assign cr[8] = 64'h0000000000000078;
    assign cr[9] = 64'h0000000000000069;
    assign cr[10] = 64'h000000000000005a;
    assign cr[11] = 64'h000000000000004b;
    
    always_comb begin
    x2_out = x2_in ^ cr[round_i[3:0] < 12 ? round_i[3:0] : 4'd0];
    end
endmodule
      