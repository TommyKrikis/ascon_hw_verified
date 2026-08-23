class ascon_env extends uvm_env;
  ascon_agent agt;
  // uvm_component_utils, constructor
  // build_phase: agt = ascon_agent::type_id::create("agt", this);

    `uvm_component_utils(ascon_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
    
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt      = ascon_agent::type_id::create("agt", this);
   endfunction

endclass