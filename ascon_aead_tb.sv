`timescale 1ns/1ps

// Testbench for ascon_aead against reference vectors:
//   key = nonce = 000102030405060708090A0B0C0D0E0F
//   PT  = 00010203  (4 bytes)
//   AD  = 15 bytes 000102...0E -> ONE padded block  (see AD_TEST_B to switch)
// Expected values generated from the Python reference (pyascon).
module ascon_aead_tb;

    logic         clk, rst_n, start;
    logic [127:0] key, nonce, pt_block;
    logic [3:0]   pt_len;
    logic         busy, done;
    logic [127:0] ct_block, tag;
    logic [7:0]   ad_blocks, ad_idx;
    logic [127:0] ad_block;

    int errors = 0;

    ascon_aead dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .key(key), .nonce(nonce), .pt_block(pt_block), .pt_len(pt_len),
        .busy(busy), .done(done), .ad_block(ad_block), .ad_blocks(ad_blocks), .ad_idx(ad_idx),
        .ct_block(ct_block), .tag(tag)
    );
    logic [127:0] ad_mem [0:3];          // small array of AD blocks
    assign ad_block = ad_mem[ad_idx];    // DUT asks by index, TB supplies  
    
    // clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // watchdog
    initial begin
        #100000;
        $display("*** TIMEOUT: done never asserted ***");
        $finish;
    end

    // ------------------------------------------------------------------
    // Set AD_TEST_B = 0 for test A (1 AD block), 1 for test B (2 AD blocks).
    // Test B is the one that exercises the AD loop-back.
    // ------------------------------------------------------------------
    localparam bit AD_TEST_B = 1'b1;

    // Expected results (from the Python reference, byte-low convention)
    localparam logic [127:0] EXP_CT = AD_TEST_B
        ? 128'h0000000000000000000000005e21286a   // test B: ct bytes 6A 28 21 5E
        : 128'h00000000000000000000000073603eb0;  // test A: ct bytes B0 3E 60 73
    localparam logic [127:0] EXP_TAG = AD_TEST_B
        ? 128'he7dca4cd012123cab217d3710fc619e2   // test B
        : 128'hae28dc20451e6a20404b58bc5a847d92;  // test A

    logic [127:0] ct_mask;

    initial begin
        // init + reset
        start=1'b0; key='0; nonce='0; pt_block='0; pt_len='0;
        ad_blocks = 8'd0;
        for (int i = 0; i < 4; i++) ad_mem[i] = '0;   // no X anywhere
        rst_n=1'b0;
        repeat (3) @(negedge clk);
        rst_n=1'b1;
        @(negedge clk);

        // ---- AD blocks (already padded by the TB; the DUT does not pad AD) ----
        if (AD_TEST_B) begin
            // 16-byte AD -> 2 blocks, the second is a pure padding block
            ad_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
            ad_mem[1] = 128'h00000000000000000000000000000001;
            ad_blocks = 8'd2;
        end else begin
            // 15-byte AD -> 1 padded block (0x01 marker in the top byte)
            ad_mem[0] = 128'h010e0d0c0b0a09080706050403020100;
            ad_blocks = 8'd1;
        end

        // drive the KAT inputs (byte j of each field sits in bits [8j+7:8j])
        key      = 128'h0f0e0d0c0b0a09080706050403020100;
        nonce    = 128'h0f0e0d0c0b0a09080706050403020100;
        pt_block = 128'h00000000000000000000000003020100; // bytes 00 01 02 03
        pt_len   = 4'd4;

        // start pulse
        @(negedge clk); start = 1'b1;
        @(negedge clk); start = 1'b0;

        // wait for completion
        wait (done == 1'b1);

        // ciphertext length == plaintext length, so mask off the low pt_len bytes
        ct_mask = ({128{1'b1}} >> (128 - pt_len*8));

        $display("---- ascon_aead KAT (AD blocks = %0d) ----", ad_blocks);
        $display("ct_block = %032h  (len=%0d)", ct_block, pt_len);
        $display("tag      = %032h", tag);

        if ((ct_block & ct_mask) !== (EXP_CT & ct_mask)) begin
            errors++;
            $display("FAIL ct: got %032h exp %032h (masked)",
                     ct_block & ct_mask, EXP_CT & ct_mask);
        end else $display("PASS ct");

        if (tag !== EXP_TAG) begin
            errors++;
            $display("FAIL tag: got %032h exp %032h", tag, EXP_TAG);
        end else $display("PASS tag");

        $display("--------------------------------------------------");
        if (errors == 0) $display("*** ALL TESTS PASSED ***");
        else             $display("*** %0d TEST(S) FAILED ***", errors);
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
