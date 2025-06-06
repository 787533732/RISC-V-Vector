module soc
(
    input   logic                   clk                 ,
    input   logic                   rst_n               ,
    input   logic                   external_interrupt  ,
    input   logic                   timer_interrupt        
);

    logic                           awvalid;
    logic                           awready;
    logic [31:0]                    awaddr; 
    logic [ 3:0]                    awid;   
    logic [ 7:0]                    awlen;  
    logic [ 2:0]                    awsize; 
    logic [ 1:0]                    awburst;
//    logic [ 2:0]                    awprot; 
    logic                           wvalid;
    logic [31:0]                    wdata; 
//    logic [ 3:0]                    wstrb; 
    logic                           wlast; 
    logic                           wready;
    logic                           bvalid;
    logic                           bready;
    logic [ 1:0]                    bresp; 
    logic [ 3:0]                    bid; 
    logic                           blast;

    rv32im_vector u_core
    (
        .clk                        (clk                ),
        .rst_n                      (rst_n              ),
        .external_interrupt         (external_interrupt ),
        .timer_interrupt            (timer_interrupt    ) 

       // .awvalid                    (awvalid            ),
       // .awready                    (awready            ),
       // .awaddr                     (awaddr             ),
       // .awid                       (awid               ),
       // .awlen                      (awlen              ),
       // .awsize                     (awsize             ),
       // .awburst                    (awburst            ),
//
       // .wvalid                     (wvalid             ), 
       // .wready                     (wready             ), 
       // .wdata                      (wdata              ),  
       // .wlast                      (wlast              ),  
//
       // .bvalid                     (bvalid             ),         
       // .bready                     (bready             ),         
       // .bid                        (bid                ),        
       // .bresp                      (bresp              ),          
       // .blast                      (                   ),          
//
       // .arvalid                    (),
       // .arready                    (),
       // .araddr                     (),
       // .arid                       (),
       // .arlen                      (),
       // .arburst                    (),
//
       // .rvalid                     (),                   
       // .rready                     (),                   
       // .rdata                      (),                    
       // .rresp                      (),                    
       // .rid                        (),                  
       // .rlast                      ()                    
    );

    axi2apb_bridge async_bridge
    (
        .aclk                       (clk            ),
        .arst_n                     (rst_n          ),

        .awvalid                    (awvalid        ),
        .awready                    (awready        ),
        .awaddr                     (awaddr         ),
        .awid                       (awid           ),
        .awlen                      (awlen          ),
        .awsize                     (awsize         ),
        .awburst                    (awburst        ),
        .awprot                     (3'b0               ), 

        .wvalid                     (wvalid         ),
        .wready                     (wready         ),
        .wdata                      (wdata          ),
        .wstrb                      (4'b1111        ),         
        .wlast                      (wlast          ),

        .bready                     (bready         ),
        .bvalid                     (bvalid         ),
        .bresp                      (bresp          ),
        .bid                        (bid            ),

        .arvalid                    (),
        .araddr                     (),
        .arsize                     (),
        .arlen                      (),
        .arburst                    (),
        .arid                       (),
        .arprot                     (),
        .arready                    (),

        .rready                     (),
        .rvalid                     (),
        .rresp                      (),
        .rlast                      (),
        .rid                        (),
        .rdata                      (),

        .pclk                       (clk),
        .preset_n                   (rst_n),
        .paddr                      (),
        .pwrite                     (),
        .psel                       (),
        .penable                    (),
        .pwdata                     (),
        .pprot                      (),
        .pstrb                      (),
        .prdata                     (),
        .pready                     (1'b1),
        .pslverr                    ()   
    );

endmodule

