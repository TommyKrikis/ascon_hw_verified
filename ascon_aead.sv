module ascon_aead(
    input  logic        start,     

    input logic         clk,           
    input logic         rst_n,         

    output logic        busy,           
    output logic        done,           

    input  logic [127:0] key,            
    input  logic [127:0] nonce,          
    output logic [127:0] ct_block,
    output logic ct_valid,       
    input  logic [127:0] pt_block,
    input logic [7:0] pt_blocks,
    output logic [7:0] pt_idx,          // "I want block number pt_idx"
    input logic [127:0] ad_block,
    input  logic [7:0]   ad_blocks,   // how many AD blocks total (0 = empty)
    output logic [7:0]   ad_idx,      // "I want block number ad_idx"
    input logic [3:0] pt_len,       
    output logic [127:0] tag           
);

  localparam [63:0] iv = 64'h00001000808c0001;
  logic [319:0] state_i;
  assign state_i = {nonce, key, iv};
  logic [127:0] pad, pad_keep, pt_padded;
  assign pad       = 128'h1 << (pt_len*8);
  assign pad_keep  = pad - 128'h1;
  assign pt_padded = (pt_block & pad_keep) | pad;

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
            ct_block <= 128'h0;
            tag <= 128'h0;  
            ad_idx <= 8'd0;
            pt_idx <= 8'd0;
        end else begin
            ct_valid <= 1'b0;
            case (fsm)
                IDLE: begin
                    if(start) begin
                        perm_rounds <= 4'b1100;
                        perm_state_in <= state_i;
                        ad_idx <= 8'd0; 
                        pt_idx <= 8'd0;
                        fsm <= INIT_START;
                        ct_valid <= 1'b0;
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
                    if(pt_idx == pt_blocks - 1) begin
                        state_reg_down <= state_reg_down ^ pt_padded;
                        ct_block       <= state_reg_down ^ pt_padded;
                        ct_valid   <= 1'b1;   
                        fsm <= FINALIZE;
                    end else begin
                        perm_rounds <= 4'b1000;
                        perm_state_in <= {state_reg_up, state_reg_down ^ pt_block};
                        ct_valid <= 1'b1;
                        ct_block <= state_reg_down ^ pt_block;
                        perm_start <= 1'b1;
                        fsm <= PROCESS_PT_WAIT;
                    end    
                end
                PROCESS_PT_WAIT: begin
                    perm_start <= 1'b0;
                    if(perm_done) begin
                        {state_reg_up, state_reg_down} <= perm_state_out;
                        pt_idx <= pt_idx + 8'd1;
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
