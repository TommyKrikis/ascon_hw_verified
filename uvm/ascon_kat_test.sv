class ascon_kat_test extends uvm_test;
  ascon_env my_env;
  ascon_kat_sequence en_seq;
  ascon_dec_sequence dec_seq;

  `uvm_component_utils(ascon_kat_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_top.set_timeout(5ms, 0);
    my_env      = ascon_env::type_id::create("my_env", this);
    
   endfunction

  task run_phase(uvm_phase phase);
    en_seq = ascon_kat_sequence::type_id::create("en_seq");
    dec_seq = ascon_dec_sequence::type_id::create("dec_seq");

    en_seq.num_vectors = 1089;
    dec_seq.num_vectors = 1089;
    phase.phase_done.set_drain_time(this, 100ns);
    phase.raise_objection(this);
    `uvm_info("BASE_TEST", "UVM flow is alive", UVM_LOW)
    en_seq.start(my_env.agt.seqr);
    dec_seq.start(my_env.agt.seqr);
    phase.drop_objection(this);
  endtask
endclass