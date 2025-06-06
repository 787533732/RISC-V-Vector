#include <string.h>
#include "util.h"

//--------------------------------------------------------------------------
// Input/Reference Data
#include "dataset7.h"
#include <stdint.h>
#include <riscv_vector.h>

// 显式声明向量类型（某些工具链需要）
typedef vint8m1_t vint8m1_t;

void gemm32x32(int N, int K,  const int8_t* A, const int8_t* B, int8_t* C) {
    
    size_t vl = __riscv_vsetvlmax_e8m1();// 设置向量长度（LMUL=1）
    
    for (int n = 0; n < N; n += vl) {
        // 动态调整处理长度
        vl = __riscv_vsetvl_e8m1(N - n);
        
        // 初始化累加器（使用正确的向量指令）
        vint8m1_t c0 ;
        vint8m1_t c1 ;
        vint8m1_t c2 ;
        vint8m1_t c3 ;
        vint8m1_t c4 ;
        vint8m1_t c5 ;
        vint8m1_t c6 ;
        vint8m1_t c7 ;
        vint8m1_t c8 ;
        vint8m1_t c9 ;
        vint8m1_t c10;
        vint8m1_t c11;
        vint8m1_t c12;
        vint8m1_t c13;
        vint8m1_t c14;
        vint8m1_t c15;
        vint8m1_t c16;
        vint8m1_t c17;
        vint8m1_t c18;
        vint8m1_t c19;
        vint8m1_t c20;
        vint8m1_t c21;
        vint8m1_t c22;
        vint8m1_t c23;
        vint8m1_t c24;
        vint8m1_t c25;
        vint8m1_t c26;
        vint8m1_t c27;
        vint8m1_t c28;
        vint8m1_t c29;
        vint8m1_t c30;
        vint8m1_t c31;

        for (int k = 0; k < K; ++k) {
            // 加载A的标量元素
            int8_t a0  = A[(0)*K + k];
            int8_t a1  = A[(1)*K + k];
            int8_t a2  = A[(2)*K + k];
            int8_t a3  = A[(3)*K + k];
            int8_t a4  = A[(4)*K + k];
            int8_t a5  = A[(5)*K + k];
            int8_t a6  = A[(6)*K + k];
            int8_t a7  = A[(7)*K + k];
            int8_t a8  = A[(8)*K + k];
            int8_t a9  = A[(9)*K + k];
            int8_t a10 = A[(10)*K + k];
            int8_t a11 = A[(11)*K + k];
            int8_t a12 = A[(12)*K + k];
            int8_t a13 = A[(13)*K + k];
            int8_t a14 = A[(14)*K + k];
            int8_t a15 = A[(15)*K + k];
            int8_t a16 = A[(16)*K + k];
            int8_t a17 = A[(17)*K + k];
            int8_t a18 = A[(18)*K + k];
            int8_t a19 = A[(19)*K + k];
            int8_t a20 = A[(20)*K + k];
            int8_t a21 = A[(21)*K + k];
            int8_t a22 = A[(22)*K + k];
            int8_t a23 = A[(23)*K + k];
            int8_t a24 = A[(24)*K + k];
            int8_t a25 = A[(25)*K + k];
            int8_t a26 = A[(26)*K + k];
            int8_t a27 = A[(27)*K + k];
            int8_t a28 = A[(28)*K + k];
            int8_t a29 = A[(29)*K + k];
            int8_t a30 = A[(30)*K + k];
            int8_t a31 = A[(31)*K + k];
            // 加载B的向量元素
            const int8_t* B_ptr = &B[k*N + n];
            vint8m1_t b = __riscv_vle8_v_i8m1(B_ptr, vl);
            
            // 乘积累加
            c0  = __riscv_vmacc_vx_i8m1(c0,  a0, b, vl);
            c1  = __riscv_vmacc_vx_i8m1(c1,  a1, b, vl);
            c2  = __riscv_vmacc_vx_i8m1(c2,  a2, b, vl);
            c3  = __riscv_vmacc_vx_i8m1(c3,  a3, b, vl);
            c4  = __riscv_vmacc_vx_i8m1(c4,  a4, b, vl);
            c5  = __riscv_vmacc_vx_i8m1(c5,  a5, b, vl);
            c6  = __riscv_vmacc_vx_i8m1(c6,  a6, b, vl);
            c7  = __riscv_vmacc_vx_i8m1(c7,  a7, b, vl);
            c8  = __riscv_vmacc_vx_i8m1(c8,  a8, b, vl);
            c9  = __riscv_vmacc_vx_i8m1(c9,  a9, b, vl);
            c10 = __riscv_vmacc_vx_i8m1(c10, a10, b, vl);
            c11 = __riscv_vmacc_vx_i8m1(c11, a11, b, vl);
            c12 = __riscv_vmacc_vx_i8m1(c12, a12, b, vl);
            c13 = __riscv_vmacc_vx_i8m1(c13, a13, b, vl);
            c14 = __riscv_vmacc_vx_i8m1(c14, a14, b, vl);
            c15 = __riscv_vmacc_vx_i8m1(c15, a15, b, vl);
            c16 = __riscv_vmacc_vx_i8m1(c16, a16, b, vl);
            c17 = __riscv_vmacc_vx_i8m1(c17, a17, b, vl);
            c18 = __riscv_vmacc_vx_i8m1(c18, a18, b, vl);
            c19 = __riscv_vmacc_vx_i8m1(c19, a19, b, vl);
            c20 = __riscv_vmacc_vx_i8m1(c20, a20, b, vl);
            c21 = __riscv_vmacc_vx_i8m1(c21, a21, b, vl);
            c22 = __riscv_vmacc_vx_i8m1(c22, a22, b, vl);
            c23 = __riscv_vmacc_vx_i8m1(c23, a23, b, vl);
            c24 = __riscv_vmacc_vx_i8m1(c24, a24, b, vl);
            c25 = __riscv_vmacc_vx_i8m1(c25, a25, b, vl);
            c26 = __riscv_vmacc_vx_i8m1(c26, a26, b, vl);
            c27 = __riscv_vmacc_vx_i8m1(c27, a27, b, vl);
            c28 = __riscv_vmacc_vx_i8m1(c28, a28, b, vl);
            c29 = __riscv_vmacc_vx_i8m1(c29, a29, b, vl);
            c30 = __riscv_vmacc_vx_i8m1(c30, a30, b, vl);
            c31 = __riscv_vmacc_vx_i8m1(c31, a31, b, vl);

        }
        // 存储结果
        __riscv_vse8_v_i8m1(&C[(0)*N + n],  c0,  vl);
        __riscv_vse8_v_i8m1(&C[(1)*N + n],  c1,  vl);
        __riscv_vse8_v_i8m1(&C[(2)*N + n],  c2,  vl);
        __riscv_vse8_v_i8m1(&C[(3)*N + n],  c3,  vl);
        __riscv_vse8_v_i8m1(&C[(4)*N + n],  c4,  vl);
        __riscv_vse8_v_i8m1(&C[(5)*N + n],  c5,  vl);
        __riscv_vse8_v_i8m1(&C[(6)*N + n],  c6,  vl);
        __riscv_vse8_v_i8m1(&C[(7)*N + n],  c7,  vl);
        __riscv_vse8_v_i8m1(&C[(8)*N + n],  c8,  vl);
        __riscv_vse8_v_i8m1(&C[(9)*N + n],  c9,  vl);
        __riscv_vse8_v_i8m1(&C[(10)*N + n], c10, vl);
        __riscv_vse8_v_i8m1(&C[(11)*N + n], c11, vl);
        __riscv_vse8_v_i8m1(&C[(12)*N + n], c12, vl);
        __riscv_vse8_v_i8m1(&C[(13)*N + n], c13, vl);
        __riscv_vse8_v_i8m1(&C[(14)*N + n], c14, vl);
        __riscv_vse8_v_i8m1(&C[(15)*N + n], c15, vl);
        __riscv_vse8_v_i8m1(&C[(16)*N + n], c16, vl);
        __riscv_vse8_v_i8m1(&C[(17)*N + n], c17, vl);
        __riscv_vse8_v_i8m1(&C[(18)*N + n], c18, vl);
        __riscv_vse8_v_i8m1(&C[(19)*N + n], c19, vl);
        __riscv_vse8_v_i8m1(&C[(20)*N + n], c20, vl);
        __riscv_vse8_v_i8m1(&C[(21)*N + n], c21, vl);
        __riscv_vse8_v_i8m1(&C[(22)*N + n], c22, vl);
        __riscv_vse8_v_i8m1(&C[(23)*N + n], c23, vl);
        __riscv_vse8_v_i8m1(&C[(24)*N + n], c24, vl);
        __riscv_vse8_v_i8m1(&C[(25)*N + n], c25, vl);
        __riscv_vse8_v_i8m1(&C[(26)*N + n], c26, vl);
        __riscv_vse8_v_i8m1(&C[(27)*N + n], c27, vl);
        __riscv_vse8_v_i8m1(&C[(28)*N + n], c28, vl);
        __riscv_vse8_v_i8m1(&C[(29)*N + n], c29, vl);
        __riscv_vse8_v_i8m1(&C[(30)*N + n], c30, vl);
        __riscv_vse8_v_i8m1(&C[(31)*N + n], c31, vl);
    }
}


int main(int argc, char* argv[]) {
    int8_t results_data[ARRAY_SIZE];
    
    // 执行整数矩阵乘法（LMUL=1版本）
    gemm32x32(DIM_SIZE, DIM_SIZE, input1_data, input2_data, results_data);
    
    // 验证结果
    return verify_int8_t(ARRAY_SIZE, results_data, verify_data);
}


