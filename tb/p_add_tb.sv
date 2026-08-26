
`timescale 1ns/1ps   // this line just sets the time units for simulation, always include it

module p_add_tb;

    // These are the "wires" we'll use to talk to the module we're testing.
    // They must match the module's ports exactly (same width, same names optional).
    logic [63:0] x2_in;    // input we control
    logic [3:0]  round_i;  // input we control
    logic [63:0] x2_out;   // output we read back

    // This creates one instance of your module, and connects our wires to its ports.
    // Think of this like: dut = p_add_const(x2_in, round_i, x2_out)
    p_add_const #(.WIDTH(64)) dut (
        .x2_in   (x2_in),
        .round_i (round_i),
        .x2_out  (x2_out)
    );

    // 'initial' just means "run this once, at the start of simulation"
    initial begin

        // ---- TEST 1 ----
        x2_in   = 64'h0000000000000000;  // input = all zeros
        round_i = 4'd0;                   // round 0

        #10;  // wait 10 time units, so the logic has time to produce x2_out

        // Print out what happened, so we can look at it with our own eyes
        $display("Test 1: x2_in=%h round=%0d -> x2_out=%h", x2_in, round_i, x2_out);
        // We know round 0's constant is 0xf0, so x2_out should be 0x00000000000000f0
        // (0 XOR 0xf0 = 0xf0)

        // ---- TEST 2 ----
        x2_in   = 64'hFFFFFFFFFFFFFFFF;  // input = all ones
        round_i = 4'd0;

        #10;

        $display("Test 2: x2_in=%h round=%0d -> x2_out=%h", x2_in, round_i, x2_out);
        // XOR with all-ones just flips every bit of the constant, so we expect
        // x2_out = 0xFFFFFFFFFFFFFF0F  (0xf0 flipped)

        // ---- TEST 3 ----
        x2_in   = 64'h0000000000000000;
        round_i = 4'd11;  // last round

        #10;

        $display("Test 3: x2_in=%h round=%0d -> x2_out=%h", x2_in, round_i, x2_out);
        // Round 11's constant is 0x4b, so we expect x2_out = 0x000000000000004b

        $finish;  // stop the simulation
    end

endmodule