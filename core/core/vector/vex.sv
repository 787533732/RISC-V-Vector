module vex
#(
    parameter DATA_WIDTH         = 32,
    parameter MICROOP_WIDTH      = 5 ,    
    parameter VECTOR_TICKET_BITS = 4 ,
    parameter VECTOR_LANES       = 8 
)
(
    input   logic                                       clk             ,
    input   logic                                       rst_n           ,
    input   logic                                       flush           ,
    //Issue Interface   
    input   logic                                       valid_i         ,
    output  logic                                       ready_o         ,
    input   to_vector_exec       [VECTOR_LANES-1:0]     exec_data_i     ,
    input   to_vector_exec_info                         exec_info_i     ,
    //Forward Point #1 (EX1)
    output  logic [VECTOR_LANES-1:0]                    frw_a_en        ,
    output  logic [4:0]                                 frw_a_addr      ,
    output  logic [VECTOR_LANES-1:0][DATA_WIDTH-1:0]    frw_a_data      ,
    output  logic [VECTOR_TICKET_BITS-1:0]              frw_a_ticket    ,
    //Forward Point #2 (EX*)    
    //output  logic [VECTOR_LANES-1:0]                    frw_b_en        ,
    //output  logic [4:0]                                 frw_b_addr      ,
    //output  logic [VECTOR_LANES-1:0][DATA_WIDTH-1:0]    frw_b_data      ,
    //output  logic [VECTOR_TICKET_BITS-1:0]              frw_b_ticket    ,
    //Writeback
    output  logic [VECTOR_LANES-1:0]                    wr_en           ,
    output  logic [4:0]                                 wr_addr         ,
    output  logic                                       wren_scalar     ,
    output  logic [31:0]                                wren_scalar_data,
    output  logic [VECTOR_LANES-1:0][DATA_WIDTH-1:0]    wr_data         ,
    output  logic [VECTOR_TICKET_BITS-1:0]              wr_ticket     
);

    logic [VECTOR_LANES-1:0] ready;
    logic [VECTOR_LANES-1:0] vex_pipe_valid;
    logic [VECTOR_LANES-1:0] wren_scalar_o;
    logic [VECTOR_LANES-1:0][31:0] exec_data1,exec_data2;

generate if(VECTOR_LANES==8) begin
    always_comb begin
        if(exec_info_i.microop==5'b10110)//IVISLIDEDOWN
            case(exec_data_i[0].immediate) 
                32'd0 : begin
                    exec_data1[0] = exec_data_i[0].data1;
                    exec_data2[0] = exec_data_i[0].data2;
                    exec_data1[1] = exec_data_i[1].data1;
                    exec_data2[1] = exec_data_i[1].data2;
                    exec_data1[2] = exec_data_i[2].data1;
                    exec_data2[2] = exec_data_i[2].data2;
                    exec_data1[3] = exec_data_i[3].data1;
                    exec_data2[3] = exec_data_i[3].data2;
                    exec_data1[4] = exec_data_i[4].data1;
                    exec_data2[4] = exec_data_i[4].data2;
                    exec_data1[5] = exec_data_i[5].data1;
                    exec_data2[5] = exec_data_i[5].data2;
                    exec_data1[6] = exec_data_i[6].data1;
                    exec_data2[6] = exec_data_i[6].data2;
                    exec_data1[7] = exec_data_i[7].data1;
                    exec_data2[7] = exec_data_i[7].data2;
                end
                32'd1 : begin
                    exec_data1[0] = exec_data_i[1].data1;
                    exec_data2[0] = exec_data_i[1].data2;
                    exec_data1[1] = exec_data_i[2].data1;
                    exec_data2[1] = exec_data_i[2].data2;
                    exec_data1[2] = exec_data_i[3].data1;
                    exec_data2[2] = exec_data_i[3].data2;
                    exec_data1[3] = exec_data_i[4].data1;
                    exec_data2[3] = exec_data_i[4].data2;
                    exec_data1[4] = exec_data_i[5].data1;
                    exec_data2[4] = exec_data_i[5].data2;
                    exec_data1[5] = exec_data_i[6].data1;
                    exec_data2[5] = exec_data_i[6].data2;
                    exec_data1[6] = exec_data_i[7].data1;
                    exec_data2[6] = exec_data_i[7].data2;
                    exec_data1[7] = 32'd0;
                    exec_data2[7] = 32'd0;
                end
                32'd2 : begin
                    exec_data1[0] = exec_data_i[2].data1;
                    exec_data2[0] = exec_data_i[2].data2;
                    exec_data1[1] = exec_data_i[3].data1;
                    exec_data2[1] = exec_data_i[3].data2;
                    exec_data1[2] = exec_data_i[4].data1;
                    exec_data2[2] = exec_data_i[4].data2;
                    exec_data1[3] = exec_data_i[5].data1;
                    exec_data2[3] = exec_data_i[5].data2;
                    exec_data1[4] = exec_data_i[6].data1;
                    exec_data2[4] = exec_data_i[6].data2;
                    exec_data1[5] = exec_data_i[7].data1;
                    exec_data2[5] = exec_data_i[7].data2;
                    exec_data1[6] = 32'd0;
                    exec_data2[6] = 32'd0;
                    exec_data1[7] = 32'd0;
                    exec_data2[7] = 32'd0;
                end
                32'd3 : begin
                    exec_data1[0] = exec_data_i[3].data1;
                    exec_data2[0] = exec_data_i[3].data2;
                    exec_data1[1] = exec_data_i[4].data1;
                    exec_data2[1] = exec_data_i[4].data2;
                    exec_data1[2] = exec_data_i[5].data1;
                    exec_data2[2] = exec_data_i[5].data2;
                    exec_data1[3] = exec_data_i[6].data1;
                    exec_data2[3] = exec_data_i[6].data2;
                    exec_data1[4] = exec_data_i[7].data1;
                    exec_data2[4] = exec_data_i[7].data2;
                    exec_data1[5] = 32'd0;
                    exec_data2[5] = 32'd0;
                    exec_data1[6] = 32'd0;
                    exec_data2[6] = 32'd0;
                    exec_data1[7] = 32'd0;
                    exec_data2[7] = 32'd0;
                end
                32'd4 : begin
                    exec_data1[0] = exec_data_i[4].data1;
                    exec_data2[0] = exec_data_i[4].data2;
                    exec_data1[1] = exec_data_i[5].data1;
                    exec_data2[1] = exec_data_i[5].data2;
                    exec_data1[2] = exec_data_i[6].data1;
                    exec_data2[2] = exec_data_i[6].data2;
                    exec_data1[3] = exec_data_i[7].data1;
                    exec_data2[3] = exec_data_i[7].data2;
                    exec_data1[4] = 32'd0;
                    exec_data2[4] = 32'd0;
                    exec_data1[5] = 32'd0;
                    exec_data2[5] = 32'd0;
                    exec_data1[6] = 32'd0;
                    exec_data2[6] = 32'd0;
                    exec_data1[7] = 32'd0;
                    exec_data2[7] = 32'd0;
                end
                32'd5 : begin
                    exec_data1[0] = exec_data_i[5].data1;
                    exec_data2[0] = exec_data_i[5].data2;
                    exec_data1[1] = exec_data_i[6].data1;
                    exec_data2[1] = exec_data_i[6].data2;
                    exec_data1[2] = exec_data_i[7].data1;
                    exec_data2[2] = exec_data_i[7].data2;
                    exec_data1[3] = 32'd0;
                    exec_data2[3] = 32'd0;
                    exec_data1[4] = 32'd0;
                    exec_data2[4] = 32'd0;
                    exec_data1[5] = 32'd0;
                    exec_data2[5] = 32'd0;
                    exec_data1[6] = 32'd0;
                    exec_data2[6] = 32'd0;
                    exec_data1[7] = 32'd0;
                    exec_data2[7] = 32'd0;
                end
                32'd6 : begin
                    exec_data1[0] = exec_data_i[6].data1;
                    exec_data2[0] = exec_data_i[6].data2;
                    exec_data1[1] = exec_data_i[7].data1;
                    exec_data2[1] = exec_data_i[7].data2;
                    exec_data1[2] = 32'd0;
                    exec_data2[2] = 32'd0;
                    exec_data1[3] = 32'd0;
                    exec_data2[3] = 32'd0;
                    exec_data1[4] = 32'd0;
                    exec_data2[4] = 32'd0;
                    exec_data1[5] = 32'd0;
                    exec_data2[5] = 32'd0;
                    exec_data1[6] = 32'd0;
                    exec_data2[6] = 32'd0;
                    exec_data1[7] = 32'd0;
                    exec_data2[7] = 32'd0;
                end
                32'd7 : begin
                    exec_data1[0] = exec_data_i[7].data1;
                    exec_data2[0] = exec_data_i[7].data2;
                    exec_data1[1] = 32'd0;
                    exec_data2[1] = 32'd0;
                    exec_data1[2] = 32'd0;
                    exec_data2[2] = 32'd0;
                    exec_data1[3] = 32'd0;
                    exec_data2[3] = 32'd0;
                    exec_data1[4] = 32'd0;
                    exec_data2[4] = 32'd0;
                    exec_data1[5] = 32'd0;
                    exec_data2[5] = 32'd0;
                    exec_data1[6] = 32'd0;
                    exec_data2[6] = 32'd0;
                    exec_data1[7] = 32'd0;
                    exec_data2[7] = 32'd0;
                end
                default : begin
                    exec_data1[0] = 32'd0;
                    exec_data2[0] = 32'd0;
                    exec_data1[1] = 32'd0;
                    exec_data2[1] = 32'd0;
                    exec_data1[2] = 32'd0;
                    exec_data2[2] = 32'd0;
                    exec_data1[3] = 32'd0;
                    exec_data2[3] = 32'd0;
                    exec_data1[4] = 32'd0;
                    exec_data2[4] = 32'd0;
                    exec_data1[5] = 32'd0;
                    exec_data2[5] = 32'd0;
                    exec_data1[6] = 32'd0;
                    exec_data2[6] = 32'd0;
                    exec_data1[7] = 32'd0;
                    exec_data2[7] = 32'd0;
                end
            endcase
        else begin
            exec_data1[0] = exec_data_i[0].data1;
            exec_data2[0] = exec_data_i[0].data2;
            exec_data1[1] = exec_data_i[1].data1;
            exec_data2[1] = exec_data_i[1].data2;
            exec_data1[2] = exec_data_i[2].data1;
            exec_data2[2] = exec_data_i[2].data2;
            exec_data1[3] = exec_data_i[3].data1;
            exec_data2[3] = exec_data_i[3].data2;
            exec_data1[4] = exec_data_i[4].data1;
            exec_data2[4] = exec_data_i[4].data2;
            exec_data1[5] = exec_data_i[5].data1;
            exec_data2[5] = exec_data_i[5].data2;
            exec_data1[6] = exec_data_i[6].data1;
            exec_data2[6] = exec_data_i[6].data2;
            exec_data1[7] = exec_data_i[7].data1;
            exec_data2[7] = exec_data_i[7].data2;
        end
    end
end
else begin
    always_comb begin
        if(exec_info_i.microop==5'b10110)//IVISLIDEDOWN
            case(exec_data_i[0].immediate) 
                32'd0 : begin
                    exec_data1[0] = exec_data_i[0].data1;
                    exec_data2[0] = exec_data_i[0].data2;
                    exec_data1[1] = exec_data_i[1].data1;
                    exec_data2[1] = exec_data_i[1].data2;
                    exec_data1[2] = exec_data_i[2].data1;
                    exec_data2[2] = exec_data_i[2].data2;
                    exec_data1[3] = exec_data_i[3].data1;
                    exec_data2[3] = exec_data_i[3].data2;
                end
                32'd1 : begin
                    exec_data1[0] = exec_data_i[1].data1;
                    exec_data2[0] = exec_data_i[1].data2;
                    exec_data1[1] = exec_data_i[2].data1;
                    exec_data2[1] = exec_data_i[2].data2;
                    exec_data1[2] = exec_data_i[3].data1;
                    exec_data2[2] = exec_data_i[3].data2;
                    exec_data1[3] = 32'b0;
                    exec_data2[3] = 32'b0;
                end
                32'd2 : begin
                    exec_data1[0] = exec_data_i[2].data1;
                    exec_data2[0] = exec_data_i[2].data2;
                    exec_data1[1] = exec_data_i[3].data1;
                    exec_data2[1] = exec_data_i[3].data2;
                    exec_data1[2] = 32'd0;
                    exec_data2[2] = 32'd0;
                    exec_data1[3] = 32'd0;
                    exec_data2[3] = 32'd0;
                end
                32'd3 : begin
                    exec_data1[0] = exec_data_i[3].data1;
                    exec_data2[0] = exec_data_i[3].data2;
                    exec_data1[1] = 32'd0;
                    exec_data2[1] = 32'd0;
                    exec_data1[2] = 32'd0;
                    exec_data2[2] = 32'd0;
                    exec_data1[3] = 32'd0;
                    exec_data2[3] = 32'd0;
                end
                default : begin
                    exec_data1[0] = 32'd0;
                    exec_data2[0] = 32'd0;
                    exec_data1[1] = 32'd0;
                    exec_data2[1] = 32'd0;
                    exec_data1[2] = 32'd0;
                    exec_data2[2] = 32'd0;
                    exec_data1[3] = 32'd0;
                    exec_data2[3] = 32'd0;
                end
            endcase
        else begin
            exec_data1[0] = exec_data_i[0].data1;
            exec_data2[0] = exec_data_i[0].data2;
            exec_data1[1] = exec_data_i[1].data1;
            exec_data2[1] = exec_data_i[1].data2;
            exec_data1[2] = exec_data_i[2].data1;
            exec_data2[2] = exec_data_i[2].data2;
            exec_data1[3] = exec_data_i[3].data1;
            exec_data2[3] = exec_data_i[3].data2;
        end
    end
end
endgenerate

assign ready_o = &ready;


to_vector_alu [7:0] operation_in;
genvar k;
generate
    for(k = 0;k < VECTOR_LANES;k++) begin
        assign vex_pipe_valid[k] = valid_i & exec_data_i[k].valid;
        assign operation_in[k].data_a    = exec_data1[k]; 
        assign operation_in[k].data_b    = exec_data2[k]; 
        assign operation_in[k].immediate = exec_data_i[k].immediate;     
        assign operation_in[k].microop   = exec_info_i.microop;      
        assign operation_in[k].fu        = exec_info_i.fu; 
        assign operation_in[k].vsew      = exec_info_i.vsew; 
        //assign operation_in[k].mask_i      = ; 

        vex_pipe 
        #(
            .DATA_WIDTH         (DATA_WIDTH   ),
            .MICROOP_WIDTH      (MICROOP_WIDTH),
            .VECTOR_LANES       (VECTOR_LANES )
        )u_vex_pipe
        (
            .clk                (clk  ),
            .rst_n              (rst_n),

            .valid_i            (vex_pipe_valid[k]),
            .ready_o            (ready[k]         ),
            . operation_in      (operation_in[k]  ),

            .frw_a_en_o         (frw_a_en[k]),
            .frw_a_data_o       (frw_a_data[k]),
            //.frw_b_en_o         (frw_b_en[k]),
            //.frw_b_data_o       (frw_b_data[k]),

            .wr_en_o            (wr_en[k]           ),
            .wr_data_o          (wr_data[k]         ), 
            .wren_scalar_o      (wren_scalar_o[k]   )
        );
    end
endgenerate


    logic   [5:0]                       dst_wr;
    logic   [VECTOR_TICKET_BITS-1:0]    ticket_wr;

    //always_ff @(posedge clk) begin
    //    if(valid_i) begin
    //        dst_wr     <= exec_info_i.dst;
    //        ticket_wr  <= exec_info_i.ticket;
    //    end
    //end
    assign frw_a_addr   = exec_info_i.dst;
    assign frw_a_ticket = exec_info_i.ticket;
    //assign frw_b_addr   = exec_info_i.dst;
    //assign frw_b_ticket = exec_info_i.ticket;
    // Writeback Signals
    assign wr_addr          = exec_info_i.dst;
    assign wr_ticket        = exec_info_i.ticket;

    assign wren_scalar      = wren_scalar_o[0];
    assign wren_scalar_data = wr_data[0];
endmodule