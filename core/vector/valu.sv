`include "../../core/include/defines.svh"
module valu 
#(
    parameter MICROOP_WIDTH = 5 ,
    parameter VECTOR_LANES  = 8 
)
(
    input   logic                                           clk             ,
    input   logic                                           rst_n           , 

    input   logic                                           valid_i         ,
    input   logic [31:0]                                    data_a_ex1_i    ,
    input   logic [31:0]                                    data_b_ex1_i    ,
    input   logic [31:0]                                    imm_ex1_i       ,
    input   logic [MICROOP_WIDTH-1:0]                       microop_i       ,
    input   logic [1:0]                                     vsew_i          ,
    input   logic                                           mask_i          ,         

    //output  logic                                           ready_res_ex1_o ,
    output  logic [32-1:0]                                  result_ex1_o    ,
    output  logic                                           wren_scalar_reg             
);

    logic                       valid_int_ex1;
    logic [31:0]                data_a_u_ex1 ;
    logic [31:0]                data_b_u_ex1 ;
    logic [31:0]                imm_u_ex1    ;
    logic [31:0]                data_a_s_ex1 ;
    logic [31:0]                data_b_s_ex1 ;
    logic [31:0]                imm_s_ex1    ;
    logic [31:0]                result_int;

    assign data_a_u_ex1 = $unsigned(data_a_ex1_i);
    assign data_b_u_ex1 = $unsigned(data_b_ex1_i);
    assign imm_u_ex1    = $unsigned(imm_ex1_i);

    assign data_a_s_ex1 = $signed(data_a_ex1_i);
    assign data_b_s_ex1 = $signed(data_b_ex1_i);
    assign imm_s_ex1    = $signed(imm_ex1_i);

    always_comb begin
        if(valid_i) begin
            case(microop_i)
                5'b00001 : begin//VADD
                    valid_int_ex1 = 1'b1;
                    case (vsew_i)
                        `SZ_8  : for(int a = 0; a < 4; a++) begin
                            result_int[a*8+:8]   = data_a_ex1_i[a*8+:8] + data_b_ex1_i[a*8+:8];
                        end
                        `SZ_16 : for(int a = 0; a < 2; a++) begin
                            result_int[a*16+:16] = data_a_ex1_i[a*16+:16] + data_b_ex1_i[a*16+:16];
                        end
                        `SZ_32 : begin
                            result_int = data_a_ex1_i + data_b_ex1_i; 
                        end
                        default: begin
                            result_int = 32'd0; 
                        end 
                    endcase
                
                end
                5'b00010 : begin//VSUB
                    valid_int_ex1 = 1'b1;
                    case (vsew_i)
                        `SZ_8  : for(int a = 0; a < 4; a++) begin
                            result_int[a*8+:8]   = data_b_ex1_i[a*8+:8] - data_a_ex1_i[a*8+:8];
                        end
                        `SZ_16 : for(int a = 0; a < 2; a++) begin
                            result_int[a*16+:16] = data_b_ex1_i[a*16+:16] - data_a_ex1_i[a*16+:16];
                        end
                        `SZ_32 : begin
                            result_int = data_b_ex1_i - data_a_ex1_i; 
                        end
                        default: begin
                            result_int = 32'd0; 
                        end 
                    endcase
                end
                5'b00011 : begin//VAND
                    result_int    = data_a_u_ex1 & data_b_u_ex1; 
                    valid_int_ex1 = 1'b1;
                end
                5'b00100 : begin//VOR
                    result_int    = data_a_u_ex1 | data_b_u_ex1; 
                    valid_int_ex1 = 1'b1;
                end
                5'b00101 : begin//VXOR
                    result_int    = data_a_u_ex1 ^ data_b_u_ex1; 
                    valid_int_ex1 = 1'b1;
                end
                5'b00110 : begin//VSLL
                    result_int    = data_a_u_ex1 << data_b_u_ex1[4:0]; 
                    valid_int_ex1 = 1'b1;
                end
                5'b00111 : begin//VSRL
                    result_int    = data_a_u_ex1 >> data_b_u_ex1[4:0]; 
                    valid_int_ex1 = 1'b1;
                end
                5'b01000 : begin//VSRA
                    result_int    = data_a_s_ex1 >>> data_b_u_ex1[4:0]; 
                    valid_int_ex1 = 1'b1;
                end
                5'b01001 : begin//VSLT
                    result_int    = (data_a_ex1_i < data_b_ex1_i); 
                    valid_int_ex1 = 1'b1;
                end
                5'b01010 : begin//VSLTU
                    result_int    = (data_a_u_ex1 < data_b_u_ex1); 
                    valid_int_ex1 = 1'b1;
                end
                5'b01011 : begin//vmv.x.s
                    result_int    = data_a_u_ex1 + data_b_u_ex1; 
                    valid_int_ex1 = 1'b1;
                    wren_scalar_reg = 1'b1;
                end
                5'b10001 : begin//VADDI
                    result_int    = data_a_u_ex1 + imm_u_ex1;
                    valid_int_ex1 = 1'b1;
                end
                5'b10011 : begin//VANDI
                    result_int    = data_a_u_ex1 & imm_u_ex1;
                    valid_int_ex1 = 1'b1;
                end
                5'b10100 : begin//VORI
                    result_int    = data_a_u_ex1 | imm_u_ex1;
                    valid_int_ex1 = 1'b1;
                end
                5'b10101 : begin//VXORI
                    result_int    = data_a_u_ex1 ^ imm_u_ex1; 
                    valid_int_ex1 = 1'b1;
                end
                5'b10110 : begin//VSLLI
                    result_int    = data_a_u_ex1 << imm_u_ex1[4:0]; 
                    valid_int_ex1 = 1'b1;
                end
                5'b10111 : begin//VSRLI
                    result_int    = data_a_u_ex1 >> imm_u_ex1[4:0]; 
                    valid_int_ex1 = 1'b1;
                end
                5'b11000 : begin//VSRAI
                    result_int    = data_a_s_ex1 >>> imm_u_ex1[4:0]; 
                    valid_int_ex1 = 1'b1;
                end
                5'b11001 : begin//vmv.v.x
                    result_int    = data_a_s_ex1; 
                    valid_int_ex1 = 1'b1;
                end
                5'b11010 : begin//vmacc.vv
                    valid_int_ex1 = 1'b1;
                    case (vsew_i)
                        `SZ_8  : for(int a = 0; a < 4; a++) begin
                            result_int[a*8+:8]   = data_b_ex1_i[a*8+:8] * imm_u_ex1 + data_a_ex1_i[a*8+:8];
                        end
                        `SZ_16 : for(int a = 0; a < 2; a++) begin
                            result_int[a*16+:16] = data_b_ex1_i[a*16+:16] * imm_u_ex1 + data_a_ex1_i[a*16+:16];
                        end
                        `SZ_32 : begin
                            result_int = data_b_ex1_i * imm_u_ex1 + data_a_ex1_i; 
                        end
                        default: begin
                            result_int = 32'd0; 
                        end 
                    endcase
                end
                5'b11010 : begin//vmacc.vx
                    valid_int_ex1 = 1'b1;
                    case (vsew_i)
                        `SZ_8  : for(int a = 0; a < 4; a++) begin
                            result_int[a*8+:8]   = data_b_ex1_i[a*8+:8] * imm_u_ex1 + data_a_ex1_i[a*8+:8];
                        end
                        `SZ_16 : for(int a = 0; a < 2; a++) begin
                            result_int[a*16+:16] = data_b_ex1_i[a*16+:16] * imm_u_ex1 + data_a_ex1_i[a*16+:16];
                        end
                        `SZ_32 : begin
                            result_int = data_b_ex1_i * imm_u_ex1 + data_a_ex1_i; 
                        end
                        default: begin
                            result_int = 32'd0; 
                        end 
                    endcase
                end
                default  : begin
                    result_int    = 32'b0;
                    valid_int_ex1 = 1'b0;
                end
            endcase
        end
        else begin
            result_int    = 32'b0;
            valid_int_ex1 = 1'b0;
            wren_scalar_reg = 1'b0;
        end
    end

    //assign ready_res_ex1_o = valid_int_ex1;
    assign result_ex1_o    = valid_int_ex1 ? result_int : 32'b0;
endmodule