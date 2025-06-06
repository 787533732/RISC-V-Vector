module vmu_ld_eng
#(
    parameter   REQ_DATA_WIDTH     = 256,//D-Cache Cacheline
    parameter   ADDR_WIDTH         = 32 ,
    parameter   VECTOR_LANES       = 8  ,
    parameter   VECTOR_TICKET_BITS = 4  ,
    parameter   MICROOP_WIDTH      = 5  
)
(
    input   logic                               clk                 ,
    input   logic                               rst_n               ,

    input   logic                               valid_in            ,
    input   to_vmu                              instr_in            ,
    output  logic                               ready_o             ,
    //VRF read Interface(for `OP_INDEXED stride)    
    output logic [4:0]                          rd_addr_o           ,//vs2
    input  logic [32*VECTOR_LANES-1:0]          rd_data_i           ,
    input  logic                                rd_pending_i        ,
    input  logic [VECTOR_TICKET_BITS-1:0]       rd_ticket_i         ,
    //RF write Interface    
    output logic                                wrtbck_req_o        ,
    input  logic                                wrtbck_grant_i      ,
    output logic [VECTOR_LANES-1:0]             wrtbck_en_o         ,
    output logic [4:0]                          wrtbck_reg_o        ,
    output logic [32*VECTOR_LANES-1:0]          wrtbck_data_o       ,
    output logic [VECTOR_TICKET_BITS-1:0]       wrtbck_ticket_o     ,
    //RF Writeback Probing Interface（目的寄存器是否被锁住）
    output logic [4:0]                          wrtbck_reg_a_o      ,
    input  logic                                wrtbck_locked_a_i   ,
    input  logic [      VECTOR_TICKET_BITS-1:0] wrtbck_ticket_a_i   ,
    output logic [4:0]                          wrtbck_reg_b_o      ,
    input  logic                                wrtbck_locked_b_i   ,
    input  logic [      VECTOR_TICKET_BITS-1:0] wrtbck_ticket_b_i   ,
    //Unlock Interface
    output logic                                unlock_en_o         ,
    output logic [4:0]                          unlock_reg_a_o      ,
    output logic [4:0]                          unlock_reg_b_o      ,
    output logic [      VECTOR_TICKET_BITS-1:0] unlock_ticket_o     ,
    //Request Interface Towards D-Cache
    input  logic                                grant_i             ,
    output logic                                req_en_o            ,
    output logic [              ADDR_WIDTH-1:0] req_addr_o          ,
    output logic [           MICROOP_WIDTH-1:0] req_microop_o       ,
    output logic [  $clog2(REQ_DATA_WIDTH/8):0] req_size_o          ,
    output logic [$clog2(VECTOR_LANES)+2:0] req_ticket_o        ,
    // Incoming Data from Cache 
    input  logic                                resp_valid_i        ,
    input  logic [$clog2(VECTOR_LANES)+2:0] resp_ticket_i       ,
    input  logic [  $clog2(REQ_DATA_WIDTH/8):0] resp_size_i         ,
    input  logic [          REQ_DATA_WIDTH-1:0] resp_data_i         ,
    //Sync Interface
    output logic                                is_busy_o          ,
    output logic                                can_be_inteleaved_o,
    output logic [ADDR_WIDTH-1:0]               start_addr_o       ,
    output logic [ADDR_WIDTH-1:0]               end_addr_o 
);
    localparam ELEMENT_ADDR_WIDTH = $clog2(VECTOR_LANES)+2;
    localparam MAX_MEM_SERVED_LIMIT = REQ_DATA_WIDTH/8;
    localparam MAX_SERVED_COUNT   = (MAX_MEM_SERVED_LIMIT < 32) ? MAX_MEM_SERVED_LIMIT : 32;
    localparam [1:0] OP_UNIT_STRIDED = 2'b00;
    localparam [1:0] OP_STRIDED      = 2'b01;
    localparam [1:0] OP_INDEXED      = 2'b10;
    localparam [2:0] SZ_8            = 3'b000;
    localparam [2:0] SZ_16           = 3'b101;
    localparam [2:0] SZ_32           = 3'b110;

    //=====================================
    // REGISTERS
    //=====================================
    logic [1:0][32*VECTOR_LANES-1:0]    scratchpad;
    logic [1:0][4*VECTOR_LANES-1:0]     pending_elem        ;
    logic [4*VECTOR_LANES-1:0]          nxt_pending_elem        ;
    logic [4*VECTOR_LANES-1:0]          nxt_pending_elem_loop   ;
    logic [1:0][4*VECTOR_LANES-1:0]     served_elem         ;
    logic [1:0][4*VECTOR_LANES-1:0]     active_elem         ;
    logic [MICROOP_WIDTH-1:0]           microop_r           ;
    logic [VECTOR_TICKET_BITS-1:0]      ticket_r            ;
    logic [4:0]                         src2_r              ;
    logic [4:0]                         rdst_r              ;
    logic [4:0]                         last_ticket_src2_r  ;
    logic [$clog2(32*VECTOR_LANES):0]   instr_vl_r          ;
    logic [4:0]                         current_exp_loop_r  ;
    logic [4:0]                         max_expansion_r     ;
    logic [ELEMENT_ADDR_WIDTH-1:0]      current_pointer_wb_r;
    logic [ADDR_WIDTH-1:0]              current_addr_r      ;
    logic [ADDR_WIDTH-1:0]              base_addr_r         ;
    logic [ADDR_WIDTH-1:0]              stride_r            ;
    logic [2:0]                         size_r              ;
    logic [1:0]                         memory_op_r         ;
    logic [ADDR_WIDTH-1:0]              start_addr_r        ;
    logic [ADDR_WIDTH-1:0]              end_addr_r          ;
    logic                               current_row         ;
    logic [4:0]                         row_0_rdst          ;
    logic [4:0]                         row_1_rdst          ;
    logic [4:0]                         row_0_src           ;
    logic [4:0]                         row_1_src           ;
    //=====================================
    // WIRES
    // =====================================
    // logic [REQ_DATA_WIDTH-1:0]           data_selected           ;
    logic [$clog2(32*VECTOR_LANES):0]       total_remaining_elements    ;
    logic [$clog2(32*VECTOR_LANES):0]       nxt_total_remaining_elements;
    logic [ELEMENT_ADDR_WIDTH:0]            loop_remaining_elements ;
    logic [$clog2(VECTOR_LANES*32)-1:0]     element_index           ;
    logic [ELEMENT_ADDR_WIDTH-1:0]          nxt_elem                ;
    logic [ELEMENT_ADDR_WIDTH:0]            el_served_count         ;
    logic [ELEMENT_ADDR_WIDTH:0]            resp_el_count           ;
    logic [VECTOR_LANES*32-1:0]             data_vector             ;
    logic [VECTOR_LANES:0]                  current_pointer_oh      ;
    logic [4*VECTOR_LANES:0]                current_served_th       ;
    logic [4*VECTOR_LANES:0]                resp_elem_th            ;
    logic [ADDR_WIDTH-1:0]                  nxt_base_addr           ;
    logic [ADDR_WIDTH-1:0]                  nxt_strided_addr        ;
    logic [ADDR_WIDTH-1:0]                  nxt_unit_strided_addr   ;
    logic [ADDR_WIDTH-1:0]                  current_addr            ;
    logic [ADDR_WIDTH-1:0]                  nxt_stride              ;
    logic [ADDR_WIDTH-1:0]                  offset_read             ;

    logic [MAX_SERVED_COUNT*32-1:0]         unpacked_data           ;
    logic [1:0]                             nxt_memory_op           ;
    logic [2:0]                             nxt_size                ;
    logic                                   start_new_instruction   ;
    logic                                   maxvl_reached           ;
    logic                                   vl_reached              ;
    logic                                   do_reconfigure          ;
    logic                                   current_finished        ;
    logic                                   currently_idle          ;
    logic                                   multi_valid             ;
    logic                                   expansion_finished      ;
    logic                                   addr_ready              ;
    logic                                   start_new_loop          ;
    logic                                   new_transaction_en      ;
    logic                                   request_ready           ;
    logic                                   resp_row                ;
    logic                                   writeback_complete      ;
    logic                                   row_0_ready             ;
    logic                                   row_1_ready             ;
    logic                                   nxt_row                 ;
    logic                                   writeback_row           ;
    logic                                   unlock_source           ;
    logic                                   unlock_dest             ;
    // Create basic control flow
    //=====================================
    assign ready_o             =  currently_idle;
    assign is_busy_o           = ~currently_idle;
    assign can_be_inteleaved_o = (memory_op_r != OP_INDEXED);//don't need vs2
    //current instruction finished
    assign current_finished = ~pending_elem[current_row][nxt_elem] & expansion_finished & new_transaction_en;
    //currently no instructions are being served
    assign currently_idle = ~|pending_elem & ~|active_elem;

    assign expansion_finished = maxvl_reached | vl_reached;
    assign maxvl_reached      = (current_exp_loop_r == (max_expansion_r-1));

    always_comb begin
        unique case (size_r)
            SZ_8    : vl_reached = (((current_exp_loop_r+1) << $clog2(4*VECTOR_LANES)) >= instr_vl_r);
            SZ_16   : vl_reached = (((current_exp_loop_r+1) << $clog2(2*VECTOR_LANES)) >= instr_vl_r);
            SZ_32   : vl_reached = (((current_exp_loop_r+1) << $clog2(VECTOR_LANES)) >= instr_vl_r);
            default : vl_reached = (((current_exp_loop_r+1) << $clog2(VECTOR_LANES)) >= instr_vl_r);
        endcase
    end

    assign start_new_instruction = valid_in & ready_o & ~instr_in.reconfigure;
    assign do_reconfigure        = valid_in & ready_o & instr_in.reconfigure;
    // Start from element 0 on the next destination vreg
    assign start_new_loop = ~|pending_elem[current_row] & ~expansion_finished & ~|active_elem[nxt_row];

    // Create the memory request control signals
    assign req_en_o      = request_ready;
    assign req_addr_o    = current_addr;
    assign req_microop_o = 5'b10000; //REVISIT will change based on instruction
    assign req_ticket_o  = {current_row,current_pointer_wb_r};
    always_comb begin
        unique case (size_r)
            SZ_8    : req_size_o = el_served_count;      //e8
            SZ_16   : req_size_o = (el_served_count); //e16
            SZ_32   : req_size_o = (el_served_count); //e32
            default : req_size_o = 'x;
        endcase
    end
    assign new_transaction_en = req_en_o & grant_i;//D-Cache准备好返回数据？
    assign request_ready      = addr_ready & pending_elem[current_row][current_pointer_wb_r];
    //index需要VS2，先判断地址是否已经计算出来
    assign addr_ready         = (memory_op_r == OP_INDEXED) ? ~rd_pending_i & ((rd_ticket_i == ticket_r) | (rd_ticket_i == last_ticket_src2_r)) : 1'b1;

    // Unlock register signals
    assign unlock_en_o     = writeback_complete;
    assign unlock_ticket_o = ticket_r;
    assign unlock_reg_a_o  = row_0_ready ? row_0_rdst : row_1_rdst;
    assign unlock_reg_b_o  = row_0_ready ? row_0_src  : row_1_src;

    // Create the writeback signals for the RF
    assign wrtbck_req_o       = row_0_ready | row_1_ready;
    assign writeback_complete = (row_0_ready | row_1_ready) & wrtbck_grant_i;
    assign writeback_row      = row_0_ready ? 1'b0 : 1'b1;
    assign row_0_ready = ~|(active_elem[0] ^ served_elem[0]) & |active_elem[0] & (wrtbck_ticket_a_i == ticket_r) & wrtbck_locked_a_i;
    assign row_1_ready = ~|(active_elem[1] ^ served_elem[1]) & |active_elem[1] & (wrtbck_ticket_b_i == ticket_r) & wrtbck_locked_b_i;

    // Output aliasing
    assign wrtbck_en_o     = row_0_ready ? {VECTOR_LANES{writeback_complete}} & served_elem[0] :
                                           {VECTOR_LANES{writeback_complete}} & served_elem[1];
    assign wrtbck_data_o   = row_0_ready ? scratchpad[0] : scratchpad[1];
    assign wrtbck_reg_o    = row_0_ready ? row_0_rdst    : row_1_rdst;
    assign wrtbck_ticket_o = ticket_r;
    assign wrtbck_reg_a_o  = row_0_rdst;
    assign wrtbck_reg_b_o  = row_1_rdst;

    assign rd_addr_o    = src2_r;
    assign start_addr_o = start_addr_r;
    assign end_addr_o   = end_addr_r;
    //=====================================
    //访存地址
    //=====================================
    assign multi_valid   = (memory_op_r == OP_UNIT_STRIDED);
    assign element_index = current_pointer_wb_r;
    assign offset_read   = rd_data_i[element_index +: 32];//index指令根据VS2的值访存
    // Generate next non-multi consecutive address
    always_comb begin
        case (memory_op_r)
            OP_UNIT_STRIDED : current_addr = current_addr_r;
            OP_STRIDED      : current_addr = current_addr_r;
            OP_INDEXED      : current_addr = base_addr_r + offset_read;
            default         : current_addr = 'X;
        endcase
    end

    assign nxt_base_addr    = instr_in.data1 + instr_in.immediate;//是否需要imm?
    assign nxt_strided_addr = current_addr_r + stride_r;
    //unit_stride 访问地址的更新（递增）
    always_comb begin
        unique case (size_r)//访存时为字节寻址
            SZ_8    : nxt_unit_strided_addr = current_addr_r + el_served_count;       //el_served_count * 1  
            SZ_16   : nxt_unit_strided_addr = current_addr_r + el_served_count;//el_served_count * 2
            SZ_32   : nxt_unit_strided_addr = current_addr_r + el_served_count;//el_served_count * 4
            default : nxt_unit_strided_addr = 'X;
        endcase
    end

//一条LOAD指令可能需要多个周期才能完成，需要在指令开始执行时保存信息
    //Hold current address
    always_ff @(posedge clk) begin
        if(start_new_instruction) begin
            current_addr_r <= nxt_base_addr;
        end else if(new_transaction_en && memory_op_r == OP_STRIDED) begin
            current_addr_r <= nxt_strided_addr;
        end else if(new_transaction_en && memory_op_r == OP_UNIT_STRIDED) begin
            current_addr_r <= nxt_unit_strided_addr;
        end
    end
    //Hold base address
    always_ff @(posedge clk) begin
        if(start_new_instruction) begin
            base_addr_r <= nxt_base_addr;
        end
    end
    //Hold stride
    assign nxt_stride = instr_in.data2;
    always_ff @(posedge clk) begin
        if(start_new_instruction) begin
            stride_r <= nxt_stride;
        end
    end
    //Hold mem op size
    assign nxt_size = instr_in.vls_width;
    always_ff @(posedge clk) begin
        if(start_new_instruction) 
            size_r <= nxt_size;
    end
    //=====================================
    // Scratchpad maintenance
    //=====================================
    assign resp_row = resp_ticket_i[$clog2(VECTOR_LANES)+2];
    // Calculate the elements that have a valid response
    always_comb begin
        unique case (size_r)
            SZ_8   : resp_el_count = resp_size_i;      //el_served_count * 1
            SZ_16  : resp_el_count = resp_size_i /*>> 1*/; //el_served_count * 2
            SZ_32  : resp_el_count = resp_size_i /*>> 2*/; //el_served_count * 4
            default : resp_el_count = 'x;
        endcase
    end
    assign resp_elem_th = (memory_op_r == OP_UNIT_STRIDED) ? ((~('1 << resp_el_count)) << resp_ticket_i[$clog2(VECTOR_LANES)-1:0]) : (1 << resp_ticket_i[ELEMENT_ADDR_WIDTH-1:0]);
    
    // Unpack the data into elements
    always_comb begin
        unpacked_data = '0;
        if(multi_valid) begin
            unique case (size_r)
                    SZ_8 : begin
                        for (int i = 0; i < MAX_SERVED_COUNT; i++) begin
                            unpacked_data[i*8+:8]    = resp_data_i[i*8 +:8];  //pick 8bits for each elem
                            //unpacked_data[i*8+8+:24] = 24'b0;                  // pad with 0s per ISA
                        end
                    end
                    SZ_16 : begin
                        for (int i = 0; i < (MAX_SERVED_COUNT/2); i++) begin
                        unpacked_data[i*16+:16]    = resp_data_i[i*16 +:16]; //pick 16bits for each elem
                        //unpacked_data[i*8+8+:24] = 24'b0;                  // pad with 0s per ISA
                        end
                    end
                    SZ_32 : begin
                        for (int i = 0; i < (MAX_SERVED_COUNT/4); i++) begin
                            unpacked_data[i*32+:32] = resp_data_i[i*32 +:32];    //pick 32bits for each elem
                            //unpacked_data[i*8+8+:24] = 24'b0;                  // pad with 0s per ISA
                        end
                    end
                    default : begin
                        for (int i = 0; i < (MAX_SERVED_COUNT/4); i++) begin
                            unpacked_data[i*32+:32] = 'X;
                        end
                    end
            endcase
        end
        else begin
            unpacked_data[0+:32] = resp_data_i[0 +: 32];
        end
    end

    // Shift unpacked data vector to match the elements positions
    assign data_vector = unpacked_data << (resp_ticket_i[$clog2(VECTOR_LANES)-1:0] * 32);
    // Store new Data
    always_ff @(posedge clk) begin
        for (int i = 0; i < 4*VECTOR_LANES; i++) begin
            // row 0 maintenance
            if(resp_valid_i && !resp_row && resp_elem_th[i]) begin
                scratchpad[0][i*8 +: 8] <= data_vector[i*8 +: 8];
            end
            else begin
                scratchpad[0][i*8 +: 8] <= 8'b0;
            end
        end
    end
    always_ff @(posedge clk) begin
        for (int i = 0; i < 4*VECTOR_LANES; i++) begin
            // row 1 maintenance
            if(resp_valid_i && resp_row && resp_elem_th[i]) begin
                scratchpad[1][i*8 +: 8] <= data_vector[i*8 +: 8];
            end
            else begin
                scratchpad[1][i*8 +: 8] <= 8'b0;
            end
        end
    end
    // keep track of the rdst for each row
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            row_0_rdst <= 0;
        end 
        else if(start_new_instruction) begin// row 0 maintenance
            row_0_rdst <= instr_in.dst;
            row_0_src  <= instr_in.src2;
        end 
        else if(start_new_loop && !nxt_row) begin
            row_0_rdst <= rdst_r +1;
            row_0_src  <= src2_r +1;
        end
    end
    // keep track of the rdst for each row
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            row_1_rdst <= 0;
        end 
        // row 1 maintenance
        else if(start_new_loop && nxt_row) begin
            row_1_rdst <= rdst_r +1;
            row_1_src  <= src2_r +1;
        end
    end
    //=====================================
    // Scoreboard maintenance
    //=====================================
    //算这个指令还有多少元素未处理
    always_comb begin
        loop_remaining_elements = '0;
        for (int i = 0; i < 4*VECTOR_LANES; i++) begin
            if (pending_elem[current_row][i]) 
                loop_remaining_elements = loop_remaining_elements +1;
        end
    end


    always_comb begin//根据当前循环次数计算剩余元素
        case (size_r)//访存时为字节寻址
            SZ_8    : total_remaining_elements = instr_vl_r - (current_exp_loop_r*VECTOR_LANES*4);    
            SZ_16   : total_remaining_elements = instr_vl_r - (current_exp_loop_r*VECTOR_LANES*2);
            SZ_32   : total_remaining_elements = instr_vl_r - (current_exp_loop_r*VECTOR_LANES);
            default : total_remaining_elements = 'X;
        endcase
    end
    always_comb begin
        case (size_r)
            SZ_8    : nxt_total_remaining_elements = instr_vl_r - ((current_exp_loop_r+1)*VECTOR_LANES*4);    
            SZ_16   : nxt_total_remaining_elements = instr_vl_r - ((current_exp_loop_r+1)*VECTOR_LANES*2);
            SZ_32   : nxt_total_remaining_elements = instr_vl_r - ((current_exp_loop_r+1)*VECTOR_LANES);
            default : nxt_total_remaining_elements = 'X;
        endcase
    end

    //对比元素个数和缓存一次能取的个数，确定元素计数器
    always_comb begin
        if (memory_op_r != OP_UNIT_STRIDED) begin
            el_served_count = 'd1;
        //UNIT_STRIDED
        end else if (loop_remaining_elements < MAX_SERVED_COUNT) begin
            el_served_count = loop_remaining_elements; // remaining < max_width
        end else begin
            el_served_count = MAX_SERVED_COUNT; // remaining > max_width
        end
    end

    // Maintain current pointer and row
    assign nxt_row  = ~current_row;
    assign nxt_elem = multi_valid ? (current_pointer_wb_r + el_served_count) : (current_pointer_wb_r +1);
    always_ff @(posedge clk or negedge rst_n) begin : current_ptr
        if(~rst_n) begin
            current_pointer_wb_r <= 0;
            current_row          <= 0;
        end 
        else if(start_new_instruction) begin
            current_pointer_wb_r <= 0;
            current_row          <= 0;
        end 
        else if(start_new_loop) begin
            current_pointer_wb_r <= 0;
            current_row          <= nxt_row;
        end 
        else if (current_finished) begin
            current_pointer_wb_r <= 0;
        end 
        else if(new_transaction_en) begin
            current_pointer_wb_r <= nxt_elem;
        end
    end
    logic [31:0] vl_byte;
    always_comb begin
        case (nxt_size)
            SZ_8    : vl_byte = instr_in.vl;    
            SZ_16   : vl_byte = instr_in.vl*2;
            SZ_32   : vl_byte = instr_in.vl*4;
            default : vl_byte = 'X;
        endcase
    end
    // Create new pending states
    always_comb begin
        // next pending state for new instruction
        if(vl_byte < 4*VECTOR_LANES) begin
            nxt_pending_elem = ~('1 << vl_byte);//独热码 vl=4时，nxt_pending_elem=0_1111
        end else begin
            nxt_pending_elem = '1;
        end
    end
    always_comb begin 
        // next pending state for new loop
        if(nxt_total_remaining_elements < VECTOR_LANES) begin
            nxt_pending_elem_loop = ~('1 << nxt_total_remaining_elements);
        end else begin
            nxt_pending_elem_loop = '1;
        end
    end

    // Store new pending states
    assign current_served_th  = (~('1 << el_served_count)) << current_pointer_wb_r;
    assign current_pointer_oh = 1 << current_pointer_wb_r;
    always_ff @(posedge clk or negedge rst_n) begin : pending_status
        if(~rst_n) begin
            pending_elem <= '0;
        end 
        else begin
            for (int i = 0; i < 4*VECTOR_LANES; i++) begin
                //row 0 maintenance
                if(start_new_instruction) begin
                    pending_elem[0][i] <= nxt_pending_elem[i];
                end 
                else if(start_new_loop && !nxt_row) begin
                    pending_elem[0][i] <= nxt_pending_elem_loop[i];
                end 
                else if(new_transaction_en && current_served_th[i] && multi_valid && !current_row) begin // multi-request
                    pending_elem[0][i] <= 1'b0;
                end 
                else if(new_transaction_en && current_pointer_oh[i] && !multi_valid && !current_row) begin // single-request
                    pending_elem[0][i] <= 1'b0;
                end
                //row 1 maintenance
                if(start_new_instruction) begin
                    pending_elem[1][i] <= 1'b0;
                end 
                else if(start_new_loop && nxt_row) begin
                    pending_elem[1][i] <= nxt_pending_elem_loop[i];
                end 
                else if(new_transaction_en && current_served_th[i] && multi_valid && current_row) begin // multi-request
                    pending_elem[1][i] <= 1'b0;
                end 
                else if(new_transaction_en && current_pointer_oh[i] && !multi_valid && current_row) begin // single-request
                    pending_elem[1][i] <= 1'b0;
                end
            end
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin : active_status
        if(~rst_n) begin
            active_elem <= '0;
        end 
        else begin
            for (int i = 0; i < 4*VECTOR_LANES; i++) begin
                // row 0 maintenance
                if (writeback_complete && !writeback_row) begin
                    active_elem[0][i] <= 1'b0;
                end 
                else if(start_new_instruction) begin
                    active_elem[0][i] <= nxt_pending_elem[i];
                end 
                else if(start_new_loop && !nxt_row) begin
                    active_elem[0][i] <= nxt_pending_elem_loop[i];
                end
                // row 1 maintenance
                if (writeback_complete && writeback_row) begin
                    active_elem[1][i] <= 1'b0;
                end 
                else if(start_new_instruction) begin
                    active_elem[1][i] <= 1'b0;
                end 
                else if(start_new_loop && nxt_row) begin
                    active_elem[1][i] <= nxt_pending_elem_loop[i];
                end
            end
        end
    end
    // Keep track of served elements from memory
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            served_elem <= '0;
        end 
        else begin
            for (int i = 0; i < 4*VECTOR_LANES; i++) begin
                // row 0 maintenance
                if(start_new_instruction) begin
                    served_elem[0][i] <= 1'b0;
                end 
                else if(start_new_loop && !nxt_row) begin
                    served_elem[0][i] <= 1'b0;
                end 
                else if(resp_valid_i && resp_elem_th[i] && !resp_row) begin
                    served_elem[0][i] <= 1'b1;
                end
                // row 1 maintenance
                if(start_new_instruction) begin
                    served_elem[1][i] <= 1'b0;
                end 
                else if(start_new_loop && nxt_row) begin
                    served_elem[1][i] <= 1'b0;
                end 
                else if(resp_valid_i && resp_elem_th[i] && resp_row) begin
                    served_elem[1][i] <= 1'b1;
                end
            end
        end
    end
    // Keep track of the expanions happening
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_exp_loop_r <= 0;
        end 
        else if(start_new_instruction) begin
            current_exp_loop_r <= 0;
            src2_r             <= instr_in.src2;
            rdst_r             <= instr_in.dst;
        end 
        else if(start_new_loop) begin
            current_exp_loop_r <= current_exp_loop_r +1;
            src2_r             <= src2_r +1;
            rdst_r             <= rdst_r +1;
        end
    end
    //Store the max expansion when reconfiguring
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            max_expansion_r <= 'd1;
        end 
        else if(do_reconfigure) begin
            max_expansion_r <= instr_in.maxvl >> $clog2(VECTOR_LANES);
        end
    end
    //=====================================
    // Update instruction length
    always_ff @(posedge clk or negedge rst_n) begin 
        if(!rst_n)
            instr_vl_r <= VECTOR_LANES;
        else if(start_new_instruction) 
            instr_vl_r <= instr_in.vl;
    end
    always_ff @(posedge clk) begin
        if(start_new_instruction) begin
            microop_r          <= instr_in.microop;
            ticket_r           <= instr_in.ticket;
            last_ticket_src2_r <= instr_in.last_ticket_src2;
        end
    end
    assign nxt_memory_op = instr_in.microop[1:0];
    always_ff @(posedge clk or negedge rst_n) begin : proc_memory_op_r
        if(~rst_n) begin
            memory_op_r <= '0;
        end 
        else if(start_new_instruction) begin
            memory_op_r <= nxt_memory_op;
        end
    end

    // calculate start-end addresses for the op
    // +- 4 to avoid conflicts due to data sizes
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            start_addr_r <= '0;
            end_addr_r   <= '1;
        end 
        else if(start_new_instruction) begin
            start_addr_r <= nxt_base_addr;
            if(instr_in.microop[1:0] == OP_INDEXED) begin
                end_addr_r <= nxt_base_addr; // cannot calculate end address for `OP_INDEXED ops
            end 
            else begin
                end_addr_r <= nxt_base_addr + ((instr_in.vl -1) * nxt_stride);
            end
        end
    end

endmodule