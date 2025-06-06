module rr
#( 
    parameter VECTOR_ENABLED = 1
)
(
    input   logic                       clk     ,
    input   logic                       rst_n   ,
    //Port towards ID   
    output logic                        ready_o        ,
    input  logic                        valid_i_1      ,
    input  decoded_instr                instruction_1  ,
    input  logic [1:0]                  branch_id1     ,
    input  logic                        valid_i_2      ,
    input  decoded_instr                instruction_2  ,
    input  logic [1:0]                  branch_id2     ,
    //Port towards IS   
    input  logic                        ready_i        ,
    output logic                        valid_o_1      ,
    output renamed_instr                instruction_o_1,
    output logic                        valid_o_2      ,
    output renamed_instr                instruction_o_2,
    //Port towards ROB  
    input  to_issue                     rob_status     ,
    output new_entries                  rob_requests   ,
    //Commit Port   
    input  writeback_toARF              commit_1       ,
    input  writeback_toARF              commit_2       ,
    //Flush Port    
    input  logic                        flush_valid    ,
    input  predictor_update             pr_update      ,
    input  logic                        flush_rat_id   
);

    // #Internal Signals#
    logic [5:0]                         alloc_p_reg_1, alloc_p_reg_2, ppreg_1, ppreg_2, fl_data, fl_data_2;
    logic [5:0]                         instr1_source1_rat, instr1_source2_rat, instr1_source3_rat;
    logic [5:0]                         instr2_source1_rat, instr2_source2_rat, instr2_source3_rat;
    logic                               current_id;
    logic                               do_alloc_1, do_alloc_2;
    logic                               fl_ready, fl_push, fl_push_2, fl_valid_1, fl_valid_2;
    logic                               instr_a_rd_rename, instr_a_s1_rename, instr_a_s2_rename, instr_a_s3_rename;
    logic                               instr_b_rd_rename, instr_b_s1_rename, instr_b_s2_rename, instr_b_s3_rename;
    logic                               instruction_o_1_vmv_x_s, instruction_o_1_vector_need_rd;
    logic                               instruction_o_2_vmv_x_s, instruction_o_2_vector_need_rd;
    logic                               dual_branch,single_branch;
    logic                               instra_is_store,instrb_is_store,instra_is_csr,instrb_is_csr;
    logic                               is_maccvx_1,is_maccvx_2;
    assign instra_is_csr     = instruction_1.functional_unit==2'b01;
    assign instra_is_store   = (instruction_1.functional_unit==2'b00) & ((instruction_1.microoperation == 5'b01000) | (instruction_1.microoperation == 5'b00111) | (instruction_1.microoperation == 5'b00110));
   
    generate 
        if(VECTOR_ENABLED) begin
            assign instr_a_rd_rename            = instruction_1.is_vector ? (instruction_o_1.is_vector_cfg | instruction_o_1_vector_need_rd)  : |instruction_1.destination;
            assign instr_a_s1_rename            = instruction_1.is_vector ? (instruction_o_1.is_vector_cfg | instruction_o_1.vector_need_rs1) : |instruction_1.source1;
            assign instr_a_s2_rename            = instruction_1.is_vector ? (instruction_o_1.is_vector_cfg | instruction_o_1.vector_need_rs2) : |instruction_1.source2;
            assign instr_b_rd_rename            = instruction_2.is_vector ? (instruction_o_2.is_vector_cfg | instruction_o_2_vector_need_rd)  : |instruction_2.destination;
            assign instr_b_s1_rename            = instruction_2.is_vector ? (instruction_o_2.is_vector_cfg | instruction_o_2.vector_need_rs1) : |instruction_2.source1;
            assign instr_b_s2_rename            = instruction_2.is_vector ? (instruction_o_2.is_vector_cfg | instruction_o_2.vector_need_rs2) : |instruction_2.source2;
            assign instruction_o_2.ticket       = (instruction_1.is_vector & ~instruction_o_1.is_vector_cfg) ? rob_status.ticket :  rob_status.ticket+1;
            assign rob_requests.valid_request_1 = valid_o_1 & ((instruction_1.is_vector & instruction_o_1.is_vector_cfg) | ~instruction_1.is_vector);
            assign rob_requests.valid_request_2 = ((instruction_1.is_vector & ~instruction_o_1.is_vector_cfg) ? valid_o_2 & ((instruction_2.is_vector & instruction_o_2.is_vector_cfg) | ~instruction_2.is_vector) : rob_requests.valid_request_1 & valid_o_2 & ((instruction_2.is_vector & instruction_o_2.is_vector_cfg) | ~instruction_2.is_vector)); 
        end
        else begin
            assign instr_a_rd_rename            = |instruction_1.destination;
            assign instr_a_s1_rename            = |instruction_1.source1;
            assign instr_a_s2_rename            = |instruction_1.source2;
            assign instr_b_rd_rename            = |instruction_2.destination;
            assign instr_b_s1_rename            = |instruction_2.source1;
            assign instr_b_s2_rename            = |instruction_2.source2;
            assign instruction_o_2.ticket       = rob_status.ticket+1;
            assign rob_requests.valid_request_1 = valid_o_1;
            assign rob_requests.valid_request_2 = rob_requests.valid_request_1 & valid_o_2;
        end
    endgenerate
//scalar
    assign instruction_o_1.pc                = instruction_1.pc;
    assign instruction_o_1.source1_pc        = instruction_1.source1_pc;
    assign instruction_o_1.source2_immediate = instruction_1.source2_immediate;
    assign instruction_o_1.immediate         = instruction_1.immediate;
    assign instruction_o_1.functional_unit   = instruction_1.functional_unit;
    assign instruction_o_1.microoperation    = instruction_1.microoperation;
    assign instruction_o_1.is_branch         = instruction_1.is_branch;
    assign instruction_o_1.is_call           = instruction_1.is_call;
    assign instruction_o_1.is_valid          = instruction_1.is_valid;
    assign instruction_o_1.rat_id            = current_id;
    assign instruction_o_1.source1           = !instr_a_s1_rename ? instruction_1.source1 : instr1_source1_rat;
    assign instruction_o_1.source2           = !instr_a_s2_rename ? instruction_1.source2 : instr1_source2_rat;
    assign instruction_o_1.destination       = !instr_a_rd_rename ? instruction_1.destination : alloc_p_reg_1;
    assign instruction_o_1.ticket            = rob_status.ticket;//指令在ROB中的位置
    assign instruction_o_1.branch_id         = branch_id1;
    assign instruction_o_1.csr_addr          = instruction_1.csr_addr;
    assign instruction_o_1.csr_imm          = instruction_1.csr_imm;
//vector
    assign instruction_o_1.logic_source1     = instruction_1.source1;
    assign instruction_o_1.logic_source2     = instruction_1.source2;
    assign instruction_o_1.is_vector         = instruction_1.is_vector;
    //vsetvli vsetvl need rs1
    assign instruction_o_1.vl_in_source1     = ((instruction_1.functional_unit == 2'b01) & ((instruction_1.microoperation==5'b10000) | (instruction_1.microoperation==5'b10001))) ?
                                               |instruction_1.source1 : 1'b0;
    always_comb begin
        case(1'b1)
            instruction_o_1.vsetvli  : begin
                if((instruction_1.source1=='d0) & (instruction_1.destination=='d0))
                    instruction_o_1.vector_config_wrd = 1'b0;
                else
                    instruction_o_1.vector_config_wrd = 1'b1;
            end
            instruction_o_1.vsetvl   : begin
                if((instruction_1.source1=='d0) & (instruction_1.destination=='d0))
                    instruction_o_1.vector_config_wrd = 1'b0;
                else
                    instruction_o_1.vector_config_wrd = 1'b1;
            end
            instruction_o_1.vsetivli : begin
                instruction_o_1.vector_config_wrd = 1'b1;
            end
            default : instruction_o_1.vector_config_wrd = 1'b0;
        endcase
    end
    assign is_maccvx_1                       = (instruction_1.functional_unit == 2'b10) & instruction_1.is_vector & instruction_1.microoperation==5'b11010;
    assign instruction_o_1.is_vector_cfg     = (instruction_1.functional_unit == 2'b01) & instruction_1.is_vector;
    assign instruction_o_1.vsetvli           = (instruction_1.functional_unit == 2'b01) & instruction_1.is_vector & (instruction_1.microoperation==5'b10000);
    assign instruction_o_1.vsetvl            = (instruction_1.functional_unit == 2'b01) & instruction_1.is_vector & (instruction_1.microoperation==5'b10001);
    assign instruction_o_1.vsetivli          = (instruction_1.functional_unit == 2'b01) & instruction_1.is_vector & (instruction_1.microoperation==5'b10010);
    assign instruction_o_1.is_vmacc          = (instruction_1.functional_unit == 2'b10) & instruction_1.is_vector & ((instruction_1.microoperation==5'b11010)|(instruction_1.microoperation==5'b01011));
    assign instruction_o_1.vector_need_rs1   = instruction_1.is_vector & ((instruction_1.functional_unit == 2'b00) | instruction_1.opivx | is_maccvx_1);
    assign instruction_o_1.vector_need_rs2   = instruction_1.is_vector & ((instruction_1.functional_unit == 2'b00) & ((instruction_1.microoperation == 5'b00001) 
                                             |(instruction_1.microoperation == 5'b00101)));
    assign instruction_o_1_vmv_x_s           = (instruction_1.functional_unit==2'b10) & instruction_1.is_vector & (instruction_1.microoperation == 5'b11001);
    assign instruction_o_1_vector_need_rd    = instruction_1.is_vector & instruction_o_1_vmv_x_s;
    assign instruction_o_1.vls_width         = instruction_1.vls_width;                    
    assign instrb_is_csr     = instruction_2.functional_unit==2'b01;
    assign instrb_is_store   = (instruction_2.functional_unit==2'b00) & ((instruction_2.microoperation == 5'b01000) | (instruction_2.microoperation == 5'b00111) | (instruction_2.microoperation == 5'b00110));

    assign instruction_o_2.pc                = instruction_2.pc;
    assign instruction_o_2.source1_pc        = instruction_2.source1_pc;
    assign instruction_o_2.source2_immediate = instruction_2.source2_immediate;
    assign instruction_o_2.immediate         = instruction_2.immediate;
    assign instruction_o_2.functional_unit   = instruction_2.functional_unit;
    assign instruction_o_2.microoperation    = instruction_2.microoperation;
//vector
    assign instruction_o_2.logic_source1     = instruction_2.source1;
    assign instruction_o_2.logic_source2     = instruction_2.source2;
    assign instruction_o_2.is_vector         = instruction_2.is_vector;
    //vsetvli vsetvl need rs1
    assign instruction_o_2.vl_in_source1     = ((instruction_2.functional_unit == 2'b01) & ((instruction_2.microoperation==5'b10000) | (instruction_2.microoperation==5'b10001))) ?
                                               |instruction_2.source1 : 1'b0;
    always_comb begin
        case(1'b1)
            instruction_o_2.vsetvli  : begin
                if((instruction_2.source1=='d0) & (instruction_2.destination=='d0))
                    instruction_o_2.vector_config_wrd = 1'b0;
                else
                    instruction_o_2.vector_config_wrd = 1'b1;
            end
            instruction_o_2.vsetvl   : begin
                if((instruction_2.source1=='d0) & (instruction_2.destination=='d0))
                    instruction_o_2.vector_config_wrd = 1'b0;
                else
                    instruction_o_2.vector_config_wrd = 1'b1;
            end
            instruction_o_2.vsetivli : begin
                instruction_o_2.vector_config_wrd = 1'b1;
            end
            default : instruction_o_2.vector_config_wrd = 1'b0;
        endcase
    end

    assign is_maccvx_2                       = (instruction_1.functional_unit == 2'b10) & instruction_1.is_vector & instruction_1.microoperation==5'b11010;
    assign instruction_o_2.is_vector_cfg     = (instruction_2.functional_unit == 2'b01) & instruction_2.is_vector;
    assign instruction_o_2.vsetvli           = (instruction_2.functional_unit == 2'b01) & instruction_2.is_vector & (instruction_2.microoperation==5'b10000);
    assign instruction_o_2.vsetvl            = (instruction_2.functional_unit == 2'b01) & instruction_2.is_vector & (instruction_2.microoperation==5'b10001);
    assign instruction_o_2.vsetivli          = (instruction_2.functional_unit == 2'b01) & instruction_2.is_vector & (instruction_2.microoperation==5'b10010);
    assign instruction_o_2.is_vmacc          = (instruction_2.functional_unit == 2'b10) & instruction_2.is_vector & ((instruction_2.microoperation==5'b11010)|(instruction_2.microoperation==5'b01011));
    assign instruction_o_2.vector_need_rs1   = instruction_2.is_vector & ((instruction_2.functional_unit == 2'b00) | instruction_2.opivx | is_maccvx_2);
    assign instruction_o_2.vector_need_rs2   = instruction_2.is_vector & ((instruction_2.functional_unit == 2'b00) & ((instruction_2.microoperation == 5'b00001) | (instruction_2.microoperation == 5'b00101)));
    assign instruction_o_2_vmv_x_s           = (instruction_2.functional_unit == 2'b10) & instruction_2.is_vector & (instruction_2.microoperation==5'b01011);
    assign instruction_o_2_vector_need_rd    = instruction_2.is_vector & instruction_o_2_vmv_x_s;
    assign instruction_o_2.vls_width         = instruction_2.vls_width;     
    assign instruction_o_2.is_branch         = instruction_2.is_branch;
    assign instruction_o_2.is_call           = instruction_2.is_call;
    assign instruction_o_2.is_valid          = instruction_2.is_valid;
    assign instruction_o_2.rat_id            = instruction_1.is_branch ? current_id+1 : current_id;

    assign instruction_o_2.branch_id         = branch_id2;
    assign instruction_o_2.csr_addr          = instruction_2.csr_addr;
    assign instruction_o_2.csr_imm           = instruction_2.csr_imm;
//--------------------------RAW---------------------------//
    //Create the Instr #2 source1
    always_comb begin
        if((instruction_2.source1 == instruction_1.destination) & ~instruction_1.is_vector & ~instra_is_store)begin
            instruction_o_2.source1 = instruction_o_1.destination;
        end else if(instr_b_s1_rename) begin
            instruction_o_2.source1 = instr2_source1_rat;
        end else begin
            instruction_o_2.source1 = instruction_2.source1;
        end
    end
    //Create the Instr #2 source2
    always_comb begin
        if((instruction_2.source2 == instruction_1.destination) & ~instruction_1.is_vector & ~instra_is_store)begin
            instruction_o_2.source2 = instruction_o_1.destination;
        end else if(instr_b_s2_rename) begin
            instruction_o_2.source2 = instr2_source2_rat;
        end else begin
            instruction_o_2.source2 = instruction_2.source2;
        end
    end
//--------------------------WAW---------------------------//
    //Create the Instr #2 destination
    always_comb begin 
        if (instr_a_rd_rename && instr_b_rd_rename) begin
            instruction_o_2.destination = alloc_p_reg_2;
        end else if (!instr_a_rd_rename && instr_b_rd_rename) begin
            instruction_o_2.destination = alloc_p_reg_1;
        end else begin
            instruction_o_2.destination = instruction_2.destination;
        end
    end
    
//add 
//1.inst1 inst2同时为vector都不写 
//2.inst1是vector inst2不是vector 端口1使能 端口2不使能 inst2通过端口1写
//3.inst2是vector inst1不是vector 端口1使能 端口2不使能
    //New ROB Requests to reserve entries
    assign rob_requests.valid_dest_1        = |instruction_o_1.destination;
    assign rob_requests.csr_store_pending_1 = instra_is_store | instra_is_csr;
    assign rob_requests.lreg_1              = instruction_1.destination;
    assign rob_requests.preg_1              = instruction_o_1.destination;
    assign rob_requests.ppreg_1             = ppreg_1;
    assign rob_requests.is_branch_1         = instruction_1.is_branch;
    assign rob_requests.is_store_1          = instruction_1.is_store;
    assign rob_requests.microoperation_1    = instruction_1.microoperation;
    assign rob_requests.pc_1                = instruction_1.pc;
    assign rob_requests.csr_1               = instra_is_csr;
   // assign rob_requests.csr_addr_1       = instruction_1.csr_addr;
    assign rob_requests.valid_dest_2        = |instruction_o_2.destination;
    assign rob_requests.csr_store_pending_2 = instrb_is_store | instrb_is_csr;
    assign rob_requests.lreg_2              = instruction_2.destination;
    assign rob_requests.preg_2              = instruction_o_2.destination;
    assign rob_requests.ppreg_2             = (instruction_1.destination == instruction_2.destination) ? instruction_o_1.destination : ppreg_2;
    assign rob_requests.is_branch_2         = instruction_2.is_branch;
    assign rob_requests.is_store_2          = instruction_2.is_store;
    assign rob_requests.microoperation_2    = instruction_2.microoperation;
    assign rob_requests.pc_2                = instruction_2.pc;
    assign rob_requests.csr_2               = instrb_is_csr;
    //assign rob_requests.csr_addr_2       = instruction_2.csr_addr;
    //Control Flow
    assign ready_o = valid_o_1 | flush_valid;
    always_comb begin
        if(valid_i_1 && valid_i_2) begin
            if(instr_a_rd_rename && instr_b_rd_rename) begin
                valid_o_1     = ready_i & fl_valid_1 & fl_valid_2 & ~flush_valid & ~rob_status.is_full & rob_status.two_empty;
            end else if(instr_a_rd_rename || instr_b_rd_rename) begin
                valid_o_1     = ready_i & fl_valid_1 & ~flush_valid & ~rob_status.is_full & rob_status.two_empty;
            end else begin
                valid_o_1     = ready_i & ~flush_valid & ~rob_status.is_full & rob_status.two_empty;
            end
            valid_o_2 = valid_o_1;
        end else if(valid_i_1 && !valid_i_2) begin
            if(instr_a_rd_rename)
                valid_o_1     = ready_i & fl_valid_1 & ~flush_valid & ~rob_status.is_full; 
            else
                valid_o_1     = ready_i & ~flush_valid & ~rob_status.is_full;
            valid_o_2     = 1'b0;
        end else begin
            valid_o_1     = 1'b0;
            valid_o_2     = 1'b0;
        end
    end
    //Do new preg allocations
    assign do_alloc_1 = valid_o_1 & instr_a_rd_rename;
    assign do_alloc_2 = valid_o_2 & instr_b_rd_rename;
    //Free List
    assign fl_push = commit_1.valid_commit & |commit_1.ldst;
    assign fl_data = commit_1.flushed ? commit_1.pdst : commit_1.ppdst;
    //assign fl_data = ~commit_1.flushed ? commit_1.pdst : commit_1.ppdst;
    assign fl_push_2 = commit_2.valid_commit & |commit_2.ldst;
    assign fl_data_2 = commit_2.flushed ? commit_2.pdst : commit_2.ppdst;
    //assign fl_data_2 = ~commit_2.flushed ? commit_2.pdst : commit_2.ppdst;
    free_list u_free_list
    (
        .clk                (clk          ),
        .rst_n              (rst_n        ),
        //Reclaim Interface
        .push_data          (fl_data      ),
        .push               (fl_push      ),
        .push_data_2        (fl_data_2    ),
        .push_2             (fl_push_2    ),
        .ready              (fl_ready     ),
        //Alloc First Dest
        .pop_data_1         (alloc_p_reg_1),
        .valid_1            (fl_valid_1   ),
        .pop_1              (do_alloc_1   ),
        //Alloc Second Dest
        .pop_data_2         (alloc_p_reg_2),
        .valid_2            (fl_valid_2   ),
        .pop_2              (do_alloc_2   )
    );
    //RAT (DecodeRAT & CheckpointedRAT)
    logic                   rat_alloc_1, rat_alloc_2, take_checkpoint, instr_num;
    logic [4:0]             rat_allo_addr_1;

    assign rat_alloc_1     = (valid_o_1 & instr_a_rd_rename) | (valid_o_1 & valid_o_2 & ~instr_a_rd_rename & instr_b_rd_rename);
    assign rat_allo_addr_1 = instr_a_rd_rename ? instruction_1.destination[4:0] : instruction_2.destination[4:0];
    assign rat_alloc_2     = (valid_o_1 & valid_o_2 & instr_a_rd_rename & instr_b_rd_rename);

    assign take_checkpoint = (instruction_1.is_branch & valid_i_1 & valid_o_1) | (instruction_2.is_branch & valid_i_2 & valid_o_2);
    assign single_branch   = (instruction_1.is_branch & valid_i_1) ^ (instruction_2.is_branch & valid_i_2);
    assign dual_branch     = (instruction_1.is_branch & valid_i_1) & (instruction_2.is_branch & valid_i_2);
    assign instr_num       = instruction_2.is_branch;
    rat u_rat 
    (
        .clk            (clk                           ),
        .rst_n          (rst_n                         ),

        .write_en_1     (rat_alloc_1                   ),
        .write_addr_1   (rat_allo_addr_1               ),
        .write_data_1   (alloc_p_reg_1                 ),
        .instr_1_rn     (instr_a_rd_rename             ),

        .write_en_2     (rat_alloc_2                   ),
        .write_addr_2   (instruction_2.destination[4:0]),
        .write_data_2   (alloc_p_reg_2                 ),
        .instr_2_rn     (instr_b_rd_rename             ),

        .read_addr_1    (instruction_1.source1[4:0]    ),
        .read_data_1    (instr1_source1_rat            ),

        .read_addr_2    (instruction_1.source2[4:0]    ),
        .read_data_2    (instr1_source2_rat            ),

        .read_addr_3    (instruction_2.source1[4:0]    ),
        .read_data_3    (instr2_source1_rat            ),

        .read_addr_4    (instruction_2.source2[4:0]    ),
        .read_data_4    (instr2_source2_rat            ),

        .read_addr_5    (instruction_1.destination[4:0]),
        .read_data_5    (ppreg_1                       ),

        .read_addr_6    (instruction_2.destination[4:0]),
        .read_data_6    (ppreg_2                       ),

        .take_checkpoint(take_checkpoint               ),
        .instr_num      (instr_num                     ),
        .single_branch  (single_branch                 ),
        .dual_branch    (dual_branch                   ),
        .current_id     (current_id                    ),

        .restore_rat    (flush_valid                   ),
        .restore_id     (flush_rat_id                  )
    );

endmodule