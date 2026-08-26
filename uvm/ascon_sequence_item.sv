class ascon_sequence_item extends uvm_sequence_item;

  // 1. stimulus: what the driver should apply
  rand bit [127:0] key;
  rand byte pt[]; 
  rand bit [127:0] nonce;
  rand byte ad[];   
  bit [127:0] tag_in;      
  rand bit decr_en;


  // 2. results: what the monitor observed
  byte ct[];
  bit [127:0] tag;
  bit tag_ok;

  // 3. constraints: what "legal" means
  constraint c_pt_len { pt.size() inside {[0:32]}; }
  constraint c_ad_len { ad.size() inside {[0:32]}; }
  constraint c_decr_en { decr_en inside {0,1}; }
  
  // 4. factory + field registration
  `uvm_object_utils_begin(ascon_sequence_item)
    `uvm_field_int(key, UVM_ALL_ON)
    `uvm_field_array_int(pt, UVM_ALL_ON)
    `uvm_field_int(nonce, UVM_ALL_ON)
    `uvm_field_array_int(ad, UVM_ALL_ON)
    `uvm_field_int(decr_en, UVM_ALL_ON)
    `uvm_field_array_int(ct, UVM_ALL_ON)
    `uvm_field_int(tag, UVM_ALL_ON)
    `uvm_field_int(tag_ok, UVM_ALL_ON)
  `uvm_object_utils_end

  // 5. constructor
  function new(string name = "ascon_sequence_item");
    super.new(name);
  endfunction

endclass