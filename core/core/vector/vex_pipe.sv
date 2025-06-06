module vex_pipe
#(
    parameter DATA_WIDTH         = 32,
    parameter MICROOP_WIDTH      = 5 ,
    parameter VECTOR_LANES       = 8 
)
(
    input   logic                               clk         ,
    input   logic                               rst_n       ,

    input   logic                               valid_i     ,
    output  logic                               ready_o     ,
    input   to_vector_alu                       operation_in,
    //Forward Point #1
    output  logic                               frw_a_en_o  ,
    output  logic [DATA_WIDTH-1:0]              frw_a_data_o,
    ////Forward Point #2
    //output  logic                               frw_b_en_o  ,
    //output  logic [DATA_WIDTH-1:0]              frw_b_data_o,
    //write back
    output  logic                               wr_en_o     ,  
    output  logic [DATA_WIDTH-1:0]              wr_data_o   ,
    output  logic                               wren_scalar_o
);

    //logic                   ready_res_int_ex1;
    logic [DATA_WIDTH-1:0]  res_int_ex1      ;
    logic                   wren_scalar_reg  ;
    logic                   valid_int_ex1;
    assign valid_int_ex1  = valid_i ? operation_in.fu : 1'b0;
    assign ready_o        = 1'b1;
    valu 
    #(
        .MICROOP_WIDTH  (MICROOP_WIDTH  ),
        .VECTOR_LANES   (VECTOR_LANES   )
    )
    vector_alu
    (
        .clk             (clk                   ),
        .rst_n           (rst_n                 ),

        .valid_i         (valid_int_ex1         ),
        .data_a_ex1_i    (operation_in.data_a   ),
        .data_b_ex1_i    (operation_in.data_b   ),
        .imm_ex1_i       (operation_in.immediate),
        .microop_i       (operation_in.microop  ),
        .vsew_i          (operation_in.vsew[1:0]),
        .mask_i          (                      ),
        //.ready_res_ex1_o (ready_res_int_ex1 ),
        .result_ex1_o    (res_int_ex1           ),
        .wren_scalar_reg (wren_scalar_reg       )
    );
    logic [31:0]         data_ex1;
    logic                wren_scalar;
    logic                valid_result_wr;
    //always_ff @(posedge clk) begin
    //    if(valid_int_ex1) begin
    //        data_ex1 <= res_int_ex1;
    //        wren_scalar <= wren_scalar_reg;
    //    end 
    //end
    //always_ff @(posedge clk or negedge rst_n) begin
    //    if(!rst_n) begin
    //        valid_result_wr     <= 1'b0;
    //        //mask_wr             <= 1'b1;
    //    end else begin
    //        valid_result_wr     <= valid_int_ex1;
    //        //mask_wr             <= mask_ex4 | (use_reduce_tree_ex4 & VECTOR_LANE_NUM != 0);
    //    end
    //end
    //assign frw_a_en_o     = valid_int_ex1;
    //assign frw_a_data_o   = res_int_ex1;  
    //assign wr_en_o        = valid_result_wr & ~wren_scalar;
    //assign wr_data_o      = data_ex1;
    //assign wren_scalar_o  = wren_scalar;

    assign frw_a_en_o     = valid_int_ex1;
    assign frw_a_data_o   = res_int_ex1;  

    assign wr_en_o        = valid_int_ex1 & ~wren_scalar_reg;
    assign wr_data_o      = res_int_ex1;
    assign wren_scalar_o  = wren_scalar_reg;
endmodule