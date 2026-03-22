# ============================================================
# Program 9: Combined Pipeline + Cache Performance Benchmark
# ============================================================
# A realistic matrix multiplication benchmark that stresses
# both the pipeline (data hazards) and the cache (memory access
# patterns). Used to measure overall system performance.
#
# Operation: C[i][j] = sum(A[i][k] * B[k][j]) for k=0..N-1
#
# Matrix size: 4x4 (small enough for Ripes, large enough
# to demonstrate real effects)
#
# Pipeline hazards present:
#   - Loop-carried accumulator dependency
#   - Load-use hazards on matrix element loads
#   - Address computation chains
#
# Cache effects:
#   - A is accessed row-major (sequential) -> cache-friendly
#   - B is accessed column-major (strided) -> cache-unfriendly
#   - C is written sequentially -> cache-friendly
#
# Run this benchmark with different configurations and record:
#   1. Total clock cycles
#   2. Pipeline stalls
#   3. Cache hit/miss rates
# ============================================================

.data
    .align 4
    # Matrix A (4x4) - row major
    matA: .word  1, 2, 3, 4
          .word  5, 6, 7, 8
          .word  9, 10, 11, 12
          .word  13, 14, 15, 16

    # Matrix B (4x4) - row major
    matB: .word  1, 0, 0, 1
          .word  0, 1, 0, 0
          .word  0, 0, 1, 0
          .word  1, 0, 0, 1

    # Result Matrix C (4x4) - initialized to 0
    matC: .word  0, 0, 0, 0
          .word  0, 0, 0, 0
          .word  0, 0, 0, 0
          .word  0, 0, 0, 0

    N: .word 4

.text
.globl main

main:
    la   x5, matA         # Base address of A
    la   x6, matB         # Base address of B
    la   x7, matC         # Base address of C
    li   x8, 4            # N = 4 (matrix dimension)

    li   x9, 0            # i = 0 (row index)

outer_i:
    li   x10, 0           # j = 0 (column index)

outer_j:
    li   x11, 0           # k = 0 (inner loop index)
    li   x12, 0           # accumulator = 0 (C[i][j])

inner_k:
    # ---- Compute address of A[i][k] ----
    mul  x13, x9, x8      # x13 = i * N                << RAW from outer loop
    add  x13, x13, x11   # x13 = i * N + k             << RAW: x13
    slli x13, x13, 2     # x13 = (i*N + k) * 4 bytes   << RAW: x13
    add  x14, x5, x13    # x14 = &A[i][k]              << RAW: x13
    lw   x15, 0(x14)     # x15 = A[i][k]               << LOAD-USE potential

    # ---- Compute address of B[k][j] ----
    mul  x16, x11, x8    # x16 = k * N
    add  x16, x16, x10   # x16 = k * N + j             << RAW: x16
    slli x16, x16, 2     # x16 = (k*N + j) * 4 bytes   << RAW: x16
    add  x17, x6, x16    # x17 = &B[k][j]              << RAW: x16
    lw   x18, 0(x17)     # x18 = B[k][j]               << LOAD-USE potential

    # ---- Multiply and accumulate ----
    mul  x19, x15, x18   # x19 = A[i][k] * B[k][j]    << RAW: x15, x18
    add  x12, x12, x19   # acc += product              << RAW: x19, x12

    # ---- Next k ----
    addi x11, x11, 1
    blt  x11, x8, inner_k

    # ---- Store C[i][j] ----
    mul  x20, x9, x8     # x20 = i * N
    add  x20, x20, x10   # x20 = i * N + j
    slli x20, x20, 2     # byte offset
    add  x21, x7, x20    # &C[i][j]
    sw   x12, 0(x21)     # C[i][j] = accumulated sum

    # ---- Next j ----
    addi x10, x10, 1
    blt  x10, x8, outer_j

    # ---- Next i ----
    addi x9, x9, 1
    blt  x9, x8, outer_i

    # ============================================
    # Expected Result: C = A * B
    # A * B where B is close to identity:
    #   B = [[1,0,0,1],[0,1,0,0],[0,0,1,0],[1,0,0,1]]
    #
    #   C[0] = [1*1+2*0+3*0+4*1, 1*0+2*1+3*0+4*0, 1*0+2*0+3*1+4*0, 1*1+2*0+3*0+4*1]
    #        = [5, 2, 3, 5]
    #   C[1] = [5+8, 6, 7, 5+8] = [13, 6, 7, 13]
    #   C[2] = [9+12, 10, 11, 9+12] = [21, 10, 11, 21]
    #   C[3] = [13+16, 14, 15, 13+16] = [29, 14, 15, 29]
    # ============================================

    # ---- End Program ----
    li   x17, 10
    ecall
