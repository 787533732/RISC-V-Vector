module rat 
(
    input  logic                    clk             ,
    input  logic                    rst_n           ,
	//Write Port #1
	input  logic [4:0]              write_addr_1    ,
	input  logic [5:0]              write_data_1    ,
	input  logic                    write_en_1      ,
	input  logic                    instr_1_rn      ,
	//Write Port #2 
	input  logic [4:0]              write_addr_2    ,
	input  logic [5:0]              write_data_2    ,
	input  logic                    write_en_2      ,
	input  logic                    instr_2_rn      ,
	//Read Port #1
	input  logic [4:0]              read_addr_1     ,
	output logic [5:0]              read_data_1     ,
	//Read Port #2                  
	input  logic [4:0]              read_addr_2     ,
	output logic [5:0]              read_data_2     ,
	//Read Port #3
	input  logic [4:0]              read_addr_3    ,
	output logic [5:0]              read_data_3    ,
	//Read Port #4
	input  logic [4:0]              read_addr_4    ,
	output logic [5:0]              read_data_4    ,
	//Read Port #5
	input  logic [4:0]              read_addr_5    ,
	output logic [5:0]              read_data_5    ,
	//Read Port #6
	input  logic [4:0]              read_addr_6    ,
	output logic [5:0]              read_data_6    ,
	//Checkpoint Port 遇到分支指令时，对RAT使用Checkpoint进行保存
	input  logic                    take_checkpoint,
	input  logic                    instr_num      ,//0:first 1:second
    input  logic                    single_branch  ,
	input  logic                    dual_branch    ,
	output logic                    current_id     ,
	//Restore Port
	input  logic                    restore_rat    ,
	input  logic                    restore_id     
);
    logic [1:0][31:0][5:0]          CheckpointedRAT;
    logic [31:0][5:0]               CurrentRAT;
    logic                           next_ckp, next_ckp_plus;

    assign current_id = next_ckp;
    //Decode RAT Management
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            //Initialize all Registers paired to R8+
            for (int i = 0; i < 32; i++) begin
                CurrentRAT[i] <= i;
            end
        end 
        else begin
            //Restore the Chkp RAT
            if(restore_rat) begin
                CurrentRAT <= CheckpointedRAT[restore_id];
                //Capture this cycle's commit
            end else begin
                //Store new Allocations
                if (write_en_1) CurrentRAT[write_addr_1] <= write_data_1;
                if (write_en_2) CurrentRAT[write_addr_2] <= write_data_2;         
            end
        end
    end
    assign next_ckp_plus = next_ckp +1;
    //Checkpointed RAT Management
    always_ff @(posedge clk) begin : CkpRAT
        if(take_checkpoint) begin
            if(dual_branch) begin//two branch instr
                CheckpointedRAT[next_ckp]      <= CurrentRAT;
                CheckpointedRAT[next_ckp_plus] <= CurrentRAT;
                if (write_en_1) begin 
                    CheckpointedRAT[next_ckp][write_addr_1] <= write_data_1;
                    CheckpointedRAT[next_ckp_plus][write_addr_1] <= write_data_1;
                end
                if (write_en_2) CheckpointedRAT[next_ckp_plus][write_addr_2] <= write_data_2;
            end 
            else if(single_branch) begin//one branch instr
            	CheckpointedRAT[next_ckp] <= CurrentRAT;
                if(!instr_num) begin
                    if (write_en_1 && instr_1_rn) 
                        CheckpointedRAT[next_ckp][write_addr_1] <= write_data_1;
                end else begin
                    if (write_en_1) 
                        CheckpointedRAT[next_ckp][write_addr_1] <= write_data_1;
                    if (write_en_2) 
                        CheckpointedRAT[next_ckp][write_addr_2] <= write_data_2;
                end
            end
        end
    end
    //Next Checkpoint Management
    always_ff @(posedge clk or negedge rst_n) begin : NextCkp
        if(!rst_n) begin
            next_ckp <= 0;
        end 
        else if(take_checkpoint) begin
            if(dual_branch) 
                next_ckp <= next_ckp +2;
            else if(single_branch) 
                next_ckp <= next_ckp +1;
        end
    end
    //Push Data Out
    assign read_data_1 = CurrentRAT[read_addr_1];
    assign read_data_2 = CurrentRAT[read_addr_2];
    assign read_data_3 = CurrentRAT[read_addr_3];
    assign read_data_4 = CurrentRAT[read_addr_4];
    assign read_data_5 = CurrentRAT[read_addr_5];
    assign read_data_6 = CurrentRAT[read_addr_6];

endmodule