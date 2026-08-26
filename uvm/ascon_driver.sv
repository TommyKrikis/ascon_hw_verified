class ascon_driver extends uvm_driver #(ascon_sequence_item);

  `uvm_component_utils(ascon_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

virtual ascon_if vif;

virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(virtual ascon_if)::get(this, "", "vif", vif)) begin
    `uvm_fatal(get_type_name(), "Didn't get handle to virtual interface ascon_if")
  end
endfunction

virtual task run_phase(uvm_phase phase);
  ascon_sequence_item req;
  wait (vif.rst_n === 1'b1);
  forever begin

    seq_item_port.get_next_item(req); 
    `uvm_info(get_type_name(), $sformatf("driving:\n%s", req.sprint()), UVM_HIGH)
    foreach (vif.pt_blk[i]) vif.pt_blk[i] = '0;
    foreach (vif.ad_blk[i]) vif.ad_blk[i] = '0;


    // drive the interface signals based on the request item
    vif.drv_cb.tag_in <= req.tag_in;
    vif.drv_cb.key <= req.key;
    vif.drv_cb.nonce <= req.nonce;
    vif.drv_cb.data_blocks <= req.pt.size()/16+1;
    vif.drv_cb.data_len <= req.pt.size() % 16;
    vif.drv_cb.ad_len <= req.ad.size() % 16;
    vif.drv_cb.ad_blocks <= (req.ad.size()==0) ? 0 : req.ad.size()/16+1;
    vif.drv_cb.decr_en <= req.decr_en;
    foreach (req.pt[j])
    vif.pt_blk[j/16][ (j%16)*8 +: 8 ] = req.pt[j];

    foreach (req.ad[j])
        vif.ad_blk[j/16][ (j%16)*8 +: 8 ] = req.ad[j];

    vif.drv_cb.start <= 1'b1;
    @(vif.drv_cb);
    vif.drv_cb.start <= 1'b0;

    // wait for the DUT to signal that it is done
    while (!vif.drv_cb.done) @(vif.drv_cb);

    seq_item_port.item_done();

  end
endtask

endclass