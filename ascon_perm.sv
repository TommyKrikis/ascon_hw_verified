module ascon_perm(
    // control
    input  logic        start,          // pulse: begin a permutation
    input  logic [3:0]  num_rounds,     // how many rounds to run (6, 8, or 12)

    input logic         clk,            // clock
    input logic         rst_n,          // async reset, active low

    output logic        busy,           // high while permutation is running
    output logic        done,           // 1-cycle pulse when finished

    // data
    input  logic [319:0] state_in,      // loaded when start is asserted
    output logic [319:0] state_out      // valid when done is high
);
    logic [3:0]   round_cnt;   
    logic [3:0]   rc_idx;      
    logic [319:0] state_reg, round_out;

    typedef enum logic [2:0] {IDLE, RUN, DONE_ST} state_e;
    state_e fsm;

    assign rc_idx = (4'd12 - num_rounds) + round_cnt;

    p_round p_round_inst (
        .state_in(state_reg),
        .round_curr(rc_idx),
        .state_out(round_out)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            round_cnt <= 4'd0;
        end else begin
            done <= 1'b0;
            case (fsm)
                IDLE: begin
                    busy <= 1'b0;
                    if(start) begin
                        round_cnt <= 4'd0;
                        state_reg <= state_in;
                        busy <= 1'b1;
                        fsm <= RUN;
                    end
                end
                RUN: begin
                    busy <= 1'b1;
                    if (round_cnt < num_rounds) begin
                        state_reg <= round_out;
                        round_cnt <= round_cnt + 4'd1;
                    end
                    else begin
                        fsm <= DONE_ST;
                    end
                end
                DONE_ST: begin
                    state_out <= state_reg;
                    busy <= 1'b0;
                    done <= 1'b1;
                    fsm <= IDLE;   
                end
            endcase     
        end
    end

endmodule
