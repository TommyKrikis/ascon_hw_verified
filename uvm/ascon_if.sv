interface ascon_if (input bit clk);


  logic        start;     
  logic         rst_n;         
  logic        busy;           
  logic        done;           
  logic [127:0] key;           
  logic [127:0] nonce;
  logic [127:0] data_out_block;
  logic data_out_valid;       
  logic [127:0] data_in;
  logic [7:0] data_blocks;
  logic [7:0] data_idx;         
  logic [3:0] data_len;       
  logic [127:0] ad_block;
  logic [7:0]   ad_blocks;   
  logic [7:0]   ad_idx;      
  logic [3:0] ad_len;        
  logic [127:0] tag;
  logic decr_en;
  logic [127:0] tag_in;       
  logic tag_ok;    

  logic [127:0] pt_blk [0:2];
  logic [127:0] ad_blk [0:2];
  assign data_in  = pt_blk[data_idx];
  assign ad_block = ad_blk[ad_idx];

  clocking drv_cb @(posedge clk);
    default input #1step output #2ns;
    output start, key, nonce, data_blocks, data_len, decr_en, ad_blocks, ad_len, tag_in;
    input  busy, done, data_idx, data_out_block, data_out_valid, tag,ad_idx,tag_ok ;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input  busy, done, data_idx, data_out_block, data_out_valid, tag,start, key, nonce, data_in, data_blocks, data_len, decr_en,ad_block, ad_blocks, ad_idx, ad_len, tag_in, tag_ok;
  endclocking      

  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);
  modport DUT (input clk, rst_n, start, key, nonce, data_in, data_blocks, data_len, decr_en,ad_block, ad_blocks, ad_len, tag_in,output busy, done, data_idx, data_out_block, ad_idx,data_out_valid, tag_ok,tag);
endinterface