module free_list
#(
    parameter int RAM_DEPTH	    = 64
)
(
    input  logic                        clk         ,
    input  logic                        rst_n       ,
    // input channel    
    input  logic[5:0]                   push_data   ,
    input  logic                        push        ,
    input  logic[5:0]                   push_data_2 ,
    input  logic                        push_2      ,
    output logic                        ready       ,
    // output channel #1    
    output logic[5:0]                   pop_data_1  ,
    output logic                        valid_1     ,
    input  logic                        pop_1       ,
    // output channel #2    
    output logic[5:0]                   pop_data_2  ,
    output logic                        valid_2     ,
    input  logic                        pop_2
    );

    logic[63:0][5:0]                    mem;
    logic[63:0]                         pop_pnt, pop_pnt_2, push_pnt, push_pnt_2;
    logic[64:0]                         status_cnt;
    logic[3:0]                          shift_vector;
    logic                               single_push, double_push, single_pop, double_pop, shift_left_single, shift_right_double, shift_right_single;

    assign valid_1 = ~status_cnt[0];
    assign valid_2 = ~status_cnt[0] & ~status_cnt[1];
    assign ready   = ~status_cnt[RAM_DEPTH];
    assign single_pop  = pop_1 ^ pop_2;
    assign double_pop  = pop_1 & pop_2;
    assign single_push = push ^ push_2;
    assign double_push = push & push_2;
    //Push Pointer Update
    assign push_pnt_2 = {push_pnt[RAM_DEPTH-2:0], push_pnt[RAM_DEPTH-1]};
    always_ff @(posedge clk or negedge rst_n) begin : PushPnt
        if(!rst_n) begin
            push_pnt <= 1 << (RAM_DEPTH-32);
        end 
        else if (double_push) begin
            push_pnt <= {push_pnt[RAM_DEPTH-3:0], push_pnt[RAM_DEPTH-1], push_pnt[RAM_DEPTH-2]};
        end 
        else if (single_push) begin
            push_pnt <= {push_pnt[RAM_DEPTH-2:0], push_pnt[RAM_DEPTH-1]};
        end
    end
    //Pop Pointer Update
    always_ff @(posedge clk or negedge rst_n) begin : PopPnt
        if(!rst_n) begin
            pop_pnt  <= 1;
        end 
        else if(double_pop) begin
            pop_pnt <= {pop_pnt[RAM_DEPTH-3:0], pop_pnt[RAM_DEPTH-1:RAM_DEPTH-2]};
        end 
        else if(single_pop) begin
            pop_pnt <= {pop_pnt[RAM_DEPTH-2:0], pop_pnt[RAM_DEPTH-1]};
        end
    end
    // Status Counter (onehot coded)
    always_ff @(posedge clk or negedge rst_n) begin: ff_status_cnt
        if(!rst_n) begin
            status_cnt <= 1 << (RAM_DEPTH-32);
        end 
        else if (double_push) begin
            if(double_pop) begin
                status_cnt <= status_cnt;
            end else if(single_pop) begin
                status_cnt <= status_cnt << 1;
            end else if (!single_pop) begin
                status_cnt <= status_cnt << 2;
            end
        end 
        else if(single_push) begin
            if(double_pop) begin
                status_cnt <= status_cnt >> 1;
            end else if(!single_pop) begin
                status_cnt <= status_cnt << 1;
            end
        end 
        else if(double_pop) begin
            if(single_pop) begin
                status_cnt <= status_cnt >> 1; 
            end 
            else begin
                status_cnt <= status_cnt >> 2;
            end
        end
    end
    // data write (push)
    // address decoding needed for onehot push pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (int i = 0; i < (RAM_DEPTH-32); i++) begin
                mem[i] <= 32+i;
            end
        end 
        else begin
            for (int i = 0; i < RAM_DEPTH; i++) begin
                if(double_push) begin
                    if( push & push_pnt[i] ) begin
                        mem[i] <= push_data;
                    end 
                    else if(push_2 & push_pnt_2[i]) begin
                        mem[i] <= push_data_2;
                    end
                end 
                else if (single_push) begin
                    if( push & push_pnt[i] ) begin
                        mem[i] <= push_data;
                    end 
                    else if(push_2 & push_pnt[i]) begin
                        mem[i] <= push_data_2;
                    end
                end
            end
        end
    end

    assign pop_pnt_2 = {pop_pnt[RAM_DEPTH-2:0], pop_pnt[RAM_DEPTH-1]};
    and_or_mux #(
        .INPUTS(RAM_DEPTH ),
        .DW    (6)
    ) mux_out (
        .data_in (mem       ),
        .sel     (pop_pnt   ),
        .data_out(pop_data_1)
    );

    and_or_mux #(
        .INPUTS(RAM_DEPTH ),
        .DW    (6)
    ) mux_out_2 (
        .data_in (mem       ),
        .sel     (pop_pnt_2 ),
        .data_out(pop_data_2)
    );

endmodule
