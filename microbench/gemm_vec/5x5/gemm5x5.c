#include <string.h>
#include "util.h"

//--------------------------------------------------------------------------
// Input/Reference Data
#include "dataset5.h"
#include <stdint.h>
#include <riscv_vector.h>

// 显式声明向量类型（某些工具链需要）
typedef vint8m1_t vint8m1_t;

void gemm5x5(int N, int K,  const int8_t* A, const int8_t* B, int8_t* C) {
    
    size_t vl = __riscv_vsetvlmax_e8m1();// 设置向量长度（LMUL=1）
    
    for (int n = 0; n < N; n += vl) {
        // 动态调整处理长度
        vl = __riscv_vsetvl_e8m1(N - n);
        
        // 初始化累加器（使用正确的向量指令）
        vint8m1_t c0;
        vint8m1_t c1;
        vint8m1_t c2;
        vint8m1_t c3;
        vint8m1_t c4;
        for (int k = 0; k < K; ++k) {
            // 加载A的标量元素
            int8_t a0 = A[(0)*K + k];
            int8_t a1 = A[(1)*K + k];
            int8_t a2 = A[(2)*K + k];
            int8_t a3 = A[(3)*K + k];
            int8_t a4 = A[(4)*K + k];
            // 加载B的向量元素
            const int8_t* B_ptr = &B[k*N + n];
            vint8m1_t b = __riscv_vle8_v_i8m1(B_ptr, vl);
            
            // 乘积累加
            c0 = __riscv_vmacc_vx_i8m1(c0, a0, b, vl);
            c1 = __riscv_vmacc_vx_i8m1(c1, a1, b, vl);
            c2 = __riscv_vmacc_vx_i8m1(c2, a2, b, vl);
            c3 = __riscv_vmacc_vx_i8m1(c3, a3, b, vl);
            c4 = __riscv_vmacc_vx_i8m1(c4, a4, b, vl);
        }
        // 存储结果
        __riscv_vse8_v_i8m1(&C[(0)*N + n], c0, vl);
        __riscv_vse8_v_i8m1(&C[(1)*N + n], c1, vl);
        __riscv_vse8_v_i8m1(&C[(2)*N + n], c2, vl);
        __riscv_vse8_v_i8m1(&C[(3)*N + n], c3, vl);
        __riscv_vse8_v_i8m1(&C[(4)*N + n], c4, vl);
    }
}


int main(int argc, char* argv[]) {
    int8_t results_data[ARRAY_SIZE];
    
    // 执行整数矩阵乘法（LMUL=1版本）
    gemm5x5(DIM_SIZE, DIM_SIZE, input1_data, input2_data, results_data);
    
    // 验证结果
    return verify_int8_t(ARRAY_SIZE, results_data, verify_data);
}


