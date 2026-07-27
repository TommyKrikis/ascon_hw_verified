`timescale 1ns/1ps

module tb_p_sub;

    localparam LANE_W = 64;
    localparam WIDTH  = 5 * LANE_W;

    logic [WIDTH-1:0] x_in;
    logic [WIDTH-1:0] x_out;

    int errors = 0;
    int checks = 0;

    // ---------------------------------------------------------------
    // DUT
    // ---------------------------------------------------------------
    p_sub #(.LANE_W(LANE_W)) dut (
        .x_in (x_in),
        .x_out(x_out)
    );

    // ---------------------------------------------------------------
    // Golden reference: Table 5 from the Ascon spec (authoritative
    // lookup table), not a re-derived formula. s_in[4:0] / s_out[4:0]
    // follow the same convention as s_box.sv: bit[4]=x0/y0 (MSB),
    // bit[0]=x4/y4 (LSB) -- i.e. table index/value read MSB-first.
    // ---------------------------------------------------------------
    function automatic [4:0] golden_sbox(input [4:0] x);
        logic [4:0] table_sbox [0:31];
        begin
            table_sbox[0]=5'h04; table_sbox[1]=5'h0b; table_sbox[2]=5'h1f; table_sbox[3]=5'h14;
            table_sbox[4]=5'h1a; table_sbox[5]=5'h15; table_sbox[6]=5'h09; table_sbox[7]=5'h02;
            table_sbox[8]=5'h1b; table_sbox[9]=5'h05; table_sbox[10]=5'h08; table_sbox[11]=5'h12;
            table_sbox[12]=5'h1d; table_sbox[13]=5'h03; table_sbox[14]=5'h06; table_sbox[15]=5'h1c;
            table_sbox[16]=5'h1e; table_sbox[17]=5'h13; table_sbox[18]=5'h07; table_sbox[19]=5'h0e;
            table_sbox[20]=5'h00; table_sbox[21]=5'h0d; table_sbox[22]=5'h11; table_sbox[23]=5'h18;
            table_sbox[24]=5'h10; table_sbox[25]=5'h0c; table_sbox[26]=5'h01; table_sbox[27]=5'h19;
            table_sbox[28]=5'h16; table_sbox[29]=5'h0a; table_sbox[30]=5'h0f; table_sbox[31]=5'h17;

            golden_sbox = table_sbox[x];
        end
    endfunction

    // Apply golden_sbox bit-sliced across all 64 lanes, same packing
    // convention as p_sub (lane0=bits[63:0], lane1=[127:64], ...).
    function automatic [WIDTH-1:0] golden_psub(input [WIDTH-1:0] x);
        logic [LANE_W-1:0] x0, x1, x2, x3, x4;
        logic [LANE_W-1:0] y0, y1, y2, y3, y4;
        logic [4:0] sin, sout;
        begin
            x0 = x[  LANE_W-1 :          0];
            x1 = x[2*LANE_W-1 :   LANE_W];
            x2 = x[3*LANE_W-1 : 2*LANE_W];
            x3 = x[4*LANE_W-1 : 3*LANE_W];
            x4 = x[5*LANE_W-1 : 4*LANE_W];

            for (int i = 0; i < LANE_W; i++) begin
                sin  = {x0[i], x1[i], x2[i], x3[i], x4[i]};
                sout = golden_sbox(sin);
                y0[i] = sout[4];
                y1[i] = sout[3];
                y2[i] = sout[2];
                y3[i] = sout[1];
                y4[i] = sout[0];
            end

            golden_psub = {y4, y3, y2, y1, y0};
        end
    endfunction

    // ---------------------------------------------------------------
    // Check task
    // ---------------------------------------------------------------
    task automatic check(input string name);
        logic [WIDTH-1:0] expected;
        begin
            expected = golden_psub(x_in);
            #1; // let combinational logic settle
            checks++;
            if (x_out !== expected) begin
                errors++;
                $display("FAIL [%s] x_in=%h", name, x_in);
                $display("      got      =%h", x_out);
                $display("      expected =%h", expected);
            end else begin
                $display("PASS [%s]", name);
            end
        end
    endtask

    // ---------------------------------------------------------------
    // Stimulus
    // ---------------------------------------------------------------
    initial begin
        // Directed cases
        x_in = '0;                         check("all_zero");
        x_in = '1;                         check("all_one");
        x_in = {WIDTH{1'b0}} | 64'h1;       check("single_bit_lane0_bit0");
        x_in[WIDTH-1] = 1'b1;               check("single_bit_lane4_bit63");

        // one lane all-ones, rest zero, for each of the 5 lanes
        for (int lane = 0; lane < 5; lane++) begin
            x_in = '0;
            x_in[(lane+1)*LANE_W-1 -: LANE_W] = {LANE_W{1'b1}};
            check($sformatf("lane%0d_all_ones", lane));
        end

        // alternating pattern
        x_in = {WIDTH{1'b0}};
        for (int b = 0; b < WIDTH; b += 2) x_in[b] = 1'b1;
        check("alternating_0101");

        // walking 1 across the full 320-bit vector
        for (int b = 0; b < WIDTH; b++) begin
            x_in = '0;
            x_in[b] = 1'b1;
            check($sformatf("walking_one_bit%0d", b));
        end

        // randomized vectors
        for (int t = 0; t < 200; t++) begin
            x_in = {$urandom(), $urandom(), $urandom(), $urandom(),
                    $urandom(), $urandom(), $urandom(), $urandom(),
                    $urandom(), $urandom()};
            check($sformatf("random_%0d", t));
        end

        $display("--------------------------------------------------");
        $display("Total checks: %0d   Errors: %0d", checks, errors);
        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TEST(S) FAILED ***", errors);
        $display("--------------------------------------------------");

        $finish;
    end

endmodule