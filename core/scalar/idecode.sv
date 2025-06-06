module idecode 
(
    input  logic                             clk                ,
    input  logic                             rst_n              ,
    //Port towards IF
    input  logic                             valid_i            ,
    output logic                             ready_o            ,
    input  logic                             taken_branch_1     ,
    input  logic [31:0]                      pc_in_1            ,
    input  logic [31:0]                      instruction_in_1   ,
    input  logic                             taken_branch_2     ,
    input  logic [31:0]                      pc_in_2            ,
    input  logic [31:0]                      instruction_in_2   ,
    output logic                             is_branch          ,//one of instr is branch
    //Output Port towards IF (Redirection Ports)
    output logic                             invalid_instruction,
    output logic                             invalid_prediction ,//misPredicted taken on non-branch instruction
    output logic                             is_return          ,
    output logic                             is_call            ,
    output logic [31:0]                      old_pc             ,
    //Port towards IS (instruction queue)
    input  logic                             ready_i            , //must indicate at least 2 free slots in queue
    output logic                             valid_o            , //indicates first push
    output decoded_instr                     output1            ,
    output logic [1:0]                       output1_branch_id  ,
    output logic                             valid_o_2          , //indicates second push
    output decoded_instr                     output2            ,
    output logic [1:0]                       output2_branch_id  ,
    //Predictor Update Port
    input  predictor_update                  pr_update1         ,//from ex
    input  predictor_update                  pr_update2         ,//from ex
    //Flush Port
    output logic                             must_flush         ,
    output logic [31:0]                      correct_address    ,
    output logic [2:0]                       rob_ticket         ,
    output logic                             flush_rat_id       
);
    // #Internal Signals#
    logic  [2:0] branch_if;

    logic   valid_transaction, valid_branch_32a, valid_branch_32b, ready_o_d;
    logic   one_slot_free, branch_stall, two_slots_free, two_branches;
    logic   valid_o_d, valid_o_2_d;
    predictor_update pr_update;
    logic   pr_update_signle_branch, pr_update_double_branch;
    logic   branch_num;

    //Control Flow -IF
    assign ready_o = (ready_o_d & ~branch_stall ) | must_flush;
    //Control Flow -RR
    assign valid_o   = valid_o_d & ~branch_stall & ~must_flush;
    assign valid_o_2 = valid_o_2_d & ~branch_stall & ~must_flush;

    logic [31:0] last_pc_a,last_pc_b;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            last_pc_a <= 32'b0;
        else if(must_flush)
            last_pc_a <= 32'b0;
        else if(~branch_stall & valid_branch_32a)
            last_pc_a <= pc_in_1;      
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            last_pc_b <= 32'b0;
        else if(must_flush)
            last_pc_b <= 32'b0;
        else if(~branch_stall & valid_branch_32b)
            last_pc_b <= pc_in_2;      
    end
    assign is_branch     = (valid_branch_32a ^ valid_branch_32b) & (last_pc_a != pc_in_1);
    assign two_branches  = valid_branch_32a & valid_branch_32b  & (last_pc_a != pc_in_1);
    //最多允许两条分支指令存在流水线中
    assign branch_stall  = (~one_slot_free & is_branch) | (~two_slots_free & two_branches);
    assign one_slot_free = branch_if != 3'd2;
    assign two_slots_free= branch_if == 3'd0;

   /* logic branch_stall_delay;
    logic save_branch;
    logic is_branch_w,two_branches_w;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            branch_stall_delay <= 1'b0;
        else 
            branch_stall_delay <= branch_stall;
    end
    assign save_branch  = ~branch_stall & branch_stall_delay;

    assign is_branch_w  = ~must_flush & save_branch & ((valid_branch_32a & (pc_in_1 == last_pc_a)) ^
                           (valid_branch_32b & (pc_in_2 == last_pc_b)));
    assign two_branches_w = ~must_flush & save_branch &(valid_branch_32a & (pc_in_1 == last_pc_a)) &
                           (valid_branch_32b & (pc_in_2 == last_pc_b));*/
    decoder  u_decoder 
    (
        .valid_i            (valid_i            ),
        .ready_o            (ready_o_d          ),//issue ready
        .taken_branch_1     (taken_branch_1     ),
        .pc_in_1            (pc_in_1            ),
        .instruction_in_1   (instruction_in_1   ),
        .taken_branch_2     (taken_branch_2     ),
        .pc_in_2            (pc_in_2            ),
        .instruction_in_2   (instruction_in_2   ),

        .invalid_instruction(invalid_instruction),
        .invalid_prediction (invalid_prediction ),
        .is_return_out      (is_return          ),
        .is_call_out        (is_call            ),
        .old_pc             (old_pc             ),

        .valid_transaction  (valid_transaction  ),
        .valid_branch_32a   (valid_branch_32a   ),
        .valid_branch_32b   (valid_branch_32b   ),

        .ready_i            (ready_i            ),
        .valid_o            (valid_o_d          ),
        .output1            (output1            ),
        .valid_o_2          (valid_o_2_d        ),
        .output2            (output2            )
    );
    always_comb begin
        if(pr_update1.valid_jump & pr_update2.valid_jump) begin
            pr_update_double_branch = 1'b1;
            pr_update_signle_branch = 1'b0;
            if(pr_update1.jump_taken) begin
                branch_num = 1'b0;
                pr_update = pr_update1;
            end
            else if(pr_update2.jump_taken) begin
                branch_num = 1'b1;
                pr_update = pr_update2;
            end
            else begin
                branch_num = 1'b0;
                pr_update = pr_update1;
            end
        end
        else if(pr_update1.valid_jump & ~pr_update2.valid_jump) begin
            branch_num = 1'b0;
            pr_update_double_branch = 1'b0;
            pr_update_signle_branch = 1'b1;
            pr_update = pr_update1;
        end
        else if(~pr_update1.valid_jump & pr_update2.valid_jump) begin
            branch_num = 1'b1;
            pr_update_double_branch = 1'b0;
            pr_update_signle_branch = 1'b1;
            pr_update = pr_update2;
        end
        else begin
            branch_num = 1'b0;
            pr_update_double_branch = 1'b0;
            pr_update_signle_branch = 1'b0; 
            pr_update = pr_update1;
        end
    end
//记录分支指令，分支预测失败时，用记录恢复PC
    flush_controller flush_controller 
    (
        .clk                        (clk                              ),
        .rst_n                      (rst_n                            ),

        .pc_in_1                    (pc_in_1                          ),
        .pc_in_2                    (pc_in_2                          ),

        .valid_transaction          (valid_transaction & ~branch_stall),
        .valid_branch_32a           (valid_branch_32a                 ),
        .valid_transaction_2        (valid_o_2                        ),
        .valid_branch_32b           (valid_branch_32b                 ),

        .pr_update                  (pr_update                        ),
        .branch_num                 (branch_num                       ),    
        .pr_update_double_branch    (pr_update_double_branch          ),
        .pr_update_signle_branch    (pr_update_signle_branch          ),

        .must_flush                 (must_flush                       ),
        .correct_address            (correct_address                  ),
        .rob_ticket                 (rob_ticket                       ),
        .rat_id                     (flush_rat_id                     )
    );
    

    always_ff @(posedge clk or negedge rst_n) begin : BranchInFlight
        if(!rst_n) 
            branch_if <= 0;
        else if(must_flush) 
            branch_if <= 0;
        else if(two_branches && (pc_in_1 != last_pc_a) && (pc_in_2 != last_pc_b) && !branch_stall) begin
            if(~pr_update1.valid_jump & ~pr_update2.valid_jump)
                branch_if <= branch_if + 2;
            else if(pr_update1.valid_jump ^ pr_update2.valid_jump)
                branch_if <= branch_if + 1;
        end 
        else if((((valid_branch_32a) & (pc_in_1 != last_pc_a)) ^ ((valid_branch_32b) & (pc_in_2 != last_pc_b))) && !branch_stall) begin
            if(~pr_update1.valid_jump & ~pr_update2.valid_jump)
                branch_if <= branch_if + 1;
        end 
        else if (pr_update1.valid_jump & pr_update2.valid_jump & |branch_if) begin
            branch_if <= branch_if - 2;
        end
        else if((pr_update1.valid_jump ^ pr_update2.valid_jump) & |branch_if) begin
            branch_if <= branch_if - 1; 
        end
    end

    logic [1:0] branch_id,branch_id1, branch_id2;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            branch_id <= 0;
        else if(two_branches && (pc_in_1 != last_pc_a) && (pc_in_2 != last_pc_b) && !branch_stall)
            branch_id <= branch_id+2;
        else if((((valid_branch_32a) & (pc_in_1 != last_pc_a)) ^ ((valid_branch_32b) & (pc_in_2 != last_pc_b))) && !branch_stall)
            branch_id <= branch_id + 1;
    end
    always_comb begin
        if(two_branches& |branch_if)
            output1_branch_id = branch_id-1;
        else if((((valid_branch_32a) & (pc_in_1 != last_pc_a)) & ~((valid_branch_32b) & (pc_in_2 != last_pc_b))) && !branch_stall)
            output1_branch_id = branch_id;
        else if((~((valid_branch_32a) & (pc_in_1 != last_pc_a)) & ((valid_branch_32b) & (pc_in_2 != last_pc_b))) && !branch_stall & |branch_if)
            output1_branch_id = branch_id-1;
        else 
            output1_branch_id = branch_id;
    end
 
    assign output2_branch_id = branch_id;


endmodule