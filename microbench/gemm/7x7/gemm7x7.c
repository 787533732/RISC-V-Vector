#include <string.h>
#include "util.h"

#include "dataset7.h"

void gemm(int M, int N, int K, 
          const unsigned char* A,
          const unsigned char* B,
          unsigned char* C) {
    // 清零输出矩阵
    //memset(C, 0, M * N * sizeof(unsigned char));
    
    for (int m = 0; m < M; m++) {
        for (int n = 0; n < N; n++) {
            for (int k = 0; k < K; k++) {
                C[m * N + n] += A[m * K + k] * B[k * N + n];
            }
        }
    }
}



int main(int argc, char* argv[]) {
    unsigned char results_data[ARRAY_SIZE];
    
    // 执行整数矩阵乘法（LMUL=1版本）
    gemm(DIM_SIZE, DIM_SIZE, DIM_SIZE, input1_data, input2_data, results_data);
    
    // 验证结果
    return verify_int8(ARRAY_SIZE, results_data, verify_data);
}


