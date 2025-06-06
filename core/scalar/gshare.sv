module gshare 
#(
	parameter HISTORY_BITS     = 4	,
	parameter SIZE		       = 2048,
	parameter PHT_SHARE_ENABLE = 1  
) 
(
	input  logic               	clk           ,
	input  logic               	rst_n         ,
	//Update Interface
	input  logic               	must_flush    ,
	input  logic               	wr_en         ,
	input  logic [31:0] 		orig_pc       ,
	input  logic               	is_taken	  ,
	//Access Interface
	input  logic [31:0] 		pc_in_a       ,//是否需要对两个PC进行分支预测
	input  logic [1:0] 		    br_type_a     ,
	input  logic [31:0] 		pc_in_b       ,//是否需要对两个PC进行分支预测
	input  logic [1:0] 		    br_type_b     ,
	//Output Interface
	output logic               	is_taken_out_a,
	output logic               	is_taken_out_b
);
	localparam SEL_BITS = $clog2(SIZE);
	logic [SEL_BITS-3:0] 		line_selector_a, line_selector_b,write_line_selector;
	logic [SEL_BITS-1:0] 		counter_selector_a, counter_selector_b,write_counter_selector;
	logic [HISTORY_BITS-1:0] 	gl_history,next_ghr,suspect_gl_history;
	logic 						same_pc;
	logic [1:0] 				retrieved_counter_a, retrieved_counter_b, old_counter, final_value;
	logic [7:0] 				retrieved_data_a, retrieved_data_b, write_retrieved_data, new_counter_vector;
	logic [2:0] 				starting_bit_a, starting_bit_b;
	logic [2:0] 				write_counter_start_bit;
	logic [2:0][SEL_BITS-3:0]	read_addresses;
	logic [2:0][7:0] 			data_out;
//-------------------------------寻址饱和计数器进行分支预测--------------------------------------//

generate 
	if(PHT_SHARE_ENABLE) begin
		//read pht
		assign counter_selector_a = {{pc_in_a[SEL_BITS+2 : HISTORY_BITS+3]}, {suspect_gl_history ^ pc_in_a[HISTORY_BITS+2 : 3]}};
		assign counter_selector_b = {{pc_in_b[SEL_BITS+2 : HISTORY_BITS+3]}, {suspect_gl_history ^ pc_in_b[HISTORY_BITS+2 : 3]}};
		assign line_selector_a = counter_selector_a[SEL_BITS-1 : 2];
		assign line_selector_b = counter_selector_b[SEL_BITS-1 : 2];
		//write pht
		assign write_counter_selector = {{orig_pc[SEL_BITS+2 : HISTORY_BITS+3]}, {suspect_gl_history ^ orig_pc[HISTORY_BITS+2 : 3]}};
		assign write_line_selector    = write_counter_selector[SEL_BITS-1 : 2];
	end
	else begin
		//read pht
		assign counter_selector_a = {{pc_in_a[SEL_BITS+1 : HISTORY_BITS+2]}, {suspect_gl_history ^ pc_in_a[HISTORY_BITS+1 : 2]}};
		assign counter_selector_b = {{pc_in_b[SEL_BITS+1 : HISTORY_BITS+2]}, {suspect_gl_history ^ pc_in_b[HISTORY_BITS+1 : 2]}};
		assign line_selector_a = counter_selector_a[SEL_BITS-1 : 2];
		assign line_selector_b = counter_selector_b[SEL_BITS-1 : 2];
		//write pht
		assign write_counter_selector = {{orig_pc[SEL_BITS+1 : HISTORY_BITS+2]}, {suspect_gl_history ^ orig_pc[HISTORY_BITS+1 : 2]}};
		assign write_line_selector    = write_counter_selector[SEL_BITS-1 : 2];
	end
endgenerate	 
	//从一行PHT(4个)中选中其中一个
	assign starting_bit_a      = {{counter_selector_a[1:0]}, 1'b0};
	assign starting_bit_b      = {{counter_selector_b[1:0]}, 1'b0};
	assign retrieved_counter_a = retrieved_data_a[starting_bit_a +: 2];
	assign retrieved_counter_b = retrieved_data_b[starting_bit_b +: 2]; 
	//根据2bit饱和计数器预测
	assign is_taken_out_a = br_type_a[1] ? 1'b1 : retrieved_counter_a[1];
	assign is_taken_out_b = br_type_b[1] ? 1'b1 : retrieved_counter_b[1];

	assign read_addresses[0] = line_selector_a;
	assign read_addresses[1] = line_selector_b;
	assign read_addresses[2] = write_line_selector;
	//-------PHT-------// 
	//------sram-------// 
	//------8bit-------// 
	//  xx  xx  xx  xx // 
	//.................//
	//.................//
	//.................//
	//.................//
	//  xx  xx  xx  xx //
	parameter SRAM_SIZE = SIZE >> 2;
	sram 
	#(
		.SIZE      (SRAM_SIZE),
		.DATA_WIDTH(8   	 ),
		.RD_PORTS  (3   	 ),
		.WR_PORTS  (1   	 ),
		.RESETABLE (1   	 )
	)
	pht_sram 
	(
		.clk          (clk                ),
		.rst_n        (rst_n              ),
		.wr_en        (wr_en              ),
		.read_address (read_addresses     ),
		.data_out     (data_out           ),
		.write_address(write_line_selector),
		.new_data     (new_counter_vector )
	);

	assign retrieved_data_a     = data_out[0];
	assign retrieved_data_b     = data_out[1];
	assign write_retrieved_data = data_out[2];
//-------------------------------update PHT--------------------------------------//

	assign write_counter_start_bit = {{write_counter_selector[1:0]}, 1'b0};
	//读出旧饱和计数器的值（8bit）
	assign old_counter = write_retrieved_data[write_counter_start_bit +: 2];
	//更新对应饱和计数器
	always_comb begin 
		if(is_taken) 
			if(&old_counter) 
				final_value = old_counter;
			else 
				final_value = old_counter+1;
		else 
			if(~|old_counter)
				final_value = old_counter;
			else 
				final_value = old_counter-1;
		new_counter_vector                             = write_retrieved_data;
		new_counter_vector[write_counter_start_bit+:2] = final_value;
	end
	logic [31:0] last_pc_a,last_pc_b;
	logic [1:0]  last_type_a,last_type_b;
	always_ff@(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			last_pc_b <= 'b0;
			last_type_b <= 'b0;
		end
		else begin
			last_pc_b <= pc_in_b;
			last_type_b <= br_type_b;
		end
	end
	always_ff@(posedge clk or negedge rst_n) begin
		if(!rst_n) 
			last_pc_a <= 'b0;
		else
			last_pc_a <= pc_in_a;
	end
	
	assign same_pc = |last_type_b &  (last_pc_b == pc_in_a) ;
	
	logic delayed_flush;
	always_ff@(posedge clk or negedge rst_n) begin 
		if(!rst_n)
			delayed_flush <= 'b0;
		else
			delayed_flush <= must_flush;
	end
	
//可以添加一个立即更新的GHR，但需要增加一个预解码模块找出分支指令
	always_ff @(posedge clk or negedge rst_n) begin 
		if(!rst_n)//reset global history
			suspect_gl_history <= 'b0;
		else 
			suspect_gl_history <= next_ghr;
	end

	always_comb begin
		if(must_flush)
			next_ghr = {gl_history[HISTORY_BITS-2:0],is_taken};
		else if(!same_pc & ((|br_type_a) | (|br_type_b))) //Update Global History by sliding
			next_ghr = {suspect_gl_history[HISTORY_BITS-2:0],(is_taken_out_a|is_taken_out_b )};
		else 
			next_ghr = suspect_gl_history;
	end
	
//-------------------------------备份GHR--------------------------------------//
	always_ff @(posedge clk or negedge rst_n) begin 
		if(!rst_n) begin//reset global history
			gl_history <= 'b0;
		end else begin
			if(wr_en) begin//Update Global History by sliding
				gl_history <= {gl_history[HISTORY_BITS-2:0],is_taken};
			end
		end
	end

endmodule