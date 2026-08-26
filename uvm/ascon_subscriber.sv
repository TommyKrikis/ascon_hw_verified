class ascon_subscriber extends uvm_subscriber #(ascon_sequence_item);
  `uvm_component_utils(ascon_subscriber)

  ascon_sequence_item tr;          // covergroups sample class members

  covergroup cg;
    pt_len: coverpoint tr.pt.size() {
      bins b_empty  = {0};
      bins b_one    = {1};
      bins b_small  = {[2:8]};
      bins b_medium = {[9:16]};
      bins b_large  = {[17:32]};
    }
    ad_len: coverpoint tr.ad.size() {       
      bins b_empty  = {0};
      bins b_one    = {1};
      bins b_small  = {[2:8]};
      bins b_medium = {[9:16]};
      bins b_large  = {[17:32]};  
    }
    mode:   coverpoint tr.decr_en;
    cross_len: cross pt_len, ad_len;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();                    
  endfunction

  function void write(ascon_sequence_item t);
    tr = t;
    cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
  `uvm_info(get_type_name(), $sformatf("coverage = %0.2f%%", cg.get_coverage()), UVM_LOW)
endfunction
endclass