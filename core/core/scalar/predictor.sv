module predictor
#(
	parameter GHR_BITS 		   = 4	 ,
	parameter PHT_SIZE         = 2048,
	parameter BTB_SIZE         = 64  ,
	parameter RAS_DEPTH        = 8	 ,
	parameter PHT_SHARE_ENABLE = 1
)									
(
    input  logic 				clk				,
    input  logic 				rst_n			,
    //Control Interface
    input  logic 				must_flush		,
    input  logic 				is_branch		,
    input  logic 				branch_resolved	,
    //Update Interface
    input  logic                new_entry		,
    input  logic [31:0]         pc_orig			,
    input  logic [31:0]         target_pc		,
    input  logic                is_taken		,
	input  logic [1:0]		    br_type			,
    //RAS Interface
    input  logic                is_return		,
    input  logic                is_call		,
    input  logic 			    invalidate		,
    input  logic [31:0]         old_pc			,
    //Access Interface          
    input  logic [31:0]         pc_in			,
    output logic				taken_branch_a	,
    output logic [31:0]         next_pc_a		,
    output logic				taken_branch_b	,
    output logic [31:0]         next_pc_b
);

	logic [31:0] pc_in_2, next_pc_btb_a, next_pc_btb_b, pc_out_ras, new_entry_ras;
	logic hit_btb_a, hit_btb_b, pop, push, is_empty_ras, is_taken_out_a, is_taken_out_b;
	logic [1:0] br_type_a,br_type_b;
	assign pc_in_2        = pc_in + 4;
	assign taken_branch_a = (hit_btb_a & is_taken_out_a);
	assign taken_branch_b = (hit_btb_b & is_taken_out_b);

	gshare 
    #(
		.HISTORY_BITS		(GHR_BITS		 ),
		.SIZE        		(PHT_SIZE        ),
		.PHT_SHARE_ENABLE 	(PHT_SHARE_ENABLE)
	)
	gshare 
    (
		.clk           		(clk           	),
		.rst_n         		(rst_n         	),
		//Update Interface	
		.must_flush	   		(must_flush    	),
		.wr_en         		(new_entry     	),
		.is_taken      		(is_taken      	),
		.orig_pc       		(pc_orig       	),
		//Access Interface	
		.pc_in_a       		(pc_in         	),
		.br_type_a	   		(br_type_a     	),
		.pc_in_b       		(pc_in_2       	),
		.br_type_b	   		(br_type_b     	),
		//Output Interface	
		.is_taken_out_a		(is_taken_out_a	),
		.is_taken_out_b		(is_taken_out_b	)
	);
	//direct mapped btb
	btb 
	#(
		.SIZE   			(BTB_SIZE	)
	)
	btb 
	(
		.clk       			(clk          ),
		.rst_n     			(rst_n        ),
		//Update Interface
		.wr_en     			(new_entry    ),
		.orig_pc   			(pc_orig      ),
		.target_pc 			(target_pc    ),
		.br_type			(br_type      ),
		//Invalidation Interface
		.invalidate			(invalidate   ),
		.pc_invalid			(old_pc       ),
		//Access Interface
		.pc_in_a   			(pc_in        ),
		.pc_in_b   			(pc_in_2      ),
		//Output Ports 
		.hit_a     			(hit_btb_a    ),
		.next_pc_a 			(next_pc_btb_a),
		.br_type_a	    	(br_type_a    ),
		.hit_b     			(hit_btb_b    ),
		.next_pc_b 			(next_pc_btb_b),
		.br_type_b	    	(br_type_b    )
	);

	assign pop  = (is_return & ~is_empty_ras);					
	assign push = is_call;
	assign new_entry_ras = old_pc +4;
	//Initialize the RAS
	ras 
	#(
		.SIZE   		(RAS_DEPTH			  )
	)
	 ras 
	(
		.clk            (clk                  ),
		.rst_n          (rst_n                ),
		
		.must_flush     (must_flush           ),
		.is_branch      (is_branch & ~is_call),
		.branch_resolved(branch_resolved      ),
		
		.pop            (pop                  ),
		.push           (push                 ),
		.new_entry      (new_entry_ras        ),
		.pc_out         (pc_out_ras           ),
		.is_empty       (is_empty_ras         )
	);
	//push the Correct PC to the Output
	always_comb begin 
		if(pop) begin
			next_pc_a = pc_out_ras;
		end else if(hit_btb_a && is_taken_out_a) begin
			next_pc_a = next_pc_btb_a;
		end else begin
			next_pc_a = pc_in+8;
		end
	end
	always_comb begin 
		if(pop) begin
			next_pc_b = pc_out_ras;
		end else if(hit_btb_b && is_taken_out_b) begin
			next_pc_b = next_pc_btb_b;
		end else begin
			next_pc_b = pc_in_2+8;
		end
	end
endmodule