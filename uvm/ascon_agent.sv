class ascon_agent extends uvm_agent;
  ascon_driver drv;
  ascon_sequencer seqr;
  //ascon_monitor mon_A;
  `uvm_component_utils(ascon_agent)
  
  function new(string name = "ascon_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(get_is_active() == UVM_ACTIVE) begin
      drv = ascon_driver::type_id::create("drv", this);
      seqr = ascon_sequencer::type_id::create("seqr", this);
      `uvm_info(get_name(), "This is Active agent", UVM_LOW);
    end
    //mon_A = monitor_A::type_id::create("mon_A", this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass