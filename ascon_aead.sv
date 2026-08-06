module ascon_aead(
    input  logic        start,     

    input logic         clk,           
    input logic         rst_n,         

    output logic        busy,           
    output logic        done,           

    input  logic [127:0] key,            
    input  logic [127:0] nonce,

    output logic [127:0] data_out_block,
    output logic data_out_valid,       
    
    input  logic [127:0] data_in,
    input logic [7:0] data_blocks,
    output logic [7:0] data_idx,          // "I want block number data_idx"
    input logic [3:0] data_len,       

    input logic [127:0] ad_block,
    input  logic [7:0]   ad_blocks,   // how many AD blocks total (0 = empty)
    output logic [7:0]   ad_idx,      // "I want block number ad_idx"
    output logic [127:0] tag,
    input logic decr_en,
    input  logic [127:0] tag_in,       // the tag received with the ciphertext (decrypt only)
    output logic tag_ok           
);

  localparam [63:0] iv = 64'h00001000808c0001;
  logic [319:0] state_i;
  assign state_i = {nonce, key, iv};
  logic [127:0] pad, pad_keep, data_padded;
  assign pad       = 128'h1 << (data_len*8);
  assign pad_keep  = pad - 128'h1;
  assign data_padded = (data_in & pad_keep) | pad;

  logic [3:0] perm_rounds = 4'b0000;

  typedef enum logic [3:0] {IDLE,INIT_START,INIT_WAIT,PROCESS_AD_INIT, PROCESS_AD_WAIT,AD_DS, PROCESS_PT_INIT,PROCESS_PT_WAIT,FINALIZE,FIN_START,FIN_WAIT,DONE} state_e;
  state_e fsm;
  logic perm_start,perm_busy, perm_done;
  logic [319:0] perm_state_in, perm_state_out;


  ascon_perm ascon_perm_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(perm_start),
    .num_rounds(perm_rounds),
    .state_in(perm_state_in),
    .state_out(perm_state_out),
    .busy(perm_busy),
    .done(perm_done)
  );

  logic [191:0] state_reg_up;
  logic [127:0] state_reg_down;

  assign busy = (fsm != IDLE);
  assign done = (fsm == DONE);
  
  always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm <= IDLE;
            perm_start <= 1'b0;
            data_out_block <= 128'h0;
            tag <= 128'h0;  
            ad_idx <= 8'd0;
            data_idx <= 8'd0;
        end else begin
            data_out_valid <= 1'b0;
            case (fsm)
                IDLE: begin
                    if(start) begin
                        perm_rounds <= 4'b1100;
                        perm_state_in <= state_i;
                        ad_idx <= 8'd0; 
                        data_idx <= 8'd0;
                        fsm <= INIT_START;
                        data_out_valid <= 1'b0;
                        tag_ok <= 1'b0;
                    end
                end
                INIT_START: begin
                    perm_start <= 1'b1;
                    fsm <= INIT_WAIT;
                end
                INIT_WAIT: begin
                    perm_start <= 1'b0;
                    if(perm_done) begin
                        {state_reg_up, state_reg_down} <= perm_state_out^{key,192'h0};
                        fsm <= (ad_blocks == 0) ? AD_DS : PROCESS_AD_INIT;
                    end
                end
                PROCESS_AD_INIT: begin
                    perm_rounds <= 4'b1000;                   
                    perm_state_in <= {state_reg_up, state_reg_down ^ ad_block};
                    perm_start <= 1'b1;
                    fsm <= PROCESS_AD_WAIT;
                end
                PROCESS_AD_WAIT: begin
                    perm_start <= 1'b0;
                    if(perm_done) begin
                        {state_reg_up, state_reg_down} <= perm_state_out;
                        ad_idx <= ad_idx + 8'd1;
                        fsm <= (ad_idx == ad_blocks - 1) ? AD_DS : PROCESS_AD_INIT;
                    end
                end
                AD_DS: begin
                    state_reg_up[191] <= ~state_reg_up[191];
                    fsm <= PROCESS_PT_INIT;
                end
                PROCESS_PT_INIT: begin
                    if(data_idx == data_blocks - 1) begin
                        if(decr_en) begin
                            state_reg_down <= (state_reg_down & ~pad_keep)     // untouched part of the rate
                                ^ (data_in & pad_keep)             // the received ciphertext bytes
                                ^ pad;                             // the 0x01 marker
                            data_out_block <= state_reg_down ^ (data_in & pad_keep);
                        end else begin
                            state_reg_down <= state_reg_down ^ data_padded;
                            data_out_block       <= state_reg_down ^ data_padded;
                        end
                        data_out_valid   <= 1'b1;   
                        fsm <= FINALIZE;
                    end else begin
                        perm_rounds <= 4'b1000;
                        if(decr_en) begin
                            perm_state_in <= {state_reg_up, data_in};
                            data_out_block <= state_reg_down ^ data_in;
                        end else begin
                            perm_state_in <= {state_reg_up, state_reg_down ^ data_in};
                            data_out_block <= state_reg_down ^ data_in;
                        end
                        data_out_valid <= 1'b1;
                        perm_start <= 1'b1;
                        fsm <= PROCESS_PT_WAIT;
                    end    
                end
                PROCESS_PT_WAIT: begin
                    perm_start <= 1'b0;
                    if(perm_done) begin
                        {state_reg_up, state_reg_down} <= perm_state_out;
                        data_idx <= data_idx + 8'd1;
                        fsm <= PROCESS_PT_INIT;
                    end
                end
                FINALIZE: begin
                    perm_rounds   <= 4'b1100;
                    perm_state_in <= {state_reg_up, state_reg_down} ^ {64'h0, key, 128'h0};
                    fsm           <= FIN_START;     // then FIN_START pulses perm_start, → FIN_WAIT
                end
                FIN_START: begin
                    perm_start <= 1'b1;
                    fsm <= FIN_WAIT;
                end
                FIN_WAIT: begin
                    perm_start <= 1'b0;
                    if(perm_done) begin
                        if(decr_en) begin
                            tag_ok <= (tag_in == (perm_state_out[319:192] ^ key));
                        end
                        tag <= perm_state_out[319:192] ^ key;
                        fsm <= DONE;
                    end
                end
                DONE: begin
                    fsm <= IDLE;
                end
                default: fsm <= IDLE;
            endcase     
        end
    end


endmodule
