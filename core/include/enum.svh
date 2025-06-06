typedef enum logic [7:0] {
LB,
LH,
LW,
LBU,
LHU,
FLW,
FLD,
FENCE,
FENCEI,
ADDI,
SLLI,
SLTI,
SLTIU,
XORI,
SRLI,
SRAI,
ORI,
ANDI,
AUIPC,
SB,
SH,
SW,
FSW,
FSD,
ADD,
SUB,
MUL,
SLL,
MULH,
SLT,
MULHSU,
SLTU,
MULHU,
XOR,
DIV,
SRL,
DIVU,
SRA,
OR,
REM,
REMU,
AND,
LUI,
BEQ,
BNE,
BLT,
BGE,
BLTU,
BGEU,
JALR,
JAL,
ECALL,
EBREAK,
MRET,
CSRRW,
CSRRS,
CSRRC,
CSRRWI,
CSRRSI,
CSRRCI,
//Vector
IVVADD,
IVVSUB,
IVVAND,
IVVOR, 
IVVXOR,
IVVADC,
IVVSLL,
IVVSRL,
IVVSRA,
IVVSLT,
IVVSLTU,

IVIADD,
IVIAND,
IVIOR, 
IVIXOR,
IVISLIDEDOWN,
IVIADC,
IVISLL,
IVISRL,
IVISRA,

IVXADD,
IVXSUB,
IVXAND,
IVXOR, 
IVXXOR,
IVXADC,
IVXSLL,
IVXSRL,
IVXSRA,
IVXVMV,

MVVVMV_X_S,
MVVVCPOP,
MVVMACC,
MVXMACC,
VSETVLI,
VSETVL,
VSETIVLI,

V_LOAD_UNIT_STRIDE,
V_LOAD_STRIDE,
V_LOAD_INDEX,
V_LOAD_INDEX_ORDER,
V_STORE_UNIT_STRIDE,
V_STORE_STRIDE,
V_STORE_INDEX,
V_STORE_INDEX_ORDER,

IDLE
} detected_instr;