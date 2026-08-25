// ---------------------------------------------------------------------------
// ascon_monitor -- passively observes the interface and rebuilds one complete
// transaction per DUT operation, then broadcasts it on an analysis port.
//
// Everything here comes from PINS only (vif.mon_cb). The monitor never looks
// at the driver or the sequence item -- that independence is what makes a
// scoreboard comparison meaningful.
// ---------------------------------------------------------------------------
class ascon_monitor extends uvm_monitor;
  `uvm_component_utils(ascon_monitor)

  virtual ascon_if vif;

  // broadcast: non-blocking, any number of subscribers (scoreboard, coverage)
  uvm_analysis_port #(ascon_sequence_item) mon_analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_analysis_port = new("mon_analysis_port", this);
    if (!uvm_config_db #(virtual ascon_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface ascon_if")
  endfunction

  // -------------------------------------------------------------------------
  // Helper: turn an array of 128-bit blocks into a byte array of `nbytes`.
  // This is the exact inverse of the packing the driver does.
  // -------------------------------------------------------------------------
  function automatic void unpack_bytes(input logic [127:0] blk[],
                                       input int nbytes,
                                       ref byte out[]);
    out = new[nbytes];
    for (int j = 0; j < nbytes; j++)
      out[j] = blk[j/16][(j%16)*8 +: 8];
  endfunction

  virtual task run_phase(uvm_phase phase);
    ascon_sequence_item tr;
    logic [127:0] in_blk[];      // message blocks seen on data_in
    logic [127:0] ad_blk_s[];    // AD blocks seen on ad_block
    logic [127:0] out_blk[];     // ciphertext/plaintext blocks seen leaving
    int out_n;
    int nbytes_data, nbytes_ad;

    wait (vif.rst_n === 1'b1);

    forever begin
      // ---- 1. wait for the start of an operation ----
      do @(vif.mon_cb); while (vif.mon_cb.start !== 1'b1);
      tr = ascon_sequence_item::type_id::create("tr");

      // ---- 2. capture the stimulus side, as presented on the pins ----
      tr.key     = vif.mon_cb.key;
      tr.nonce   = vif.mon_cb.nonce;
      tr.decr_en = vif.mon_cb.decr_en;

      in_blk   = new[vif.mon_cb.data_blocks];
      ad_blk_s = new[(vif.mon_cb.ad_blocks == 0) ? 1 : vif.mon_cb.ad_blocks];
      out_blk  = new[vif.mon_cb.data_blocks];
      out_n    = 0;

      // real byte counts implied by the block/length pins
      nbytes_data = (vif.mon_cb.data_blocks - 1) * 16 + vif.mon_cb.data_len;
      nbytes_ad   = (vif.mon_cb.ad_blocks == 0) ? 0
                    : (vif.mon_cb.ad_blocks - 1) * 16 + vif.mon_cb.ad_len;

      // ---- 3. follow the operation until it finishes ----
      // The DUT fetches blocks by index, so sample whatever it is being
      // shown each cycle; the last value seen for an index is the one it
      // consumed. Ciphertext leaves one block per data_out_valid pulse.
      while (vif.mon_cb.done !== 1'b1) begin
        if (vif.mon_cb.data_idx < in_blk.size())
          in_blk[vif.mon_cb.data_idx] = vif.mon_cb.data_in;
        if (vif.mon_cb.ad_idx < ad_blk_s.size())
          ad_blk_s[vif.mon_cb.ad_idx] = vif.mon_cb.ad_block;

        if (vif.mon_cb.data_out_valid === 1'b1 && out_n < out_blk.size()) begin
          out_blk[out_n] = vif.mon_cb.data_out_block;
          out_n++;
        end


        @(vif.mon_cb);
      end
      // ---- 4. results are valid with done ----
      tr.tag    = vif.tag;
      tr.tag_ok = vif.tag_ok;
      // ---- 5. blocks back into byte arrays ----
      unpack_bytes(in_blk,   nbytes_data, tr.pt);
      unpack_bytes(ad_blk_s, nbytes_ad,   tr.ad);
      unpack_bytes(out_blk,  nbytes_data, tr.ct);   // |CT| == |PT|


      `uvm_info(get_type_name(),
                $sformatf("observed: %0d data blk, %0d ad blk, tag=%032h tag_ok=%0b",
                          in_blk.size(), ad_blk_s.size(), tr.tag, tr.tag_ok),
                UVM_MEDIUM)

      // ---- 6. broadcast one complete transaction ----
      mon_analysis_port.write(tr);
    end
  endtask

endclass
