# ============================================================
# Program 11: 2-Way Replacement Policy Demo (Single Program)
# ============================================================
# Purpose:
# Compare replacement policy behavior in a 2-way set-associative cache:
# - 2-way LRU
# - 2-way Random
#
# Run this SAME file twice in Ripes:
# Run A: 256B cache, 16B line, 2-way, LRU
# Run B: 256B cache, 16B line, 2-way, Random
#
# What to observe in Cache tab:
# - Total Hits, Misses, Hit Rate
# - Compare Run A vs Run B directly (replacement policy effect)
#
# Notes:
# - A/B/C/D blocks are spaced 128 bytes apart so they map to the same set
#   for 256B, 16B line, 2-way cache (8 sets -> stride = 8*16 = 128).
# ============================================================

.data
    # Block A (16 bytes data + 112 bytes padding)
    .align 4
block_A:
    .word 0xAAAA0001, 0xAAAA0002, 0xAAAA0003, 0xAAAA0004
    .word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    # Block B (same-set target)
block_B:
    .word 0xBBBB0001, 0xBBBB0002, 0xBBBB0003, 0xBBBB0004
    .word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    # Block C (same-set target)
block_C:
    .word 0xCCCC0001, 0xCCCC0002, 0xCCCC0003, 0xCCCC0004
    .word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    # Block D (same-set target, optional stress)
block_D:
    .word 0xDDDD0001, 0xDDDD0002, 0xDDDD0003, 0xDDDD0004

.text
.globl main

main:
    la   x10, block_A
    la   x11, block_B
    la   x12, block_C
    la   x13, block_D

    # Warm-up in same set
    lw   x20, 0(x10)
    lw   x21, 0(x11)
    lw   x20, 0(x10)

    # Policy-sensitive pattern:
    # A, B, A, C, A repeated.
    # In LRU, A is likely kept due to recent reuse.
    # In Random, A may be evicted unpredictably.
    li   x5, 20
repl_loop:
    lw   x20, 0(x10)
    lw   x21, 0(x11)
    lw   x20, 0(x10)
    lw   x22, 0(x12)
    lw   x20, 0(x10)
    addi x5, x5, -1
    bnez x5, repl_loop

    # Optional extra pressure with D, keeps all accesses in same set.
    li   x5, 8
stress_loop:
    lw   x20, 0(x10)
    lw   x21, 0(x11)
    lw   x22, 0(x12)
    lw   x23, 0(x13)
    addi x5, x5, -1
    bnez x5, stress_loop

    add  x6, x20, x21
    add  x6, x6, x22
    add  x6, x6, x23

    li   x17, 10
    ecall
