module rv32im_vector
(
    input   logic                       clk                 ,
    input   logic                       rst_n               ,
    input   logic                       external_interrupt  ,
    input   logic                       timer_interrupt      
//AXI Interface
    //Write request channel
    //output  logic                       awvalid             ,
    //input   logic                       awready             ,
    //output  logic [31:0]                awaddr              ,
    //output  logic [ 3:0]                awid                ,
    //output  logic [ 7:0]                awlen               ,
    //output  logic [ 2:0]                awsize              ,
    //output  logic [ 1:0]                awburst             ,
    ////Write data channel
    //output  logic                       wvalid              , 
    //input   logic                       wready              , 
    //output  logic [31:0]                wdata               ,  
    //output  logic                       wlast               ,  
    ////Write response channel
    //input   logic                       bvalid              ,         
    //output  logic                       bready              ,         
    //input   logic [ 3:0]                bid                 ,        
    //input   logic [ 1:0]                bresp               ,          
    //input   logic                       blast               ,          
    ////read req channel
    //output  logic                       arvalid             ,
    //input   logic                       arready             ,
    //output  logic [31:0]                araddr              ,
    //output  logic [ 3:0]                arid                ,
    //output  logic [ 7:0]                arlen               ,
    //output  logic [ 1:0]                arburst             ,
    ////read data channel      
    //input   logic                       rvalid              ,                   
    //output  logic                       rready              ,                   
    //input   logic [31:0]                rdata               ,                    
    //input   logic [ 1:0]                rresp               ,                    
    //input   logic [ 3:0]                rid                 ,                  
    //input   logic                       rlast                                   
);
    //Memory System Parameters
    //8KB I-Cache
    localparam ICACHE_ENTRIES       = 256;
    localparam ICACHE_DATAWIDTH     = 128;
    //16KB D-Cache
    localparam DCACHE_ENTRIES       = 64;
    localparam DCACHE_DATAWIDTH     = 256;
    localparam L2_ENTRIES           = 40960;
    localparam L2_DATAWIDTH         = 512 ;
    localparam REALISTIC            = 1   ;
    localparam DELAY_CYCLES         = 4  ;
    //Other Parameters  (DO NOT MODIFY)
    localparam ADDR_BITS      = 32        ; //default: 32
    localparam FETCH_WIDTH    = 64        ; //default: 64
    localparam R_WIDTH        = 6         ; //default: 6
    localparam MICROOP_W      = 5         ; //default: 5
    //Vector Parameters

    localparam VECTOR_ENABLED   = 1;
    localparam VECTOR_LANES     = 8;
    localparam VECTOR_MICROOP_WIDTH = 7; 
    localparam VECTOR_REQ_WIDTH     = 256; 
    //===================================================================================
    logic                               icache_valid_i      ;
    logic                               dcache_valid_i      ;
    logic                               cache_store_valid   ;
    logic                               icache_valid_o      ;
    logic                               dcache_valid_o      ;
    logic                               cache_load_valid    ;
    logic                               write_l2_valid      ;
    logic [   ADDR_BITS-1:0]            icache_address_i    ;
    logic [   ADDR_BITS-1:0]            dcache_address_i    ;
    logic [   ADDR_BITS-1:0]            cache_store_addr    ;
    logic [   ADDR_BITS-1:0]            icache_address_o    ;
    logic [   ADDR_BITS-1:0]            dcache_address_o    ;
    logic [   ADDR_BITS-1:0]            write_l2_addr       ;
    logic [   ADDR_BITS-1:0]            cache_load_addr     ;
    logic [       DCACHE_DATAWIDTH-1:0] write_l2_data;
    logic [       DCACHE_DATAWIDTH-1:0] dcache_data_o;
    logic [31:0]                        cache_store_data    ;
    logic [       ICACHE_DATAWIDTH-1:0] icache_data_o;
    logic [   ADDR_BITS-1:0]            current_pc          ;
    logic                               hit_icache          ;
    logic                               miss_icache         ;
    logic                               partial_access      ;
    logic [ FETCH_WIDTH-1:0]            fetched_data        ;
    logic                               cache_store_uncached;
    logic                               cache_store_cached  ;
    logic [     R_WIDTH-1:0]            cache_load_dest     ;
    logic [   MICROOP_W-1:0]            cache_load_microop  ;
    logic [   MICROOP_W-1:0]            cache_store_microop ;
    logic [2:0]                         cache_load_ticket   ;
    logic [             1:0]            partial_type        ;
    ex_update                           cache_fu_update     ;
    logic                               cache_will_block    ;
    logic                               cache_blocked       ;
    logic                               cache_store_blocked ;
    logic                               cache_load_blocked  ;

    logic                               frame_buffer_write  ;
    logic [15:0]                        frame_buffer_data   ;
    logic [14:0]                        frame_buffer_address;
    logic [ 7:0]                        red_o, green_o, blue_o;
    logic [ 4:0]                        color               ;
    //logic                    vector_flush_valid;
    logic                               vector_valid;      
    to_vector                           vector_instruction;
    logic                               vector_ready;
    logic                               mem_req_valid_o;
    vector_mem_req                      mem_req_o;       
    logic                               cache_ready_i;   
    logic                               mem_resp_valid_i;
    vector_mem_resp                     mem_resp_i;   
    logic [ 5:0]                        wr_addr;         
    logic                               wren_scalar;     
    logic [31:0]                        wren_scalar_data; 
    logic                               vmu_idle; 
    logic                               ld_st_output_used,viq_no_ls_infight;     
    processor_top 
    #(

        .GHR_BITS               (4              ),        
        .PHT_SIZE               (2048           ),        
        .BTB_SIZE               (64             ),        
        .RAS_DEPTH              (8              ),       
        .IBUF_DEEP              (4              ),       
        .MICROOP_WIDTH          (5              ),       
        .ISSUEQUEUE_DEPTH       (4              ),        
        .CSR_DEPTH              (64             ),       
        .VECTOR_ENABLED         (VECTOR_ENABLED ),
        .VECTOR_LANES           (VECTOR_LANES   )
    )
    u_processor
    (
        .clk                    (clk  ),
        .rst_n                  (rst_n),
        .external_interrupt     (external_interrupt),
        .timer_interrupt        (timer_interrupt),
        .vector_valid           (vector_valid      ),        
        .vector_instruction     (vector_instruction),
        .vector_ready           (vector_ready      ),     
        //Input from ICache     
        .current_pc             (current_pc      ),
        .hit_icache             (hit_icache      ),
        .miss_icache            (miss_icache     ),
        .partial_access         (partial_access  ),
        .partial_type           (partial_type    ),
        .fetched_data           (fetched_data    ),

        .cache_wb_valid_o       (cache_store_cached ),
        .cache_wb_addr_o        (cache_store_addr   ),
        .cache_wb_data_o        (cache_store_data   ),
        .cache_wb_microop_o     (cache_store_microop),
        // Load for DCache  
        .cache_load_valid       (cache_load_valid  ),
        .cache_load_addr        (cache_load_addr   ),
        .cache_load_dest        (cache_load_dest   ),
        .cache_load_microop     (cache_load_microop),
        .cache_load_ticket      (cache_load_ticket ),
        //Misc
        .cache_fu_update        (cache_fu_update),
        .cache_store_blocked    (cache_store_blocked),
        .cache_load_blocked     (cache_load_blocked),
        .cache_will_block       (),
        .ld_st_output_used      (ld_st_output_used),
        //vector core write scalar reg
        .wr_addr                (wr_addr           ),
        .wren_scalar            (wren_scalar       ),     
        .wren_scalar_data       (wren_scalar_data  ) 
    );

    generate if(VECTOR_ENABLED) begin : vector_processor
        vector_top
        #(
            .VIQ_DEPTH          (400 ),
            .VECTOR_TICKET_BITS (4 ),
            .VECTOR_LANES       (VECTOR_LANES)    
        )vector_cpu
        (
            .clk                 (clk  ),
            .rst_n               (rst_n),

            //.vector_flush_valid  (vector_flush_valid), 
            .vector_valid        (vector_valid      ),
            .vector_ready        (vector_ready      ),
            .vector_instruction  (vector_instruction),

            //Cache Request Interface
        	.mem_req_valid_o     (mem_req_valid_o   ),
        	.mem_req_o           (mem_req_o         ),
            .vmu_idle            (vmu_idle          ),
            .no_ls_infight       (viq_no_ls_infight ),
        	.cache_ready_i       (cache_ready_i     ),
        	//Cache Response Interface  
        	.mem_resp_valid_i    (mem_resp_valid_i  ), 
        	.mem_resp_i          (mem_resp_i        ),
            //write scalar reg
            .wr_addr             (wr_addr           ),
            .wren_scalar         (wren_scalar       ),     
            .wren_scalar_data    (wren_scalar_data  ) 
        );
        end
    endgenerate
    data_cache 
    #(
        .ADDR_BITS              (ADDR_BITS           ), 
        .R_WIDTH                (R_WIDTH             ),
        .MICROOP                (MICROOP_W           ),
        .ROB_TICKET             ( 3       ),
        .ENTRIES                (DCACHE_ENTRIES      ),
        .BLOCK_WIDTH            (DCACHE_DATAWIDTH    ),
        .BUFFER_SIZES           (40                  ),
        .VECTOR_ENABLED         (VECTOR_ENABLED      ),
        .VECTOR_MICROOP_WIDTH   (VECTOR_MICROOP_WIDTH),          
        .VECTOR_REQ_WIDTH       (VECTOR_REQ_WIDTH    ),          
        .VECTOR_LANES           (VECTOR_LANES        )          
    ) 
    data_cache 
    (
        .clk                 (clk                ),
        .rst_n               (rst_n              ),
        .output_used         (ld_st_output_used  ),
        //Load Input Port 
        .load_valid          (cache_load_valid  ),
        .load_address        (cache_load_addr   ),
        .load_dest           (cache_load_dest   ),
        .load_microop        (cache_load_microop),
        .load_ticket         (cache_load_ticket ),
        //Store Input Port 
        .store_valid         (cache_store_cached ),
        .store_address       (cache_store_addr   ),
        .store_data          (cache_store_data   ),
        .store_microop       (cache_store_microop),
        //Request Write Port to L2
        .write_l2_valid      (write_l2_valid     ),
        .write_l2_addr       (write_l2_addr      ),
        .write_l2_data       (write_l2_data      ),
        //Request Read Port to L2
        .request_l2_valid    (dcache_valid_i     ),
        .request_l2_addr     (dcache_address_i   ),
        // Update Port from L2
        .update_l2_valid     (dcache_valid_o     ),
        .update_l2_addr      (dcache_address_o   ),
        .update_l2_data      (dcache_data_o      ),
        //Output Port 
        .cache_will_block    (cache_will_block   ),
        .cache_store_blocked (cache_store_blocked),
        .cache_load_blocked  (cache_load_blocked ),
        .served_output       (cache_fu_update    ),
//
        .mem_req_valid_i     (mem_req_valid_o    ),
        .mem_req_i           (mem_req_o          ),
        .vmu_idle            (vmu_idle           ),
        .viq_no_ls_infight   (viq_no_ls_infight  ),
        .cache_vector_ready_o(cache_ready_i      ),
        .vector_resp_valid_o (mem_resp_valid_i   ),
        .vector_resp         (mem_resp_i         )
    );
    icache 
    #(
        .ENTRIES                (ICACHE_ENTRIES),
        .BLOCK_WIDTH            (ICACHE_DATAWIDTH)
    )
    u_icache 
    (
        .clk                    (clk             ),
        .rst_n                  (rst_n           ),

		.address                (current_pc      ),
		.hit                    (hit_icache      ),
		.miss                   (miss_icache     ),
		.partial_access         (partial_access  ),
		.partial_type           (partial_type    ),
		.fetched_data           (fetched_data    ),

        .valid_o                (icache_valid_i  ),
        .ready_in               (icache_valid_o  ),
        .address_out            (icache_address_i),
        .data_in                (icache_data_o   )
    );
    main_memory  
    #(
        .L2_BLOCK_DW     (512) ,
        .L2_ENTRIES      (L2_ENTRIES),
        .ADDRESS_BITS    (32),
        .ICACHE_BLOCK_DW (ICACHE_DATAWIDTH),
        .DCACHE_BLOCK_DW (DCACHE_DATAWIDTH),
        .REALISTIC       (REALISTIC),
        .DELAY_CYCLES    (DELAY_CYCLES)  
    )u_main_memory
    (
        .clk              (clk             ),
        .rst_n            (rst_n           ),
        .ready            (                ),
        //Read Request Input from ICache
        .icache_valid_i   (icache_valid_i  ),
        .icache_address_i (icache_address_i),
        //Output to ICache
        .icache_valid_o   (icache_valid_o  ),
        //.icache_address_o (icache_address_o),
        .icache_data_o    (icache_data_o   ),
        //Read Request Input from DCache
        .dcache_valid_i   (dcache_valid_i  ),
        .dcache_address_i (dcache_address_i),
        //Output to DCache
        .dcache_valid_o   (dcache_valid_o  ),
        .dcache_address_o (dcache_address_o),
        .dcache_data_o    (dcache_data_o   ),
        //Write Request Input from DCache
        .dcache_valid_wr  (write_l2_valid  ),
        .dcache_address_wr(write_l2_addr   ),
        .dcache_data_wr   (write_l2_data   ),
//AXI Interface
    //Write request channel
        .awvalid          (),     
        .awready          (),     
        .awaddr           (),  
        .awid             (),    
        .awlen            (),   
        .awsize           (),  
        .awburst          (),     
    //Write data channel
        .wvalid           (),
        .wready           (),
        .wdata            (),
        .wlast            (),
    //Write response channel
        .bvalid           (), 
        .bready           (), 
        .bid              (),    
        .bresp            (),  
        .blast            (),  
    //read req channel
        .arvalid          (),
        .arready          (),
        .araddr           (),
        .arid             (),
        .arlen            (),
        .arburst          (),
    //read data channel    
        .rvalid           (), 
        .rready           (), 
        .rdata            (), 
        .rresp            (), 
        .rid              (), 
        .rlast            () 
    );
endmodule