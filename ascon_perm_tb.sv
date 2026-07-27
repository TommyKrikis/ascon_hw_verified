`timescale 1ns/1ps   // time unit / precision -- always include it

// A testbench is the TOP module: it has NO ports. Everything below is
// an internal 'logic' signal we either drive (DUT inputs) or read (DUT
// outputs). This is the key difference from a normal module.
module ascon_perm_tb;

    // -----------------------------------------------------------------
    // 1) Internal signals -- one per DUT port. NOT input/output here!
    // -----------------------------------------------------------------
    logic         clk;
    logic         rst_n;
    logic         start;
    logic [3:0]   num_rounds;
    logic [3:0]   round_idx_start;
    logic         a_b;             // DUT has this port; tie to 0 (unused)
    logic         busy;
    logic         done;
    logic [319:0] state_in;
    logic [319:0] state_out;

    int errors = 0;
    int checks = 0;

    // -----------------------------------------------------------------
    // 2) Instantiate the Device Under Test, wiring our signals to it.
    //    .port_name(our_signal)
    // -----------------------------------------------------------------
    ascon_perm dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .num_rounds      (num_rounds),
        .round_idx_start (round_idx_start),
        .busy            (busy),
        .done            (done),
        .state_in        (state_in),
        .state_out       (state_out)
    );

    // -----------------------------------------------------------------
    // 3) Clock: free-running, 10 ns period (flips every 5 ns, forever).
    // -----------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------
    // 4) Watchdog: if 'done' never comes (stuck FSM), stop the sim
    //    instead of hanging forever.
    // -----------------------------------------------------------------
    initial begin
        #100000;
        $display("*** TIMEOUT: done never asserted -- FSM stuck? ***");
        $finish;
    end

    // -----------------------------------------------------------------
    // 5) Reusable "run one permutation and check it" task.
    //    'automatic' = each call gets its own copies of the arguments.
    // -----------------------------------------------------------------
    task automatic run_perm(input logic [3:0]   nr,        // num_rounds
                            input logic [3:0]   ris,       // round_idx_start
                            input logic [319:0] din,       // state_in
                            input logic [319:0] expected,  // golden output
                            input string        name);
        begin
            // Drive inputs on a falling edge, so they're stable before
            // the rising edge the DUT samples them on.
            @(negedge clk);
            num_rounds      = nr;
            round_idx_start = ris;
            state_in        = din;
            start           = 1'b1;     // request a run

            @(negedge clk);
            start           = 1'b0;     // 'start' was high across exactly
                                        // one rising edge -> a 1-cycle pulse

            wait (done == 1'b1);        // block until the DUT finishes

            // 'done' and 'state_out' update on the same edge, so read now.
            checks++;
            if (state_out === expected) begin   // === so an X FAILS, not matches
                $display("PASS [%s]", name);
            end else begin
                errors++;
                $display("FAIL [%s]", name);
                $display("      got      = %h", state_out);
                $display("      expected = %h", expected);
            end

            @(negedge clk);             // let 'done' drop / FSM return to IDLE
        end
    endtask

    // -----------------------------------------------------------------
    // 6) Test sequence.
    // -----------------------------------------------------------------
    initial begin
        // ---- safe initial values + reset ----
        start           = 1'b0;
        a_b             = 1'b0;
        num_rounds      = 4'd0;
        round_idx_start = 4'd0;
        state_in        = '0;
        rst_n           = 1'b0;              // assert active-low reset
        repeat (3) @(negedge clk);
        rst_n           = 1'b1;              // release reset
        @(negedge clk);

        // ---- directed golden vectors (input = all zeros) ----
        // Golden outputs come from the Python reference ascon_permutation().
        run_perm(4'd12, 4'd0, 320'h0,
            320'h045d648e4def12c93fe53f36f2c1178c6937f83e03d11a509b9bfb8513b560f778ea7ae5cfebb108,
            "p12_zero");

        run_perm(4'd8,  4'd4, 320'h0,
            320'h0168260badf76a06f01fdabf8c8a82b4a01ef761bf8e1652a5425f1f8cb313881418f8af721aa830,
            "p8_zero");

        run_perm(4'd6,  4'd6, 320'h0,
            320'h649af379ba83cd302b23481598ffa8eae0377d04e23a914b21495b1b0ae33eef160c84f20faad4f1,
            "p6_zero");

        // ---- summary (same style as tb_p_sub) ----
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
