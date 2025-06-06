module register_file 
#(
    parameter int DATA_WIDTH = 32 , 
    parameter int ADDR_WIDTH = 6  , 
    parameter int SIZE       = 64 , 
    parameter int READ_PORTS = 2
) 
(
	input  logic                                  clk         ,
	input  logic                                  rst_n       ,
	// Write Port
	input  logic                                  write_En    ,
	input  logic [ADDR_WIDTH-1:0]                 write_Addr  ,
	input  logic [DATA_WIDTH-1:0]                 write_Data  ,
	// Write Port
	input  logic                                  write_En_2  ,
	input  logic [ADDR_WIDTH-1:0]                 write_Addr_2,
	input  logic [DATA_WIDTH-1:0]                 write_Data_2,
	// Write Port
	input  logic                                  write_En_3  ,
	input  logic [ADDR_WIDTH-1:0]                 write_Addr_3,
	input  logic [DATA_WIDTH-1:0]                 write_Data_3,
	// Read Port
	input  logic [READ_PORTS-1:0][ADDR_WIDTH-1:0] read_Addr   ,
	output logic [READ_PORTS-1:0][DATA_WIDTH-1:0] data_Out
);
	// #Internal Signals#
	logic [SIZE-1:0][DATA_WIDTH-1 : 0] RegFile;
	//debug
	logic [31:0] x1_ra_w  ,x2_sp_w  ,x3_gp_w  ,x4_tp_w  ,x5_t0_w  ,x6_t1_w  ,x7_t2_w  ,x8_s0_w  ,x9_s1_w  ,x10_a0_w ,v2_x11_a1_w ,r1_x12_a2_w ,v1_x13_a3_w ,x14_a4_w ,x15_a5_w ,r2_x16_a6_w ,x17_a7_w ,x18_s2_w ,x19_s3_w ,x20_s4_w ,x21_s5_w ,x22_s6_w ,x23_s7_w ,x24_s8_w ,x25_s9_w ,x26_s10_w,x27_s11_w,x28_t3_w ,x29_t4_w ,x30_t5_w ,x31_t6_w;

    assign x1_ra_w   = RegFile[1];
    assign x2_sp_w   = RegFile[2];
    assign x3_gp_w   = RegFile[3];
    assign x4_tp_w   = RegFile[4];
    assign x5_t0_w   = RegFile[5];
    assign x6_t1_w   = RegFile[6];
    assign x7_t2_w   = RegFile[7];
    assign x8_s0_w   = RegFile[8];
    assign x9_s1_w   = RegFile[9];
    assign x10_a0_w  = RegFile[10];
    assign v2_x11_a1_w  = RegFile[11];
    assign r1_x12_a2_w  = RegFile[12];
    assign v1_x13_a3_w  = RegFile[13];
    assign x14_a4_w  = RegFile[14];
    assign x15_a5_w  = RegFile[15];
    assign r2_x16_a6_w  = RegFile[16];
    assign x17_a7_w  = RegFile[17];
    assign x18_s2_w  = RegFile[18];
    assign x19_s3_w  = RegFile[19];
    assign x20_s4_w  = RegFile[20];
    assign x21_s5_w  = RegFile[21];
    assign x22_s6_w  = RegFile[22];
    assign x23_s7_w  = RegFile[23];
    assign x24_s8_w  = RegFile[24];
    assign x25_s9_w  = RegFile[25];
    assign x26_s10_w = RegFile[26];
    assign x27_s11_w = RegFile[27];
    assign x28_t3_w  = RegFile[28];
    assign x29_t4_w  = RegFile[29];
    assign x30_t5_w  = RegFile[30];
    assign x31_t6_w  = RegFile[31];

    //x0 is not allow to write
	logic not_zero, not_zero_2, not_zero_3;
    assign not_zero   = |write_Addr;
	assign not_zero_2 = |write_Addr_2;
	assign not_zero_3 = |write_Addr_3;
	//Create OH signals
	logic [SIZE-1:0] address_1, address_2,address_3;
	assign address_1 = 1 << write_Addr;
	assign address_2 = 1 << write_Addr_2;
	assign address_3 = 1 << write_Addr_3;
	//Write Data
	always_ff @(posedge clk or negedge rst_n) begin : WriteData
		if(!rst_n) begin
			for (int i = 0; i < SIZE; i++) begin
				RegFile[i] <= 'b0;
			end
		end 
		else begin
			for (int i = 0; i < SIZE; i++) begin
				if(write_En_3 && not_zero_3 && address_3[i]) begin
					RegFile[i] <= write_Data_3;
				end
				else if(write_En_2 && not_zero_2 && address_2[i]) begin
					RegFile[i] <= write_Data_2;
				end 
				else if(write_En && not_zero && address_1[i]) begin
					RegFile[i] <= write_Data;
				end
			end
		end
	end
	//Output Data
	always_comb begin : ReadData
		for (int i = 0; i < READ_PORTS; i++) begin		
			data_Out[i] = RegFile[read_Addr[i]];		
		end
	end
endmodule