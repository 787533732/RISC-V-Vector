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
initial begin  
    clk  = 1'b0;
    rst_n = 1'b0;
    for(j=0; j < 102400; j=j+1) begin
        top_tb.u_top.u_core.u_main_memory.ram[j] <= 'b0;
    end
    #20
    rst_n = 1'b1;

    for (k = 10; k <= 10; k=k+1) begin
        inst_name = inst_list[k];
        inst_load(inst_name);
        wait(a0_x10==32'hffff_ffff);
        $display("%s PASS", inst_name);
        //$display("cycle is: %d", cycle); 
        //$display("instr is: %d", commit_instr); 
        //$display("branch_instr is: %d", branch_instr); 
        //$display("mispredict_instr_num is: %d", mispredict);
        #20
        reset; 
        #400;
        
    end 
    $finish;
end


initial begin
    inst_list[0] = "../vector_test/vadd_int8.verilog"; inst_list[1] = "../vector_test/vadd_int16.verilog"; inst_list[2] = "../vector_test/vadd_int32.verilog"; 
    inst_list[3] = "../vector_test/vsub_int8.verilog"; inst_list[4] = "../vector_test/vsub_int16.verilog"; inst_list[5] = "../vector_test/vsub_int32.verilog"; 
    inst_list[6] = "../vector_test/vand_int8.verilog"; inst_list[7] = "../vector_test/vand_int16.verilog"; inst_list[8] = "../vector_test/vand_int32.verilog"; 

    inst_list[10] = "../lenet/lenet.verilog";
end
initial begin  
    external_interrupt = 1'b0;
    #1000000 
    $finish;
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

task reset;              
    begin
        rst_n = 0; 
        #20;
        rst_n = 1;
    end
endtask

integer r;
string result;

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
 


 