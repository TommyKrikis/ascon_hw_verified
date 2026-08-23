class ascon_sequencer extends uvm_sequencer #(ascon_sequence_item);
  `uvm_component_utils(ascon_sequencer)

  function new (string name, uvm_component parent);
    super.new(name, parent); 
  endfunction
endclass