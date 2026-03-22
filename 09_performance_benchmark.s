# ============================================================
# Program 9: Extended Pipeline + Cache Benchmark
# ============================================================
# What this program does:
# 1) Computes C  = A * B      (B is identity, so C should equal A)
# 2) Computes C2 = A * B2     (B2 is anti-diagonal, so each row is reversed)
# 3) Runs additional reduction passes over C and C2 to increase workload
#
# Why this is useful:
# - Generates a larger workload for pipeline and cache analysis.
# - Includes multiple nested-loop phases with dependency chains.
# - Produces heavy nested-loop activity for performance comparison.
#
# How to use in Ripes:
# - Run under different processor/cache configurations.
# - Compare cycles/CPI/IPC and cache hit-miss behavior.
# ============================================================

.data
    .align 4
        matA: .word  1,  2,  3,  4,  5,  6,  7,  8
            .word  9, 10, 11, 12, 13, 14, 15, 16
            .word 17, 18, 19, 20, 21, 22, 23, 24
            .word 25, 26, 27, 28, 29, 30, 31, 32
            .word 33, 34, 35, 36, 37, 38, 39, 40
            .word 41, 42, 43, 44, 45, 46, 47, 48
            .word 49, 50, 51, 52, 53, 54, 55, 56
            .word 57, 58, 59, 60, 61, 62, 63, 64

        matB: .word 1,0,0,0,0,0,0,0
            .word 0,1,0,0,0,0,0,0
            .word 0,0,1,0,0,0,0,0
            .word 0,0,0,1,0,0,0,0
            .word 0,0,0,0,1,0,0,0
            .word 0,0,0,0,0,1,0,0
            .word 0,0,0,0,0,0,1,0
            .word 0,0,0,0,0,0,0,1

        matC: .word 0,0,0,0,0,0,0,0
            .word 0,0,0,0,0,0,0,0
            .word 0,0,0,0,0,0,0,0
            .word 0,0,0,0,0,0,0,0
            .word 0,0,0,0,0,0,0,0
            .word 0,0,0,0,0,0,0,0
            .word 0,0,0,0,0,0,0,0
            .word 0,0,0,0,0,0,0,0

        matB2: .word 0,0,0,0,0,0,0,1
             .word 0,0,0,0,0,0,1,0
             .word 0,0,0,0,0,1,0,0
             .word 0,0,0,0,1,0,0,0
             .word 0,0,0,1,0,0,0,0
             .word 0,0,1,0,0,0,0,0
             .word 0,1,0,0,0,0,0,0
             .word 1,0,0,0,0,0,0,0

        matC2: .word 0,0,0,0,0,0,0,0
             .word 0,0,0,0,0,0,0,0
             .word 0,0,0,0,0,0,0,0
             .word 0,0,0,0,0,0,0,0
             .word 0,0,0,0,0,0,0,0
             .word 0,0,0,0,0,0,0,0
             .word 0,0,0,0,0,0,0,0
             .word 0,0,0,0,0,0,0,0

        N: .word 8

.text
.globl main

main:
    la   x5, matA
    la   x6, matB
    la   x7, matC
    li   x8, 8

    li   x9, 0

outer_i:
    li   x10, 0

outer_j:
    li   x11, 0
    li   x12, 0

inner_k:
    mul  x13, x9, x8
    add  x13, x13, x11
    slli x13, x13, 2
    add  x14, x5, x13
    lw   x15, 0(x14)

    mul  x16, x11, x8
    add  x16, x16, x10
    slli x16, x16, 2
    add  x17, x6, x16
    lw   x18, 0(x17)

    mul  x19, x15, x18
    add  x12, x12, x19

    addi x11, x11, 1
    blt  x11, x8, inner_k

    mul  x20, x9, x8
    add  x20, x20, x10
    slli x20, x20, 2
    add  x21, x7, x20
    sw   x12, 0(x21)

    addi x10, x10, 1
    blt  x10, x8, outer_j

    addi x9, x9, 1
    blt  x9, x8, outer_i

    la   x6, matB2
    la   x7, matC2
    li   x9, 0

outer_i_2:
    li   x10, 0

outer_j_2:
    li   x11, 0
    li   x12, 0

inner_k_2:
    mul  x13, x9, x8
    add  x13, x13, x11
    slli x13, x13, 2
    add  x14, x5, x13
    lw   x15, 0(x14)

    mul  x16, x11, x8
    add  x16, x16, x10
    slli x16, x16, 2
    add  x17, x6, x16
    lw   x18, 0(x17)

    mul  x19, x15, x18
    add  x12, x12, x19

    addi x11, x11, 1
    blt  x11, x8, inner_k_2

    mul  x20, x9, x8
    add  x20, x20, x10
    slli x20, x20, 2
    add  x21, x7, x20
    sw   x12, 0(x21)

    addi x10, x10, 1
    blt  x10, x8, outer_j_2

    addi x9, x9, 1
    blt  x9, x8, outer_i_2

    la   x22, matC
    la   x23, matC2
    li   x9, 0

row_loop:
    li   x10, 0
    li   x12, 0

row_inner:
    mul  x13, x9, x8
    add  x13, x13, x10
    slli x13, x13, 2

    add  x14, x22, x13
    lw   x15, 0(x14)
    add  x16, x23, x13
    lw   x17, 0(x16)

    add  x12, x12, x15
    add  x12, x12, x17

    addi x10, x10, 1
    blt  x10, x8, row_inner

    addi x9, x9, 1
    blt  x9, x8, row_loop

    li   x10, 0

col_loop:
    li   x9, 0
    li   x12, 0

col_inner:
    mul  x13, x9, x8
    add  x13, x13, x10
    slli x13, x13, 2

    add  x14, x22, x13
    lw   x15, 0(x14)
    add  x16, x23, x13
    lw   x17, 0(x16)

    add  x12, x12, x15
    add  x12, x12, x17

    addi x9, x9, 1
    blt  x9, x8, col_inner

    addi x10, x10, 1
    blt  x10, x8, col_loop

    li   x9, 0
    li   x12, 0

checksum_loop:
    slli x13, x9, 2
    mul  x18, x9, x8
    add  x18, x18, x9
    slli x18, x18, 2

    add  x14, x22, x18
    lw   x15, 0(x14)
    add  x16, x23, x18
    lw   x17, 0(x16)

    add  x12, x12, x15
    add  x12, x12, x17

    addi x9, x9, 1
    blt  x9, x8, checksum_loop

    li   x17, 10
    ecall
