class ascon_sequence extends uvm_sequence #(ascon_sequence_item);
  `uvm_object_utils(ascon_sequence)

  function new(string name = "ascon_sequence");
    super.new(name);
  endfunction

  task body();
    req = ascon_sequence_item::type_id::create("req");
    start_item(req);
    assert(req.randomize() with { decr_en == 0; });
    finish_item(req);
  endtask
endclass