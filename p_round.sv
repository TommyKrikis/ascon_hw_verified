module p_round(
    // data
    input  logic [319:0] state_in,
    input logic [3:0]  round_curr,
    output logic [319:0] state_out
);
  logic [319:0] p_add_out,p_sub_out;

    p_add_const p_add_const_inst (
        .s_in(state_in),
        .round_i(round_curr),
        .s_out(p_add_out)
    );

    p_sub p_sub_inst (
        .s_in(p_add_out),
        .s_out(p_sub_out)
    );

    p_diff p_diff_inst (
        .s_in(p_sub_out),
        .s_out(state_out)
    );
endmodule
