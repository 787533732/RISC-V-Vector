module btb 
#(
    parameter int SIZE = 64
) 
(
    input  logic                clk       ,
    input  logic                rst_n     ,
    //Update Interface
    input  logic                wr_en     ,
    input  logic [31:0]         orig_pc   ,
    input  logic [31:0]         target_pc ,
    input  logic [1:0]          br_type   ,
    //Invalidation Interface
    input  logic                invalidate,
    input  logic [31:0]         pc_invalid,
    //Access Interface
    input  logic [31:0]         pc_in_a   ,
    input  logic [31:0]         pc_in_b   ,
    //Output Ports
    output logic                hit_a     ,
    output logic [31:0]         next_pc_a ,
    output logic [1:0]          br_type_a ,
    output logic                hit_b     ,
    output logic [31:0]         next_pc_b ,
    output logic [1:0]          br_type_b
);
    localparam SEL_BITS      = $clog2(SIZE);
    localparam SEL_BITS_3    = SEL_BITS-3;
    localparam BTB_TAG_WIDTH = 30-SEL_BITS;
	// #Internal Signals#
    logic [1:0][63:0]           data_out;
    logic [1:0][SEL_BITS-1:0]   read_addresses;
    logic [SEL_BITS-1:0]        line_selector_a, line_selector_b, line_write_selector, line_inv_selector;
    logic [63:0]                retrieved_data_a, retrieved_data_b, new_data;
    logic [SIZE-1:0]            validity;
    logic                       masked_wr_en;

    assign line_selector_a = pc_in_a[SEL_BITS+2:3];
    assign line_selector_b = pc_in_b[SEL_BITS+2:3];
    //Create the line selector for the write operation
    assign line_write_selector = orig_pc[SEL_BITS+1:3];
	//Create the new Data to be stored ([orig_pc/target_pc])
	assign new_data            = {{SEL_BITS_3{1'b0}}, br_type, orig_pc[31:SEL_BITS+3], target_pc};
	//Create the Invalidation line selector
	assign line_inv_selector   = pc_invalid[SEL_BITS+1 : 2];

    assign read_addresses[0] = line_selector_a;
    assign read_addresses[1] = line_selector_b;
    sram 
    #(
        .SIZE        (SIZE),
        .DATA_WIDTH  (64),
        .RD_PORTS    (2),
        .WR_PORTS    (1),
        .RESETABLE   (1)
    ) u_sram
    (
        .clk                 (clk),
        .rst_n               (rst_n),
        .wr_en               (wr_en),
        .read_address        (read_addresses),
        .data_out            (data_out),
        .write_address       (line_write_selector),
        .new_data            (new_data)
    );

    //always output the target PC
    assign retrieved_data_a = data_out[0];
    assign retrieved_data_b = data_out[1];
    assign next_pc_a        = retrieved_data_a[0+:32];
    assign next_pc_b        = retrieved_data_b[0+:32];
    assign br_type_a        = retrieved_data_a[62-SEL_BITS+:2];
    assign br_type_b        = retrieved_data_b[62-SEL_BITS+:2]; 
    assign hit_a = validity[line_selector_a] ? retrieved_data_a[32 +: BTB_TAG_WIDTH]==pc_in_a[31:SEL_BITS+2] : 1'b0;
    assign hit_b = validity[line_selector_b] ? retrieved_data_b[32 +: BTB_TAG_WIDTH]==pc_in_b[31:SEL_BITS+2] : 1'b0;

    assign masked_wr_en = invalidate ? wr_en & (line_inv_selector!=line_write_selector) : wr_en;
	always_ff @(posedge clk or negedge rst_n) begin : ValidityBits
		if(!rst_n) begin
			 validity[SIZE-1:0]    <= 'd0;
		end else begin
			 if(invalidate) begin
			 	validity[line_inv_selector] <= 0;
			 end
             if(masked_wr_en) begin
			 	validity[line_write_selector] <= 1;
			 end
		end
	end

endmodule