class ascon_base_test extends uvm_test;
  ascon_env my_env;
  ascon_sequence my_seq;
  `uvm_component_utils(ascon_base_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_top.set_timeout(1ms, 0);
    my_seq = ascon_sequence::type_id::create("my_seq");
    my_env      = ascon_env::type_id::create("my_env", this);
   endfunction

  task run_phase(uvm_phase phase);
    phase.phase_done.set_drain_time(this, 100ns);
    phase.raise_objection(this);
    `uvm_info("BASE_TEST", "UVM flow is alive", UVM_LOW)
    my_seq.start(my_env.agt.seqr);
    phase.drop_objection(this);
  endtask
endclass