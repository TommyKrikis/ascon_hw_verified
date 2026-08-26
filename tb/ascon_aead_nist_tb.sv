`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// Full NIST KAT sweep for ascon_aead.
//
// Runs all 1089 reference vectors (PT 0..32 bytes x AD 0..32 bytes), each in
// three passes:
//   1. encrypt          -> ciphertext blocks + tag vs the reference
//   2. decrypt          -> recovered plaintext vs the original, tag_ok == 1
//   3. decrypt bad tag  -> one bit flipped in tag_in, tag_ok must be 0
//
// Vectors come from gen_kat_hex.py (run it first). $readmemh resolves paths
// relative to the directory you launch vsim from -- run from ascon_hw_verified/.
// ---------------------------------------------------------------------------
module ascon_aead_nist_tb;

    localparam int NVEC      = 1089;   // vectors in the KAT file
    localparam int MAXBLK    = 3;      // blocks per field (32 bytes -> 2 + 1 pad)
    localparam int MAX_ERR   = 20;     // bail out after this many failures
    localparam int PROGRESS  = 100;    // print a heartbeat every N vectors

    localparam logic [127:0] KAT_KEY   = 128'h0f0e0d0c0b0a09080706050403020100;
    localparam logic [127:0] KAT_NONCE = 128'h0f0e0d0c0b0a09080706050403020100;

    // ---- DUT signals ----
    logic         clk, rst_n, start;
    logic [127:0] key, nonce;
    logic [127:0] data_in_block, data_out_block, ad_block;
    logic [7:0]   data_in_blocks, data_in_idx;
    logic [7:0]   ad_blocks, ad_idx;
    logic [3:0]   data_len, ad_len;
    logic         busy, done, tag_ok, decr_en;
    logic [127:0] tag, tag_in;
    logic         data_out_valid;

    int errors = 0;
    int cases  = 0;

    ascon_aead dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .key(key), .nonce(nonce),
        .data_in(data_in_block), .data_blocks(data_in_blocks),
        .data_idx(data_in_idx), .data_len(data_len),
        .ad_block(ad_block), .ad_blocks(ad_blocks), .ad_idx(ad_idx), .ad_len(ad_len),
        .busy(busy), .done(done), .tag_ok(tag_ok), .decr_en(decr_en),
        .data_out_block(data_out_block), .data_out_valid(data_out_valid),
        .tag(tag), .tag_in(tag_in)
    );

    // ---- block memories: the DUT asks by index, we answer ----
    logic [127:0] pt_mem [0:MAXBLK-1];
    logic [127:0] ad_mem [0:MAXBLK-1];
    logic [127:0] ct_mem [0:MAXBLK-1];
    assign data_in_block = decr_en ? ct_mem[data_in_idx] : pt_mem[data_in_idx];
    assign ad_block      = ad_mem[ad_idx];

    logic [127:0] exp_ct [0:MAXBLK-1];
    logic [127:0] exp_tag;

    // ---- the KAT vector database, loaded from disk at time 0 ----
    logic [31:0]  kat_meta [0:NVEC-1];
    logic [127:0] kat_ad   [0:MAXBLK*NVEC-1];
    logic [127:0] kat_pt   [0:MAXBLK*NVEC-1];
    logic [127:0] kat_ct   [0:MAXBLK*NVEC-1];
    logic [127:0] kat_tag  [0:NVEC-1];

    initial begin
        $readmemh("kat_meta.hex", kat_meta);
        $readmemh("kat_ad.hex",   kat_ad);
        $readmemh("kat_pt.hex",   kat_pt);
        $readmemh("kat_ct.hex",   kat_ct);
        $readmemh("kat_tag.hex",  kat_tag);
    end

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ~4 ms of real work; leave generous headroom
    initial begin
        #100_000_000;
        $display("*** TIMEOUT -- FSM stuck? ***");
        $finish;
    end

    // ---- output monitor: capture each block as data_out_valid pulses ----
    logic [127:0] data_out_cap [0:MAXBLK-1];
    int data_out_n = 0;

    always @(posedge clk) begin
        if (rst_n && data_out_valid) begin
            if (data_out_n < MAXBLK) begin
                data_out_cap[data_out_n] = data_out_block;
                // Only capture ciphertext while ENCRYPTING -- during the
                // decrypt pass ct_mem is the DUT's input and must not change.
                if (!decr_en) ct_mem[data_out_n] = data_out_block;
            end
            data_out_n = data_out_n + 1;
        end
    end

    task automatic clear_vectors();
        begin
            for (int i = 0; i < MAXBLK; i++) begin
                pt_mem[i] = '0;
                ad_mem[i] = '0;
                ct_mem[i] = '0;
                exp_ct[i] = '0;
            end
            exp_tag        = '0;
            data_in_blocks = 8'd0;
            ad_blocks      = 8'd0;
            data_len       = 4'd0;
            ad_len         = 4'd0;
        end
    endtask

    // one start pulse, then wait for the core to finish
    task automatic run_once();
        begin
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
            wait (done == 1'b1);
            @(negedge clk);      // let the monitor see the final pulse
        end
    endtask

    // -----------------------------------------------------------------
    // Three passes over one vector. Silent unless something fails.
    // -----------------------------------------------------------------
    task automatic run_case(input int v);
        logic [127:0] mask;
        begin
            cases++;
            mask = (data_len == 0) ? 128'h0
                                   : ({128{1'b1}} >> (128 - data_len*8));

            // ---------- pass 1: encrypt ----------
            data_out_n = 0;
            decr_en    = 1'b0;
            run_once();

            if (data_out_n !== data_in_blocks) begin
                errors++;
                $display("FAIL v%0d enc block count: got %0d exp %0d",
                         v, data_out_n, data_in_blocks);
            end
            for (int i = 0; i < data_in_blocks - 1; i++)
                if (data_out_cap[i] !== exp_ct[i]) begin
                    errors++;
                    $display("FAIL v%0d ct[%0d]: got %032h exp %032h",
                             v, i, data_out_cap[i], exp_ct[i]);
                end
            if ((data_out_cap[data_in_blocks-1] & mask) !== (exp_ct[data_in_blocks-1] & mask)) begin
                errors++;
                $display("FAIL v%0d ct[%0d] last: got %032h exp %032h",
                         v, data_in_blocks-1,
                         data_out_cap[data_in_blocks-1] & mask,
                         exp_ct[data_in_blocks-1] & mask);
            end
            if (tag !== exp_tag) begin
                errors++;
                $display("FAIL v%0d tag: got %032h exp %032h", v, tag, exp_tag);
            end

            // ---------- pass 2: decrypt ----------
            tag_in     = tag;          // the tag encryption just produced
            data_out_n = 0;
            decr_en    = 1'b1;
            run_once();

            for (int i = 0; i < data_in_blocks - 1; i++)
                if (data_out_cap[i] !== pt_mem[i]) begin
                    errors++;
                    $display("FAIL v%0d pt[%0d]: got %032h exp %032h",
                             v, i, data_out_cap[i], pt_mem[i]);
                end
            if ((data_out_cap[data_in_blocks-1] & mask) !== (pt_mem[data_in_blocks-1] & mask)) begin
                errors++;
                $display("FAIL v%0d pt[%0d] last: got %032h exp %032h",
                         v, data_in_blocks-1,
                         data_out_cap[data_in_blocks-1] & mask,
                         pt_mem[data_in_blocks-1] & mask);
            end
            if (tag_ok !== 1'b1) begin
                errors++;
                $display("FAIL v%0d good tag REJECTED (tag_ok=%b)", v, tag_ok);
            end

            // ---------- pass 3: decrypt with a corrupted tag ----------
            tag_in     = tag_in ^ 128'h1;
            data_out_n = 0;
            decr_en    = 1'b1;
            run_once();

            if (tag_ok !== 1'b0) begin
                errors++;
                $display("FAIL v%0d BAD TAG ACCEPTED (tag_ok=%b) -- authentication broken",
                         v, tag_ok);
            end
            tag_in = tag_in ^ 128'h1;

            @(negedge clk);
        end
    endtask

    // -----------------------------------------------------------------
    // Sweep
    // -----------------------------------------------------------------
    initial begin
        start = 1'b0; decr_en = 1'b0; tag_in = '0;
        key = '0; nonce = '0;
        clear_vectors();
        rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        key   = KAT_KEY;
        nonce = KAT_NONCE;

        $display("=== NIST KAT sweep: %0d vectors x 3 passes ===", NVEC);

        for (int v = 0; v < NVEC; v++) begin
            clear_vectors();

            // unpack the packed meta word
            ad_blocks      = kat_meta[v][31:24];
            ad_len         = kat_meta[v][23:20];
            data_in_blocks = kat_meta[v][19:12];
            data_len       = kat_meta[v][11:8];

            // vector v's block j lives at index v*MAXBLK + j
            for (int j = 0; j < MAXBLK; j++) begin
                ad_mem[j] = kat_ad[v*MAXBLK + j];
                pt_mem[j] = kat_pt[v*MAXBLK + j];
                exp_ct[j] = kat_ct[v*MAXBLK + j];
            end
            exp_tag = kat_tag[v];

            run_case(v);

            if ((v % PROGRESS) == (PROGRESS-1))
                $display("  ... %0d/%0d vectors, %0d errors", v+1, NVEC, errors);

            if (errors > MAX_ERR) begin
                $display("*** stopping early: more than %0d failures ***", MAX_ERR);
                break;
            end
        end

        $display("--------------------------------------------------");
        $display("Vectors run: %0d   Errors: %0d", cases, errors);
        if (errors == 0) $display("*** ALL %0d NIST VECTORS PASSED ***", cases);
        else             $display("*** %0d CHECK(S) FAILED ***", errors);
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
