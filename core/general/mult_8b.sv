module mult_8b
#(
    parameter DATA_WTH = 8,
    parameter RES_WTH = 16 
) 
(
    input   logic                    clk         ,
    input   logic                    rst_n       ,
    input   logic                    msg_in_vld  ,

    input   logic [DATA_WTH-1:0]     a_dat0      ,
    input   logic [DATA_WTH-1:0]     b_dat0      ,

    output  logic [RES_WTH-1:0]      d_dat           
);
    logic [DATA_WTH-1:0]    a;
    logic [DATA_WTH-1:0]    b;       
    logic [DATA_WTH:0]      pp0_t;
    logic [DATA_WTH:0]      pp1_t;
    logic [DATA_WTH:0]      pp2_t;
    logic [DATA_WTH:0]      pp3_t;
    logic [RES_WTH-1:0]       pp0;
    logic [RES_WTH-1:0]       pp1;
    logic [RES_WTH-1:0]       pp2;
    logic [RES_WTH-1:0]       pp3;
    logic [11:0]            pp0_o;
    logic [10:0]            pp1_o;
    logic [10:0]            pp2_o;
    logic [10:0]            pp3_o;
    logic                   e0;    
    logic                   e1;
    logic                   e2;
    logic                   e3;
    logic [RES_WTH:0]       sum0;
    logic [RES_WTH:0]       co0;

    always_comb begin
        if(msg_in_vld) begin
            a = a_dat0;
            b = b_dat0;
        end 
        else begin
            a = 8'h00;
            b = 8'h00;
        end
    end

    mult_bth#(.MUL_WIDTH(8))bth0(.a_dat(a),.b_bits({b[1:0],1'b0}),.pp(pp0_t),.e(e0));
    mult_bth#(.MUL_WIDTH(8))bth1(.a_dat(a),.b_bits( b[3:1]      ),.pp(pp1_t),.e(e1));
    mult_bth#(.MUL_WIDTH(8))bth2(.a_dat(a),.b_bits( b[5:3]      ),.pp(pp2_t),.e(e2));
    mult_bth#(.MUL_WIDTH(8))bth3(.a_dat(a),.b_bits( b[7:5]      ),.pp(pp3_t),.e(e3));

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pp0_o <= 11'h00;
            pp1_o <= 10'h00;
            pp2_o <= 10'h00;
            pp3_o <= 10'h00;
        end 
        else begin
                pp0_o <= {e0,~e0,~e0,pp0_t};
                pp1_o <= {1'b1,e1,pp1_t};
                pp2_o <= {1'b1,e2,pp2_t};
                pp3_o <= {1'b1,e3,pp3_t}; 
        end
    end
    
    assign pp0 = pp0_o;
    assign pp1 = {pp1_o, 2'b0};
    assign pp2 = {pp2_o, 4'b0};
    assign pp3 = {pp3_o, 6'b0};
    
    csa42#(.CSA42_WIDTH(16))csa42_0(.i1(pp0), .i2(pp1), .i3(pp2), .i4(pp3), .sum(sum0), .co(co0));
    assign d_dat = sum0 + co0;

endmodule