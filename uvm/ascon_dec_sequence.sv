class ascon_dec_sequence extends uvm_sequence #(ascon_sequence_item);
  `uvm_object_utils(ascon_dec_sequence)

  localparam int NVEC_MAX = 1089;   // vectors in the KAT file
  localparam int MAXBLK   = 3;      // blocks per field (32 bytes -> 2 + 1 pad)

  // key/nonce are constant across every KAT vector (gen_kat_hex.py checks this)
  localparam logic [127:0] KAT_KEY   = 128'h0f0e0d0c0b0a09080706050403020100;
  localparam logic [127:0] KAT_NONCE = 128'h0f0e0d0c0b0a09080706050403020100;

  // How many vectors to send. Set smaller from the test for quick runs.
  int num_vectors = NVEC_MAX;

  logic [31:0]  kat_meta [0:NVEC_MAX-1];
  logic [127:0] kat_ct   [0:MAXBLK*NVEC_MAX-1];
  logic [127:0] kat_ad   [0:MAXBLK*NVEC_MAX-1];
  logic [127:0] kat_tag  [0:NVEC_MAX-1];


  function new(string name = "ascon_dec_sequence");
    super.new(name);
  endfunction

  // -------------------------------------------------------------------------
  // blocks -> bytes. Same mapping the driver and monitor use: byte j of the
  // message lives in block j/16 at bit position (j%16)*8.
  // -------------------------------------------------------------------------
  function automatic void unpack(input logic [127:0] blk[],
                                 input int base,      // first block of this vector
                                 input int nbytes,
                                 ref byte out[]);
    out = new[nbytes];
    for (int j = 0; j < nbytes; j++)
      out[j] = blk[base + j/16][(j%16)*8 +: 8];
  endfunction

  task body();
    int data_blocks, data_len, ad_blocks, ad_len;
    int nbytes_data, nbytes_ad;

    $readmemh("kat_ct.hex", kat_ct);
    $readmemh("kat_tag.hex", kat_tag);
    $readmemh("kat_meta.hex", kat_meta);
    $readmemh("kat_ad.hex", kat_ad);

    `uvm_info(get_type_name(),
              $sformatf("driving %0d KAT vectors", num_vectors), UVM_LOW)

    for (int v = 0; v < num_vectors; v++) begin
      // ---- unpack the meta word written by gen_kat_hex.py ----
      ad_blocks   = kat_meta[v][31:24];
      ad_len      = kat_meta[v][23:20];
      data_blocks = kat_meta[v][19:12];
      data_len    = kat_meta[v][11:8];

      // real byte counts implied by those fields
      nbytes_data = (data_blocks - 1) * 16 + data_len;
      nbytes_ad   = (ad_blocks == 0) ? 0 : (ad_blocks - 1) * 16 + ad_len;

      req = ascon_sequence_item::type_id::create($sformatf("kat_%0d", v));

      // Directed stimulus: set fields explicitly, no randomize().
      req.key     = KAT_KEY;
      req.tag_in = kat_tag[v];
      req.nonce   = KAT_NONCE;
      req.decr_en = 1'b1;                 // KAT vectors are encryption
      unpack(kat_ct, v*MAXBLK, nbytes_data, req.pt);
      unpack(kat_ad, v*MAXBLK, nbytes_ad,   req.ad);

      start_item(req);
      finish_item(req);                   // blocks until the driver is done

      if ((v % 100) == 99)
        `uvm_info(get_type_name(),
                  $sformatf("... %0d/%0d vectors sent", v+1, num_vectors), UVM_LOW)
    end
  endtask

endclass
