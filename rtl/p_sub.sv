module p_sub (
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

    genvar i;
    generate
        for (i = 0; i < 64; i++) begin : sbox_loop
            // s_box is LSB-first: s_in[0]=x0 ... s_in[4]=x4 (and same for
            // s_out). In a concat the RIGHTMOST item is bit 0, so x0/y0 go
            // last. Getting this order backwards silently computes the wrong
            // permutation (it still "runs" -- verify against the reference).
            s_box sbox_inst (
                .s_in ({x4[i], x3[i], x2[i], x1[i], x0[i]}),
                .s_out({y4[i], y3[i], y2[i], y1[i], y0[i]})
            );
        end
    endgenerate

    assign s_out = {y4, y3, y2, y1, y0};

endmodule