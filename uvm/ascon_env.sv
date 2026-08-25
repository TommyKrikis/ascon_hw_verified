class ascon_env extends uvm_env;
  ascon_agent agt;
  ascon_scoreboard sb;
  `uvm_component_utils(ascon_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
    


  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = ascon_agent::type_id::create("agt", this);
    sb = ascon_scoreboard::type_id::create("sb", this);
   endfunction

  function void connect_phase(uvm_phase phase);
    agt.mon_A.mon_analysis_port.connect(sb.mon_imp);
  endfunction

endclass