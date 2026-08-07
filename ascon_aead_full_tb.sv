
`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// Regression testbench for ascon_aead: runs EVERY vector in one simulation.
//
// key = nonce = 000102030405060708090A0B0C0D0E0F for all cases.
// Golden ciphertext/tag values generated from the Python reference (pyascon).
//
// To add a case: fill the vector arrays, then call run_case("name").
// ---------------------------------------------------------------------------
module ascon_aead_full_tb;

    logic         clk, rst_n, start;
    logic [127:0] key, nonce;
    logic [127:0] data_in_block, data_out_block, ad_block;
    logic [7:0]   data_in_blocks, data_in_idx;
    logic [7:0]   ad_blocks, ad_idx;
    logic [3:0]   data_len;
    logic         busy, done , tag_ok,decr_en;
    logic [127:0] tag, tag_in;
    logic data_out_valid;

    int errors = 0;
    int cases  = 0;

    //for encryption, decr_en = 0; for decryption, decr_en = 1
    ascon_aead dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .key(key), .nonce(nonce),
        .data_in(data_in_block), .data_blocks(data_in_blocks), .data_idx(data_in_idx), .data_len(data_len),
        .ad_block(ad_block), .ad_blocks(ad_blocks), .ad_idx(ad_idx),
        .busy(busy), .done(done), .tag_ok(tag_ok), .decr_en(decr_en),
        .data_out_block(data_out_block), .data_out_valid(data_out_valid), .tag(tag) , .tag_in(tag_in)
    );

    // ---- block memories: the DUT asks by index, we answer ----
    logic [127:0] pt_mem [0:3];
    logic [127:0] ad_mem [0:3];
    logic [127:0] ct_mem [0:3];
    assign data_in_block = decr_en ? ct_mem[data_in_idx] : pt_mem[data_in_idx];
    assign ad_block = ad_mem[ad_idx];

    // ---- expected values for the case currently running ----
    logic [127:0] exp_ct  [0:3];
    logic [127:0] exp_tag;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        #500000;
        $display("*** TIMEOUT ***");
        $finish;
    end

    // ---- ciphertext monitor: grab each block as ct_valid pulses ----
    logic [127:0] data_out_cap [0:3];
    int data_out_n = 0;

    always @(posedge clk) begin
        if (rst_n && data_out_valid) begin
            data_out_cap[data_out_n] = data_out_block;
            if (!decr_en) ct_mem[data_out_n] = data_out_block;
            data_out_n = data_out_n + 1;
        end
    end

    // -----------------------------------------------------------------
    // Clear all vector state so a stale value from the previous case
    // can never leak into the next one.
    // -----------------------------------------------------------------
    task automatic clear_vectors();
        begin
            for (int i = 0; i < 4; i++) begin
                pt_mem[i] = '0;
                ad_mem[i] = '0;
                exp_ct[i] = '0;
            end
            exp_tag   = '0;
            data_in_blocks = 8'd0;
            ad_blocks = 8'd0;
            data_len    = 4'd0;
        end
    endtask

    // -----------------------------------------------------------------
    // Run one encryption and check ciphertext blocks + tag.
    // Reads the module-level vector arrays set up by the caller.
    // -----------------------------------------------------------------
    task automatic run_case(input string name);
        logic [127:0] mask;
        begin
            cases++;
            data_out_n = 0;                       // reset the monitor for this case
            decr_en = 1'b0;                         // encryption
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;

            wait (done == 1'b1);
            @(negedge clk);                 // let the monitor see the last pulse

            // --- how many blocks came out? ---
            if (data_out_n !== data_in_blocks) begin
                errors++;
                $display("FAIL [%s] block count: got %0d exp %0d", name, data_out_n, data_in_blocks);
            end

            // --- full blocks: compare all 128 bits ---
            for (int i = 0; i < data_in_blocks- 1; i++) begin
                if (data_out_cap[i] !== exp_ct[i]) begin
                    errors++;
                    $display("FAIL [%s] ct[%0d]: got %032h exp %032h",
                             name, i, data_out_cap[i], exp_ct[i]);
                end
            end

            // --- last block is partial: only the low data_len bytes count.
            //     data_len == 0 -> mask is 0 -> nothing to compare (correct:
            //     a pure-padding block contributes no ciphertext).
            mask = (data_len == 0) ? 128'h0 : ({128{1'b1}} >> (128 - data_len*8));
            if ((data_out_cap[data_in_blocks-1] & mask) !== (exp_ct[data_in_blocks-1] & mask)) begin
                errors++;
                $display("FAIL [%s] ct[%0d] (last, masked): got %032h exp %032h",
                         name, data_in_blocks-1,
                         data_out_cap[data_in_blocks-1] & mask, exp_ct[data_in_blocks-1] & mask);
            end

            // --- tag ---
            if (tag !== exp_tag) begin
                errors++;
                $display("FAIL [%s] tag: got %032h exp %032h", name, tag, exp_tag);
            end else begin
                $display("PASS [%s]  (AD blk=%0d, PT blk=%0d, data_len=%0d)",
                         name, ad_blocks, data_in_blocks, data_len);
            end

            @(negedge clk);
            
            tag_in = tag;          // the tag encryption just produced
            data_out_n = 0;        // reset the monitor for the decrypt run
            decr_en = 1'b1;
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;

            wait (done == 1'b1);
            @(negedge clk);    

            for (int i = 0; i < data_in_blocks- 1; i++) begin
                if (data_out_cap[i] !== pt_mem[i]) begin
                    errors++;
                    $display("FAIL in Plaintext [%s] ct[%0d]: got %032h exp %032h",
                             name, i, data_out_cap[i], pt_mem[i]);
                end
            end

            mask = (data_len == 0) ? 128'h0 : ({128{1'b1}} >> (128 - data_len*8));
            if ((data_out_cap[data_in_blocks-1] & mask) !== (pt_mem[data_in_blocks-1] & mask)) begin
                errors++;
                $display("FAIL [%s] ct[%0d] (last, masked): got %032h exp %032h",
                         name, data_in_blocks-1,
                         data_out_cap[data_in_blocks-1] & mask, pt_mem[data_in_blocks-1] & mask);
            end

            // --- tag ---
            if (tag_ok !== 1'b1) begin
                errors++;
                $display("FAIL [%s] tag: got %032h exp %032h", name, tag, exp_tag);
            end else begin
                $display("DECRYPT PASS [%s]  (AD blk=%0d, PT blk=%0d, data_len=%0d)",
                         name, ad_blocks, data_in_blocks, data_len);
            end

            // -------------------------------------------------------------
            // NEGATIVE TEST: corrupt the tag and decrypt the SAME ciphertext
            // again. The core must reject it (tag_ok == 0). Without this, a
            // DUT that hardwired tag_ok = 1 would pass every check above.
            // -------------------------------------------------------------
            @(negedge clk);
            tag_in     = tag_in ^ 128'h1;   // flip a single bit of the tag
            data_out_n = 0;
            decr_en    = 1'b1;

            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;

            wait (done == 1'b1);
            @(negedge clk);

            if (tag_ok !== 1'b0) begin
                errors++;
                $display("FAIL [%s] BAD TAG ACCEPTED (tag_ok=%b) -- authentication is broken!",
                         name, tag_ok);
            end else begin
                $display("REJECT PASS [%s]  (corrupted tag correctly rejected)", name);
            end

            tag_in = tag_in ^ 128'h1;       // restore, so nothing leaks to the next case
            @(negedge clk);
        end
    endtask

    // -----------------------------------------------------------------
    // Test sequence
    // -----------------------------------------------------------------
    initial begin
        start = 1'b0; key = '0; nonce = '0;
        clear_vectors();
        rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        key   = 128'h0f0e0d0c0b0a09080706050403020100;
        nonce = 128'h0f0e0d0c0b0a09080706050403020100;

        // ---- E1: empty AD, EMPTY PT (one pure-padding block) ----
        clear_vectors();
        pt_mem[0] = 128'h00000000000000000000000000000000;
        exp_ct[0] = 128'h00000000000000000000000000000000;
        exp_tag   = 128'hb09b83f0605944fc51141e8e4bd62744;
        ad_blocks = 8'd0; data_in_blocks= 8'd1; data_len = 4'd0;
        run_case("E1 emptyAD emptyPT");

        // ---- E2: empty AD, 4-byte PT ----
        clear_vectors();
        pt_mem[0] = 128'h00000000000000000000000003020100;
        exp_ct[0] = 128'h00000000000000000000000089d270e7;
        exp_tag   = 128'h0f5d3020158d48eb368ce50174bd3d72;
        ad_blocks = 8'd0; data_in_blocks= 8'd1; data_len = 4'd4;
        run_case("E2 emptyAD 4B-PT");

        // ---- E3: empty AD, EXACTLY 16-byte PT -> 2nd block is all padding ----
        clear_vectors();
        pt_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
        pt_mem[1] = 128'h00000000000000000000000000000000;
        exp_ct[0] = 128'he37452ce8ea4d07cee4aa4d289d270e7;
        exp_ct[1] = 128'h00000000000000000000000000000000;
        exp_tag   = 128'h1184a7f5725974f256e5c48f9a1f72ea;
        ad_blocks = 8'd0; data_in_blocks= 8'd2; data_len = 4'd0;
        run_case("E3 emptyAD 16B-PT exact");

        // ---- E4: empty AD, 20-byte PT (2 blocks) ----
        clear_vectors();
        pt_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
        pt_mem[1] = 128'h00000000000000000000000013121110;
        exp_ct[0] = 128'he37452ce8ea4d07cee4aa4d289d270e7;
        exp_ct[1] = 128'h000000000000000000000000e1d7ba81;
        exp_tag   = 128'ha688fdb6d0646a3987938a60b60d41eb;
        ad_blocks = 8'd0; data_in_blocks= 8'd2; data_len = 4'd4;
        run_case("E4 emptyAD 20B-PT");

        // ---- E5: empty AD, 40-byte PT (3 blocks) ----
        clear_vectors();
        pt_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
        pt_mem[1] = 128'h1f1e1d1c1b1a19181716151413121110;
        pt_mem[2] = 128'h00000000000000002726252423222120;
        exp_ct[0] = 128'he37452ce8ea4d07cee4aa4d289d270e7;
        exp_ct[1] = 128'hb1beeb0d6173780f97c4dc63e1d7ba81;
        exp_ct[2] = 128'h000000000000000067636ad1898197c7;
        exp_tag   = 128'hdb7a1b59144db8b61000518a68ca33d8;
        ad_blocks = 8'd0; data_in_blocks= 8'd3; data_len = 4'd8;
        run_case("E5 emptyAD 40B-PT 3blk");

        // ---- E6: 1 AD block, 20-byte PT ----
        clear_vectors();
        ad_mem[0] = 128'h010e0d0c0b0a09080706050403020100;
        pt_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
        pt_mem[1] = 128'h00000000000000000000000013121110;
        exp_ct[0] = 128'hb06519b744f7308bb051a21773603eb0;
        exp_ct[1] = 128'h000000000000000000000000357abef1;
        exp_tag   = 128'h01a0edbc17fe50b2ebdad779e67d51e0;
        ad_blocks = 8'd1; data_in_blocks= 8'd2; data_len = 4'd4;
        run_case("E6 1AD-blk 20B-PT");

        // ---- E7: 2 AD blocks (16B AD -> extra padding block), 20-byte PT ----
        clear_vectors();
        ad_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
        ad_mem[1] = 128'h00000000000000000000000000000001;
        pt_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
        pt_mem[1] = 128'h00000000000000000000000013121110;
        exp_ct[0] = 128'h997f188b319520e4fa23604a5e21286a;
        exp_ct[1] = 128'h00000000000000000000000006236dc5;
        exp_tag   = 128'he587c69503d4e53d930ae41b74af2896;
        ad_blocks = 8'd2; data_in_blocks= 8'd2; data_len = 4'd4;
        run_case("E7 2AD-blk 20B-PT");

        // ---- E8: 3 AD blocks, 33-byte PT (3 blocks, 1-byte last) ----
        clear_vectors();
        ad_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
        ad_mem[1] = 128'h1f1e1d1c1b1a19181716151413121110;
        ad_mem[2] = 128'h00000000000000000000000001222120;
        pt_mem[0] = 128'h0f0e0d0c0b0a09080706050403020100;
        pt_mem[1] = 128'h1f1e1d1c1b1a19181716151413121110;
        pt_mem[2] = 128'h00000000000000000000000000000020;
        exp_ct[0] = 128'h3f1024fc08d5c59d4c0de08afc0f537b;
        exp_ct[1] = 128'h8ec2db1b2bcf60fd29b33b0d15bf9a47;
        exp_ct[2] = 128'h00000000000000000000000000000004;
        exp_tag   = 128'h71de5bb91a79b2ca4ef898437722d61a;
        ad_blocks = 8'd3; data_in_blocks= 8'd3; data_len = 4'd1;
        run_case("E8 3AD-blk 33B-PT 3blk");

        // ---- summary ----
        $display("--------------------------------------------------");
        $display("Cases run: %0d   Errors: %0d", cases, errors);
        if (errors == 0) $display("*** ALL TESTS PASSED ***");
        else             $display("*** %0d CHECK(S) FAILED ***", errors);
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
