
module axi2apb_bridge
#(
    parameter SLAVE_NUM  = 1 ,
    parameter FIFO_WIDTH = 56,
    parameter FIFO_DEPTH = 8
) 
(
    //AXI protocol
    input   logic                           aclk        ,
    input   logic                           arst_n     ,
    // Address write chanel
    input   logic                           awvalid     ,
    output  logic                           awready     ,
    input   logic [31:0]                    awaddr      ,
    input   logic [ 3:0]                    awid        ,
    input   logic [ 7:0]                    awlen       ,
    input   logic [ 2:0]                    awsize      ,
    input   logic [ 1:0]                    awburst     ,
    input   logic [ 2:0]                    awprot      ,
    //write data chanel
    input  logic                            wvalid      ,
    input  logic [31:0]                     wdata       ,
    input  logic [ 3:0]                     wstrb       ,
    input  logic                            wlast       ,
    output logic                            wready      ,
    // address read chanel
    input   logic                           arvalid     ,
    output  logic                           arready     ,
    input   logic [31:0]                    araddr      ,
    input   logic [ 2:0]                    arsize      ,
    input   logic [ 7:0]                    arlen       ,
    input   logic [ 1:0]                    arburst     ,
    input   logic [ 3:0]                    arid        ,
    input   logic [ 2:0]                    arprot      ,
    //write respond chanel
    output logic                            bvalid      ,
    input  logic                            bready      ,
    output logic [ 1:0]                     bresp       ,
    output logic [ 3:0]                     bid         ,
    //read data chanel
    input  logic                            rready      ,
    output logic                            rvalid      ,
    output logic [ 1:0]                     rresp       ,
    output logic                            rlast       ,
    output logic [ 7:0]                     rid         ,
    output logic [31:0]                     rdata       ,
    //APB protocol
    input  logic                            pclk        ,
    input  logic                            preset_n    ,
    output logic [31:0]                     paddr       ,
    output logic                            pwrite      ,
    output logic [SLAVE_NUM-1:0]            psel        ,
    output logic                            penable     ,
    output logic [31:0]                     pwdata      ,
    output logic [2:0]                      pprot       ,
    output logic [3:0]                      pstrb       ,
    input  logic [SLAVE_NUM-1:0][31:0]      prdata      ,
    input  logic [SLAVE_NUM-1:0]            pready      ,
    input  logic [SLAVE_NUM-1:0]            pslverr     
    //reg
    //output logic                            pselReg     ,
    //input                                   preadyReg   ,
    //input                                   pslverrReg  ,
    //input [31:0]                            prdataReg   
);
    localparam IDLE    = 2'b00;
    localparam SETUP   = 2'b01;
    localparam ACCESS  = 2'b10;
    localparam OKAY    = 2'b00;
    localparam EXOKAY  = 2'b01;
    localparam SLVERR  = 2'b10;
    localparam DECERR  = 2'b11;
    localparam PSLVERR = 2'b10;
    logic                           sfifoAwFull;
    logic                           sfifoAwNotFull;
    logic                           sfifoAwEmpty;
    logic                           aw_fifo_valid;
    logic                           fifoAwWe;
    logic                           fifoAwRe;
    logic [31:0]                    sfifoAwAwaddr;
    logic [7:0]                     sfifoAwAwid;
    logic [7:0]                     sfifoAwCtrlAwlen;
    logic [2:0]                     sfifoAwCtrlAwsize;
    logic [1:0]                     sfifoAwCtrlAwburst;
    logic [2:0]                     sfifoAwCtrlAwprot;
    //SFIFO_AR
    logic                           fifoArWe;
    logic                           fifoArRe;
    logic [31:0]                    sfifoArAraddr;
    logic [7:0]                     sfifoArArid;
    logic [7:0]                     sfifoArCtrlArlen;
    logic [2:0]                     sfifoArCtrlArsize;
    logic [1:0]                     sfifoArCtrlArburst;
    logic [2:0]                     sfifoArCtrlArprot;
    //SFIFO_WD
    logic                           sfifoWdFull;
    logic                           sfifoWdNotFull;
    logic                           sfifoWdEmpty;
    logic                           sfifoWdNotEmpty;
    logic                           fifoWdWe;
    logic                           fifoWdRe;
    logic [31:0]                    sfifoWdWdata;
    logic [3:0]                     sfifoWdWstrb;
    //SFIFO_RD
    logic                           sfifoRdFull;
    logic                           sfifoRdNotFull;
    logic                           sfifoRdEmpty;
    logic                           sfifoRdNotEmpty;
    logic                           fifoRdWe;
    logic                           fifoRdRe;
    //RD_CH
    logic[1:0]                      rChRresp;
    //logic                           rChRlast;
    //ARBITER
    logic [1:0]                     abtGrant;
    logic [1:0]                     nextGrant;
    logic [1:0]                     nextSel;
    //DECODER
    logic                           pslverrX;
    logic [31:0]                    prdataX;
    logic                           preadyX;
    logic                           transCompleted;
    logic                           decError;
    logic                           transCntEn;
    logic [31:0]                    startAddr;
    logic [SLAVE_NUM-1:0]           sel;
    logic                           selReg;
    logic [7:0]                     selectLen;
    logic [7:0]                     transferCounter;
    logic                           transfer;
    logic [1:0]                     nextState;
    logic [1:0]                     currentState;
    logic                           fsmCal;
    logic [1:0]                     burstMode;
    logic [31:0]                    incrNextTransAddr;
    logic [31:0]                    wrapNextTransAddr;
    logic [2:0]                     bitNum;
    logic [2:0]                     bit3Addr;
    logic [3:0]                     bit4Addr;
    logic [4:0]                     bit5Addr;
    logic [5:0]                     bit6Addr;
    logic [SLAVE_NUM-1:0]           preadyOut;
    logic [SLAVE_NUM-1:0]           pslverrOut;
    logic [SLAVE_NUM-1:0][31:0]     prdataOut;
    logic [7:0]                     cnt_transfer;
    logic                           update;
    logic                           selRes;
    logic                           transEn;
    logic                           pselRes;
    logic [31:0]                    prdataRegOut;
    //read req channel fifo
    fifo
    #(
        .DW             (52),
        .DEPTH          (FIFO_DEPTH)
    )
    ar_fifo
    (
        .clk            (aclk   ),
        .rst_n          (arst_n),
        //Flush Interface
        .valid_flush    (1'b0),
        // input channel
        .push_data      ({araddr[31:0], arid[3:0], arlen[7:0], arsize[2:0], arburst[1:0], arprot[2:0]}),
        .push           (fifoArWe),
        .ready          (ar_fifo_ready),
        // output channel
        .pop_data       ({sfifoArAraddr[31:0], sfifoArArid[3:0], sfifoArCtrlArlen[7:0], sfifoArCtrlArsize[2:0], sfifoArCtrlArburst[1:0], sfifoArCtrlArprot[2:0]}),
        .valid          (ar_fifo_valid),
        .pop            (fifoArRe)   
    );
    //Logic
    assign arready  = ar_fifo_ready;
    assign fifoArWe = arready & arvalid;
    assign fifoArRe = ar_fifo_valid & transCompleted & abtGrant[0];
    //read resp channel fifo
    fifo 
    #(
        .DW             (38),
        .DEPTH          (FIFO_DEPTH)
    ) 
    rd_fifo
    (
        .clk            (aclk   ),
        .rst_n          (arst_n),
        //Flush Interface
        .valid_flush    (1'b0),
        // input channel
        .push_data      ({prdataX[31:0], rChRresp[1:0], sfifoArArid[3:0]}),
        .push           (fifoRdWe),
        .ready          (rd_fifo_ready),
        // output channel
        .pop_data       ({rdata[31:0], rresp[1:0], rid[3:0]}),
        .valid          (rd_fifo_valid),
        .pop            (fifoRdRe)   
    );
    //Logic
    assign rvalid     = rd_fifo_valid;
    assign fifoRdRe   = rvalid & rready;
    assign transCntEn = (|psel[SLAVE_NUM-1:0] | pselRes) & penable & preadyX;
    assign fifoRdWe   = rd_fifo_ready & transCntEn & ~pwrite;
    //RD_CH
    //rChRresp
    always_comb begin
      if(~pslverrX)
    	  rChRresp = OKAY;
    	else if(decError)
    	  rChRresp = DECERR;
    	else
    	  rChRresp = PSLVERR;
    end
    //rlast
    always_comb begin
      if(transCompleted & abtGrant[0])
    	  rlast = 1'b1;
    	else
        rlast = 1'b0;	
    end
    //write req channel fifo
    fifo 
    #(
        .DW             (52),
        .DEPTH          (FIFO_DEPTH)
    ) 
    aw_fifo
    (
        .clk            (aclk   ),
        .rst_n          (arst_n ),
        //Flush Interface
        .valid_flush    (1'b0),
        // input channel
        .push_data      ({awaddr[31:0], awid[3:0], awlen[7:0], awsize[2:0], awburst[1:0], awprot[2:0]}),
        .push           (fifoAwWe),
        .ready          (aw_fifo_ready),
        // output channel
        .pop_data       ({sfifoAwAwaddr[31:0], sfifoAwAwid[3:0], sfifoAwCtrlAwlen[7:0], sfifoAwCtrlAwsize[2:0], sfifoAwCtrlAwburst[1:0], sfifoAwCtrlAwprot[2:0]}),
        .valid          (aw_fifo_valid),
        .pop            (fifoAwRe)   
    );
    //Logic
    assign awready  = aw_fifo_ready;
    assign fifoAwWe = awready & awvalid;
    assign fifoAwRe = aw_fifo_valid & transCompleted & abtGrant[1];
    //write data channel fifo
    fifo 
    #(
        .DW             (36),
        .DEPTH          (FIFO_DEPTH)
    ) 
    wd_fifo
    (
        .clk            (aclk   ),
        .rst_n          (arst_n ),
        //Flush Interface
        .valid_flush    (1'b0),
        // input channel
        .push_data      ({wdata[31:0], wstrb[3:0]}),
        .push           (fifoWdWe),
        .ready          (wd_fifo_ready),
        // output channel
        .pop_data       ({sfifoWdWdata[31:0], sfifoWdWstrb[3:0]}),
        .valid          (wd_fifo_valid),
        .pop            (fifoWdRe)   
    );
    //logic
    assign wready          = wd_fifo_ready;
    assign fifoWdWe       = wvalid & wready;
    assign fifoWdRe       = wd_fifo_valid & abtGrant[1] & (currentState == ACCESS);

    //B_CH
    //bresp
    always_ff @(posedge aclk, negedge arst_n) begin
      if(~arst_n)
    	  bresp[1:0] <= OKAY;
      else if(transCompleted & abtGrant[1]) begin
    	  if(~pslverrX)
    	    bresp[1:0] <= OKAY;
    	  else if(decError)
    	    bresp[1:0] <= DECERR;
        else
    	    bresp[1:0] <= PSLVERR;
    	end
    end
    //bid
    assign bid = 'b1;
    //bvalid
    always_ff @(posedge aclk, negedge arst_n) begin
      if(~arst_n)
    	  bvalid <= 1'b0;
    	else if(transCompleted & abtGrant[1])
    	  bvalid <= 1'b1;
    	else
    	  bvalid <= 1'b0;
    end
    //checked to here
    //ARBITER
    //nextSel0
    always_comb begin
      if(abtGrant[0])
    	  nextSel[0] = 1'b1;
    	else if(~nextSel[1])
    	  nextSel[0] = 1'b0;
    	else if(ar_fifo_valid)
    	  nextSel[0] = 1'b0;
    	else
    	  nextSel[0] = 1'b1;
    end
    //nextSel1
    always_comb begin
      if(abtGrant[1])
    	  nextSel[1] = 1'b1;
    	else if(~nextSel[0])
    	  nextSel[1] = 1'b0;
    	else if(aw_fifo_valid)
    	  nextSel[1] = 1'b0;
    	else
    	  nextSel[1] = 1'b1;
    end
    //nextGrant[1]
    always_comb begin
      if(~nextSel[0])
    	  nextGrant[1] = 1'b0;
    	else if(aw_fifo_valid)
    	  nextGrant[1] = 1'b1;
    	else
    	  nextGrant[1] = abtGrant[1];
    end
    //nextGrant[0]
    always_comb begin
      if(~nextSel[1])
    	  nextGrant[0] = 1'b0;
    	else if(ar_fifo_valid)
    	  nextGrant[0] = 1'b1;
    	else
    	  nextGrant[0] = abtGrant[0];
    end
    //abtGrant
    assign update = (abtGrant[0] & aw_fifo_valid & ~ar_fifo_valid) | transCompleted;
    always_ff @(posedge aclk, negedge arst_n) begin
      if(~arst_n)
    	  abtGrant[1:0] <= 2'b01;
    	else if(update)
      //else if(transCompleted || (abtGrant[0] == 1'b1 && aw_fifo_valid == 1'b1))
    	  abtGrant[1:0] <= nextGrant[1:0];	  
    end
    //X2P_DECODER
    //startAddr
    assign startAddr[31:0] = abtGrant[0] ? sfifoArAraddr[31:0] : sfifoAwAwaddr[31:0];
    //sel[SLAVE_NUM-1:0]
    generate
      if(SLAVE_NUM >= 1) begin
    	  assign selReg  = (startAddr[31:0] >= 32'h3000_0000)  & (startAddr[31:0] <= 32'h4000_0000);
    	  assign sel[0]  = (startAddr[31:0] >= 32'h3000_0000)  & (startAddr[31:0] <= 32'h4000_0000);
    	end
    endgenerate
    //selRes
    generate
      if(SLAVE_NUM == 1)
    	  assign selRes  = (startAddr[31:0] >= 32'h3000_0000)  & (startAddr[31:0] <= 32'h4000_0000);
    endgenerate
    //selectLen
    assign selectLen[7:0] = abtGrant[0] ?  sfifoArCtrlArlen[7:0] : sfifoAwCtrlAwlen[7:0];
    //transCompleted
    assign transCompleted = (transferCounter[7:0] == selectLen[7:0] + 1'b1) ? 1'b1 : 1'b0;
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  transferCounter[7:0] <= 8'd0;
      else begin
        casez({transCntEn, transCompleted})
    	    2'b?1:  transferCounter[7:0] <= 8'd0;
    	    2'b10:  transferCounter[7:0] <= transferCounter[7:0] + 1'b1;
    		default transferCounter[7:0] <= transferCounter[7:0];
    	  endcase
    	end	
    end
    //decError
    generate
      if(SLAVE_NUM == 1)
    	  assign decError = (startAddr[31:0] < 32'h3000_0000) | (startAddr[31:0] > 32'h4000_0000);
    endgenerate
    //pslverrX, preadyX
    assign preadyX  = |preadyOut[SLAVE_NUM-1:0] | pselRes;
    assign pslverrX = |pslverrOut[SLAVE_NUM-1:0]| pselRes;
    generate
      genvar i;
    	for (i = 0; i <= SLAVE_NUM-1; i = i + 1) begin: decPreadyAndPslverr
    	  assign preadyOut[i]  = psel[i] & pready[i];
    	  assign pslverrOut[i] = psel[i] & pslverr[i];
    	end
    endgenerate
    //prdataX
    assign prdataX = prdataOut[SLAVE_NUM-1];
    assign prdataOut[0] = psel[0] ? prdata[0] : 32'd0;
    generate
      genvar j;
    	for(j = 1; j <= SLAVE_NUM-1; j = j + 1) begin: decPrdata
    	  assign prdataOut[j] = psel[j] ? prdata[j] : prdataOut[j-1];
    	end
    endgenerate
    //transfer
    assign transEn = |sel[SLAVE_NUM-1:0] | selRes | selReg;
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  transfer <= 1'b0;
      else if(cnt_transfer[7:0] >= selectLen[7:0] + 1'b1)
    	  transfer <= 1'b0;
    	else if(transEn)
    	  transfer <= 1'b1;
    	else
    	  transfer <= 1'b0;
    end

    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  cnt_transfer[7:0] <= 8'd0;
    	else if(transCompleted)
    	  cnt_transfer[7:0] <= 8'd0;
    	//else if((currentState == IDLE && transfer == 1'b1)|(currentState == ACCESS && transfer == 1'b1))
    	else if(transfer & (currentState == ACCESS || currentState == IDLE))
    	  cnt_transfer <= cnt_transfer + 1'b1;
    end
    //nextState circuit
    always_comb begin
      case(currentState[1:0])
    	  IDLE: begin
    	    if(transfer)
    		  nextState[1:0] = SETUP;
    		else
    		  nextState[1:0] = IDLE;
    	  end
    	  SETUP: nextState[1:0] = ACCESS;
    	  ACCESS: begin
    	    if(~preadyX)
    		  nextState[1:0] = ACCESS;
    		else if(transfer)
    		  nextState[1:0] = SETUP;
    		else
    		  nextState[1:0] = IDLE;
    	  end
    	  default nextState[1:0] = IDLE;
    	endcase
    end
    //currentState
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  currentState[1:0] <= IDLE;
    	else
    	  currentState[1:0] <= nextState[1:0];
    end
    //psel
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n) begin
    	  psel[SLAVE_NUM-1:0] <= 0;
    	  
    	  pselRes <= 0;
    	end
    	else begin
    	  case(currentState[1:0])
    	    IDLE:begin
      	  psel[SLAVE_NUM-1:0] <= 0;
    		  pselRes             <= 0;
    		  
    		end
    	    SETUP:begin
        	  psel[SLAVE_NUM-1:0] <= sel[SLAVE_NUM-1:0];
    		  pselRes           <= selRes;
    		  
    		end
    	    ACCESS:begin
    		  psel[SLAVE_NUM-1:0] <= psel[SLAVE_NUM-1:0];
    		  pselRes             <= pselRes;
    		  
    		end
    	  endcase
    	end
    end
    //penable
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  penable <= 1'b0;
    	else begin
    	  case(currentState[1:0])
    	    IDLE:   penable <= 1'b0;
    		SETUP:  penable <= 1'b0;
    		ACCESS: penable <= 1'b1;
    	  endcase
    	end
    end
    //paddr
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  paddr[31:0] = 32'd0;
    	else begin
    	  case(currentState[1:0])
    	    IDLE: paddr[31:0] <= 32'd0;
    		SETUP: begin
    		  if(~fsmCal)
    		    paddr[31:0] <= startAddr[31:0];
    		  else begin
    		    case(burstMode[1:0])
    			  2'b00:  paddr[31:0] <= paddr[31:0];
    			  2'b01:  paddr[31:0] <= incrNextTransAddr[31:0];
    			  2'b10:  paddr[31:0] <= wrapNextTransAddr[31:0];
    			  default paddr[31:0] <= 32'd0;
    			endcase
    		  end
    		end
    		ACCESS: paddr[31:0] <= paddr[31:0];
    	  endcase
    	end
    end
    //fsmCal
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  fsmCal <= 1'b0;
    	else if(transCompleted)
    	  fsmCal <= 1'b0;
    	else
    	  fsmCal <= |psel[SLAVE_NUM-1:0] ;
    end
    //incrNextTransAddr
    assign incrNextTransAddr[31:0] = paddr[31:0] + 32'd4;
    //burstMode
    assign burstMode[1:0] = (abtGrant[0] == 1'b1) ? sfifoArCtrlArburst[1:0] : sfifoAwCtrlAwburst[1:0];
    //bitNum
    always_comb begin
      case(selectLen[7:0])
    	  8'd1:  bitNum[2:0] = 3'b011;
    	  8'd3:  bitNum[2:0] = 3'b100;
    	  8'd7:  bitNum[2:0] = 3'b101;
    	  8'd15: bitNum[2:0] = 3'b110;
    	  default bitNum[2:0] = 3'bx;
    	endcase
    end
    //bit3Addr, bit4Addr, bit5Addr, bit6Addr
    always_comb begin
      if(bitNum[2:0] == 3'b011)
    	  bit3Addr[2:0] = paddr[2:0] + 3'd4;
    	else
    	  bit3Addr[2:0] = 3'd0;
    end
    always_comb begin
      if(bitNum[2:0] == 3'b100)
    	  bit4Addr[3:0] = paddr[3:0] + 4'd4;
    	else
    	  bit4Addr[3:0] = 4'd0;
    end
    always_comb begin
      if(bitNum[2:0] == 3'b101)
    	  bit5Addr[4:0] = paddr[4:0] + 4'd4;
    	else
    	  bit5Addr[4:0] = 5'd0;
    end
    always_comb begin
      if(bitNum[2:0] == 3'b110)
    	  bit6Addr[5:0] = paddr[5:0] + 4'd4;
    	else
    	  bit6Addr[5:0] = 6'd0;
    end
    //wrapNextTransAddr
    always_comb begin
      case(bitNum[2:0])
    	  3'b011: wrapNextTransAddr[31:0] = {paddr[31:3], bit3Addr[2:0]};
    	  3'b100: wrapNextTransAddr[31:0] = {paddr[31:4], bit4Addr[3:0]};
    	  3'b101: wrapNextTransAddr[31:0] = {paddr[31:5], bit5Addr[4:0]};
    	  3'b110: wrapNextTransAddr[31:0] = {paddr[31:6], bit6Addr[5:0]};
    	  default wrapNextTransAddr[31:0] = 32'bx;
    	endcase
    end
    //pwrite
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  pwrite <= 1'b0;
    	else begin
    	  case(currentState[1:0])
    	    IDLE: pwrite <= 1'b0;
    		SETUP: begin
    		  if(~abtGrant[0])
    		    pwrite <= 1'b1;
    		  else
    		    pwrite <= 1'b0;
    		end
    		ACCESS: pwrite <= pwrite;
    	  endcase
    	end
    end
    //pwdata
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  pwdata[31:0]           <= 32'd0;
    	else begin
    	  case(currentState[1:0])
    	    IDLE: pwdata[31:0]   <= 32'd0;
    		SETUP: begin
    		  if(abtGrant[0])
    		    pwdata[31:0]     <= 32'd0;
    		  else
    		    pwdata[31:0]     <= sfifoWdWdata[31:0];
    		end
    		ACCESS: pwdata[31:0] <= pwdata[31:0];
    	  endcase
    	end
    end
    //pprot
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  pprot[2:0] <= 3'd0;
    	else begin
    	  case(currentState[1:0])
    	    IDLE: pprot[2:0] <= 3'd0;
    	    SETUP: begin
    		  if(abtGrant[0])
    		    pprot[2:0] <= sfifoArCtrlArprot[2:0];
    		  else
    		    pprot[2:0] <= sfifoAwCtrlAwprot[2:0];
    		end
    		ACCESS: pprot[2:0] <= pprot[2:0];
    	  endcase
    	end
    end
    //pstrb
    always_ff @(posedge pclk, negedge preset_n) begin
      if(~preset_n)
    	  pstrb[3:0] = 4'd0;
    	else begin
    	  case(currentState[1:0])
    	    IDLE: pstrb[3:0] <= 4'd0;
    		SETUP: begin
    		  if(~abtGrant[0])
    		    pstrb[3:0] <= sfifoWdWstrb[3:0];
    		  else
    		    pstrb[3:0] <= 4'd0;
    		end
    		ACCESS: pstrb[3:0] <= pstrb[3:0];
    	  endcase
    	end
    end
endmodule