import uvm_pkg::*;
import ascon_pkg::*;

module ascon_tb_top;
  
  bit clk;

  always #5 clk = ~clk;

  ascon_if intf(clk);

  initial begin
    intf.rst_n = 1'b0;
    repeat (3) @(posedge clk);
    intf.rst_n = 1'b1;
  end
  
  //DUT instance, interface signals are connected to the DUT ports
  ascon_aead DUT (
    .clk            (intf.clk),
    .rst_n          (intf.rst_n),
    .start          (intf.start),
    .busy           (intf.busy),
    .done           (intf.done),

    .key            (intf.key),
    .nonce          (intf.nonce),

    .data_in        (intf.data_in),
    .data_blocks    (intf.data_blocks),
    .data_idx       (intf.data_idx),
    .data_len       (intf.data_len),
    .data_out_block (intf.data_out_block),
    .data_out_valid (intf.data_out_valid),

    .ad_block       (intf.ad_block),
    .ad_blocks      (intf.ad_blocks),
    .ad_idx         (intf.ad_idx),
    .ad_len         (intf.ad_len),

    .decr_en        (intf.decr_en),
    .tag            (intf.tag),
    .tag_in         (intf.tag_in),
    .tag_ok         (intf.tag_ok)
   );
  
  //enabling the wave dump
  initial begin 
    uvm_config_db#(virtual ascon_if)::set(uvm_root::get(),"*","vif",intf);
    $dumpfile("dump.vcd"); $dumpvars;
  end
  
  initial begin 
    run_test();
  end
endmodule