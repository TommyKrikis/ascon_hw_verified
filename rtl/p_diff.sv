module p_diff (
    input  logic [319:0] s_in,
    output logic [319:0] s_out
);

    logic [63:0] x0, x1, x2, x3, x4;
    logic [63:0] y0, y1, y2, y3, y4;

    assign x0 = s_in[ 63:  0];
    assign x1 = s_in[127: 64];
    assign x2 = s_in[191:128];
    assign x3 = s_in[255:192];
    assign x4 = s_in[319:256];

    function automatic logic [63:0] ror(input logic [63:0] v, input int n);
        ror = (v >> n) | (v << (64 - n));
    endfunction

    always_comb begin
        y0 = x0 ^ ror(x0, 19) ^ ror(x0, 28);
        y1 = x1 ^ ror(x1, 61) ^ ror(x1, 39);
        y2 = x2 ^ ror(x2,  1) ^ ror(x2,  6);
        y3 = x3 ^ ror(x3, 10) ^ ror(x3, 17);
        y4 = x4 ^ ror(x4,  7) ^ ror(x4, 41);
    end

    assign s_out = {y4, y3, y2, y1, y0};

endmodule
