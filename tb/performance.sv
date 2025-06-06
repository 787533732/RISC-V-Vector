module top_tb();

reg clk;
reg rst_n;
reg external_interrupt;
reg [450:0] inst_name;
reg [450:0] inst_list [0:100];
reg [7:0]   mem [131072:0];

integer i;
integer k;

logic [31:0] s10_x26; 
logic [31:0] s11_x27; 
logic [31:0] gp_x3;   
logic [31:0] a7_x17;  
logic [31:0] a0_x10;  
logic [31:0] x2_sp;   
logic [63:0] cycle;                            
logic [19:0] commit_instr;    
logic [19:0] branch_instr;    
logic [19:0] mispredict;      
logic        wfi1;            
logic        wfi2; 

assign s10_x26 = u_top.u_core.u_processor.debug_regfile.x26_s10_w;
assign s11_x27 = u_top.u_core.u_processor.debug_regfile.x27_s11_w;
assign gp_x3   = u_top.u_core.u_processor.debug_regfile.x3_gp_w;
assign a7_x17  = u_top.u_core.u_processor.debug_regfile.x17_a7_w;
assign a0_x10  = u_top.u_core.u_processor.debug_regfile.x10_a0_w;
assign x2_sp   = u_top.u_core.u_processor.debug_regfile.x2_sp_w;

//------------------performance test-------------------------//
assign cycle            = {u_top.u_core.u_processor.u0_execute_stage.lsu_csr.csr_ctrl.csr_reg.csr_mcycle_h_q,
                           u_top.u_core.u_processor.u0_execute_stage.lsu_csr.csr_ctrl.csr_reg.csr_mcycle_q};

always_ff @(posedge clk or negedge rst_n) begin 
    if(!rst_n)
        commit_instr <= 'd0;
    else if((u_top.u_core.u_processor.u_rob.writeback_1.valid_commit & !u_top.u_core.u_processor.u_rob.writeback_1.flushed) 
          ^ (u_top.u_core.u_processor.u_rob.writeback_2.valid_commit & !u_top.u_core.u_processor.u_rob.writeback_2.flushed))
        commit_instr <= commit_instr+1;
    else if((u_top.u_core.u_processor.u_rob.writeback_1.valid_commit & !u_top.u_core.u_processor.u_rob.writeback_1.flushed) 
          & (u_top.u_core.u_processor.u_rob.writeback_2.valid_commit & !u_top.u_core.u_processor.u_rob.writeback_2.flushed))
        commit_instr <= commit_instr+2;
end

always_ff @(posedge clk or negedge rst_n) begin 
    if(!rst_n)
        mispredict <= 'd0;
    else if(u_top.u_core.u_processor.instruction_decode.must_flush)
        mispredict <= mispredict+1;
end

always_ff @(posedge clk or negedge rst_n) begin 
    if(!rst_n)
        branch_instr <= 'd0;
    else if((u_top.u_core.u_processor.u_rob.writeback_1.valid_commit & !u_top.u_core.u_processor.u_rob.writeback_1.flushed & u_top.u_core.u_processor.u_rob.writeback_1.is_branch) & (u_top.u_core.u_processor.u_rob.writeback_2.valid_commit & !u_top.u_core.u_processor.u_rob.writeback_2.flushed & u_top.u_core.u_processor.u_rob.writeback_2.is_branch))
        branch_instr <= branch_instr+2;
    else if((u_top.u_core.u_processor.u_rob.writeback_1.valid_commit & !u_top.u_core.u_processor.u_rob.writeback_1.flushed & u_top.u_core.u_processor.u_rob.writeback_1.is_branch) | (u_top.u_core.u_processor.u_rob.writeback_2.valid_commit & !u_top.u_core.u_processor.u_rob.writeback_2.flushed & u_top.u_core.u_processor.u_rob.writeback_2.is_branch))
        branch_instr <= branch_instr+1;
end

assign wfi1  = u_top.u_core.u_processor.instruction_decode.u_decoder.decoder_full_a.wfi;
assign wfi2  = u_top.u_core.u_processor.instruction_decode.u_decoder.decoder_full_b.wfi;

real cpi;
integer j;
real cy =cycle;
real instr=commit_instr;
initial begin  
    clk  = 1'b0;
    rst_n = 1'b0;
    for(j=0; j < 102400; j=j+1) begin
        top_tb.u_top.u_core.u_main_memory.ram[j] <= 'b0;
    end
    #20
    rst_n = 1'b1;

    for (k = 45; k <= 45; k=k+1) begin
        inst_name = inst_list[k];
        inst_load(inst_name);
        #1000
        wait(wfi1|wfi2);
        $display("test is: %s", inst_name);
        $display("cycle is: %d", cycle); 
        $display("instr is: %d", commit_instr); 
        $display("branch_instr is: %d", branch_instr); 
        $display("mispredict_instr_num is: %d", mispredict); 
        reset;
    end 

    $finish;
end
initial begin

    inst_list[0]  = "../microbench/vadd/16/vadd.verilog";
    inst_list[1]  = "../microbench/vadd/32/vadd.verilog";
    inst_list[2]  = "../microbench/vadd/64/vadd.verilog";
    inst_list[3]  = "../microbench/vadd/128/vadd.verilog";
    inst_list[4]  = "../microbench/vadd/256/vadd.verilog";
    inst_list[5]  = "../microbench/memcpy/16/memcpy.verilog";
    inst_list[6]  = "../microbench/memcpy/32/memcpy.verilog";
    inst_list[7]  = "../microbench/memcpy/64/memcpy.verilog";
    inst_list[8]  = "../microbench/memcpy/128/memcpy.verilog";
    inst_list[9]  = "../microbench/memcpy/256/memcpy.verilog";
    inst_list[10] = "../microbench/perceptron/16/perceptron.verilog";
    inst_list[11] = "../microbench/perceptron/32/perceptron.verilog";
    inst_list[12] = "../microbench/perceptron/64/perceptron.verilog";
    inst_list[13] = "../microbench/perceptron/128/perceptron.verilog";  
    inst_list[14] = "../microbench/perceptron/256/perceptron.verilog";
    inst_list[15] = "../microbench/gemm/3x3/gemm_3x3.verilog";
    inst_list[16] = "../microbench/gemm/5x5/gemm_5x5.verilog";
    inst_list[17] = "../microbench/gemm/7x7/gemm_7x7.verilog";
    inst_list[18] = "../microbench/gemm/16x16/gemm_16x16.verilog";
    inst_list[19] = "../microbench/gemm/32x32/gemm_32x32.verilog";

    inst_list[20] = "../microbench/vadd/16/vec_vadd.verilog";//error
    inst_list[21] = "../microbench/vadd/32/vec_vadd.verilog";
    inst_list[22] = "../microbench/vadd/64/vec_vadd.verilog";
    inst_list[23] = "../microbench/vadd/128/vec_vadd.verilog";
    inst_list[24] = "../microbench/vadd/256/vec_vadd.verilog";
    inst_list[25] = "../microbench/memcpy/16/vec_memcpy.verilog";//error
    inst_list[26] = "../microbench/memcpy/32/vec_memcpy.verilog"; //error
    inst_list[27] = "../microbench/memcpy/64/vec_memcpy.verilog"; 
    inst_list[28] = "../microbench/memcpy/128/vec_memcpy.verilog";//error 
    inst_list[29] = "../microbench/memcpy/256/vec_memcpy.verilog";//error 
    inst_list[30] = "../microbench/perceptron_int8/perceptron_16.verilog";
    inst_list[31] = "../microbench/perceptron_int8/perceptron_32.verilog";
    inst_list[32] = "../microbench/perceptron_int8/perceptron_64.verilog";
    inst_list[33] = "../microbench/perceptron_int8/perceptron_128.verilog";   
    inst_list[34] = "../microbench/perceptron_int8/perceptron_256.verilog";
    inst_list[35] = "../microbench/perceptron_int16/perceptron_16.verilog";//error
    inst_list[36] = "../microbench/perceptron_int16/perceptron_32.verilog";//error
    inst_list[37] = "../microbench/perceptron_int16/perceptron_64.verilog";//error
    inst_list[38] = "../microbench/perceptron_int16/perceptron_128.verilog";//error
    inst_list[39] = "../microbench/perceptron_int16/perceptron_256.verilog";//error
    inst_list[40] = "../microbench/perceptron_int32/perceptron_16.verilog";
    inst_list[41] = "../microbench/perceptron_int32/perceptron_32.verilog";
    inst_list[42] = "../microbench/perceptron_int32/perceptron_64.verilog";
    inst_list[43] = "../microbench/perceptron_int32/perceptron_128.verilog";   
    inst_list[44] = "../microbench/perceptron_int32/perceptron_256.verilog";

    inst_list[45] = "../microbench/gemm_vec/3x3/vec_gemm_3x3.verilog";
    inst_list[46] = "../microbench/gemm_vec/5x5/vec_gemm_5x5.verilog";
    inst_list[47] = "../microbench/gemm_vec/7x7/vec_gemm_7x7.verilog";
    inst_list[48] = "../microbench/gemm_vec/16x16/vec_gemm_16x16.verilog";
    inst_list[49] = "../microbench/gemm_vec/32x32/vec_gemm_32x32.verilog";
end
initial begin  
    external_interrupt = 1'b0;
/*    #3000
    external_interrupt = 1'b1;
    #40
    external_interrupt = 1'b0;
    #1000
    external_interrupt = 1'b1;
    #40
    external_interrupt = 1'b0;*/
end

always #10 clk = ~clk;

task inst_load;
    input [600:0] inst_name;
    
    begin
    for (i=0;i<131072;i=i+1)
        mem[i] = 0;
    $readmemh(inst_name, mem);

    for (i=0;i<131072;i=i+1) begin
        u_top.u_core.u_main_memory.write(i, mem[i]);
    end
    
    end

endtask

task reset;                // reset 1 clock
    begin
        rst_n = 0; 
        #20;
        rst_n = 1;
    end
endtask

integer r;
string result;



initial begin
//#4000000
//$finish;
    
    repeat(33) begin
    wait((top_tb.u_top.u_core.u_processor.cache_wb_addr_o=='h3000_000c) & top_tb.u_top.u_core.u_processor.cache_wb_valid_o)begin
        $display("%s", top_tb.u_top.u_core.u_processor.cache_wb_data_o[15:0]); 
    end
    #40;
    end


end

soc u_top
(
    .clk                    (clk ),
    .rst_n                  (rst_n),
    .external_interrupt     (external_interrupt),
    .timer_interrupt        ()
);



initial begin 
    $fsdbDumpfile("top.fsdb");
    $fsdbDumpvars(0,top_tb,"+all");
    $fsdbDumpMDA();
end


endmodule
 