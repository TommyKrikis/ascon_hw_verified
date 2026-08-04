`timescale 1ns/1ps

// Multi-block PT testbench for ascon_aead.
//   key = nonce = 000102030405060708090A0B0C0D0E0F
//   PT  = 20 bytes 000102...13  -> 2 blocks (one full + one 4-byte partial)
//   TEST_D = 0 : empty AD
//   TEST_D = 1 : one AD block
// Expected values generated from the Python reference (pyascon).
module ascon_aead_multi_tb;

    logic         clk, rst_n, start;
    logic [127:0] key, nonce;
    logic [127:0] pt_block, ad_block;
    logic [7:0]   pt_blocks, pt_idx;
    logic [7:0]   ad_blocks, ad_idx;
    logic [3:0]   pt_len;
    logic         busy, done, ct_valid;
    logic [127:0] ct_block, tag;

    int errors = 0;

    ascon_aead dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .key(key), .nonce(nonce),
        .pt_block(pt_block), .pt_blocks(pt_blocks), .pt_idx(pt_idx), .pt_len(pt_len),
        .ad_block(ad_block), .ad_blocks(ad_blocks), .ad_idx(ad_idx),
        .busy(busy), .done(done),
        .ct_block(ct_block), .ct_valid(ct_valid), .tag(tag)
    );

    // ---- block "memories": the DUT asks by index, we answer ----
    logic [127:0] pt_mem [0:3];
    logic [127:0] ad_mem [0:3];
    assign pt_block = pt_mem[pt_idx];
    assign ad_block = ad_mem[ad_idx];

    // clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // watchdog
    initial begin
        #200000;
        $display("*** TIMEOUT: done never asserted ***");
        $finish;
    end

    // ------------------------------------------------------------------
    // CIPHERTEXT MONITOR
    // ct_block is overwritten once per block, so we must grab each one as
    // it appears. ct_valid pulses high for exactly one cycle each time
    // ct_block holds a fresh block -- so we sample on that pulse.
    // ------------------------------------------------------------------
    logic [127:0] ct_cap [0:3];
    int ct_n = 0;

    always @(posedge clk) begin
        if (rst_n && ct_valid) begin
            ct_cap[ct_n] = ct_block;      // blocking: this is a monitor, not RTL
            $display("  [monitor] captured ct[%0d] = %032h", ct_n, ct_block);
            ct_n = ct_n + 1;
        end
    end

    // ------------------------------------------------------------------
    // Test selection + expected values
    // ------------------------------------------------------------------
    localparam bit TEST_D = 1'b1;   // 0 = empty AD, 1 = one AD block

    localparam logic [127:0] EXP_CT0 = TEST_D
        ? 128'hb06519b744f7308bb051a21773603eb0
        : 128'he37452ce8ea4d07cee4aa4d289d270e7;
    localparam logic [127:0] EXP_CT1 = TEST_D
        ? 128'h000000000000000000000000357abef1
        : 128'h000000000000000000000000e1d7ba81;
    localparam logic [127:0] EXP_TAG = TEST_D
        ? 128'h01a0edbc17fe50b2ebdad779e67d51e0
        : 128'ha688fdb6d0646a3987938a60b60d41eb;

    logic [127:0] ct_mask;

    initial begin
        // ---- init every input, then reset ----
        start = 1'b0; key = '0; nonce = '0;
        pt_blocks = 8'd0; ad_blocks = 8'd0; pt_len = '0;
        for (int i = 0; i < 4; i++) begin
            pt_mem[i] = '0;
            ad_mem[i] = '0;
        end
        rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // ---- plaintext: 20 bytes -> 2 blocks, last one has 4 real bytes ----
        pt_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;  // bytes 00..0F
        pt_mem[1] = 128'h00000000000000000000000013121110;  // bytes 10..13
        pt_blocks = 8'd2;
        pt_len    = 4'd4;        // real bytes in the FINAL block

        // ---- associated data ----
        if (TEST_D) begin
            ad_mem[0] = 128'h010e0d0c0b0a09080706050403020100;  // 15 bytes + 0x01 pad
            ad_blocks = 8'd1;
        end else begin
            ad_blocks = 8'd0;
        end

        key   = 128'h0f0e0d0c0b0a09080706050403020100;
        nonce = 128'h0f0e0d0c0b0a09080706050403020100;

        // ---- start pulse ----
        @(negedge clk); start = 1'b1;
        @(negedge clk); start = 1'b0;

        wait (done == 1'b1);
        @(negedge clk);          // let the monitor catch the final pulse

        // ---- checks ----
        ct_mask = ({128{1'b1}} >> (128 - pt_len*8));   // mask for the partial block

        $display("---- ascon_aead multi-block PT (AD blocks = %0d) ----", ad_blocks);
        $display("blocks captured = %0d (expected %0d)", ct_n, pt_blocks);
        $display("tag = %032h", tag);

        if (ct_n !== pt_blocks) begin
            errors++;
            $display("FAIL block count: got %0d exp %0d", ct_n, pt_blocks);
        end else $display("PASS block count");

        // first block is a FULL 128-bit block -> compare all of it
        if (ct_cap[0] !== EXP_CT0) begin
            errors++;
            $display("FAIL ct[0]: got %032h exp %032h", ct_cap[0], EXP_CT0);
        end else $display("PASS ct[0]");

        // last block is partial -> only the low pt_len bytes are real
        if ((ct_cap[1] & ct_mask) !== (EXP_CT1 & ct_mask)) begin
            errors++;
            $display("FAIL ct[1]: got %032h exp %032h (masked)",
                     ct_cap[1] & ct_mask, EXP_CT1 & ct_mask);
        end else $display("PASS ct[1]");

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
