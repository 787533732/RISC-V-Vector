module mult_bth
#(
    parameter MUL_WIDTH = 8
)
(
    input   logic [MUL_WIDTH-1:0]        a_dat   ,
    input   logic [2:0]                  b_bits  ,

    output  logic [MUL_WIDTH:0]          pp      ,
    output  logic                        e       
);

    logic ee;
    logic e_reg;
    logic [MUL_WIDTH:0] a_dat_p1;
    logic [MUL_WIDTH:0] a_dat_n1;
    logic [MUL_WIDTH:0] pp_reg;

    assign pp = pp_reg;
    assign e  = e_reg;
    assign a_dat_p1 =  {a_dat[MUL_WIDTH-1],a_dat};  //加符号位表示X
    assign a_dat_n1 = ~{a_dat[MUL_WIDTH-1],a_dat} + 1'b1;  //所有位数取反加1表示-X
    assign ee       = ~(a_dat[MUL_WIDTH-1] ^ b_bits[2]);

    always_comb begin
        case(b_bits) 
            3'b000, 3'b111 :
            begin
                pp_reg = 0;                                     //不操作
                e_reg  = 1'b1;
            end
            3'b001, 3'b010 :
            begin
                pp_reg = a_dat_p1;                              //+X
                e_reg  = ee;
            end
            3'b011 :
            begin
                pp_reg = {a_dat_p1[MUL_WIDTH-1:0], 1'b0};       //+2X
                e_reg  = ee;
            end
            3'b100 :
            begin
                pp_reg = {a_dat_n1[MUL_WIDTH-1:0], 1'b0};       //-2X
                e_reg  = ee;
            end
            3'b101, 3'b110 :
            begin
                pp_reg = a_dat_n1;                              //-X
                e_reg  = ee;
            end
        endcase
    end

endmodule