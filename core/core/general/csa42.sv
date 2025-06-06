module csa42
#(
    parameter CSA42_WIDTH = 16
)
(
    input   logic [CSA42_WIDTH-1:0]          i1  ,
    input   logic [CSA42_WIDTH-1:0]          i2  ,
    input   logic [CSA42_WIDTH-1:0]          i3  ,
    input   logic [CSA42_WIDTH-1:0]          i4  ,

    output  logic [CSA42_WIDTH:0]            sum ,
    output  logic [CSA42_WIDTH:0]            co    
);
    
    logic [CSA42_WIDTH-1:0]     xor12;
    logic [CSA42_WIDTH-1:0]     xor1234;
    logic [CSA42_WIDTH-1:0]     cin_t;
    logic [CSA42_WIDTH-1:0]     sum_t;
    logic [CSA42_WIDTH-1:0]     co_t;
    logic [CSA42_WIDTH:0]       cin;

    assign xor12   = i1 ^ i2;
    assign xor1234 = i1 ^ i2 ^ i3 ^ i4;

    assign cin_t   = (xor12 & i3) | (~xor12 & i1);                               //Cout
    assign sum_t   = xor1234 ^ cin[CSA42_WIDTH-1:0];                            //sum
    assign co_t    = (xor1234 & cin[CSA42_WIDTH-1:0]) | (~xor1234 & i4);       //carry

    assign cin     = {cin_t,1'b0};                                              //Cin=2Cout 即Cout左移一位
    assign sum     = {cin[CSA42_WIDTH],sum_t};                                  //进位+求和结果
    assign co      = {co_t,1'b0};

endmodule