# ============================================================
# Program 11: Combined Cache Comparison (Single Program)
# ============================================================
# Purpose:
# 1) Compare set-associative behavior (2-way vs 4-way)
# 2) Compare replacement policy behavior (LRU vs Random)
#
# Recommended manual runs in Ripes (same file each time):
# Run A: 256B cache, 16B line, 2-way, LRU
# Run B: 256B cache, 16B line, 4-way, LRU
# Run C: 256B cache, 16B line, 2-way, Random
# Run D: 256B cache, 16B line, 4-way, Random
#
# What to observe in Cache tab:
# - Total Hits, Misses, Hit Rate
# - Differences between Run A vs Run B (associativity effect, LRU)
# - Differences between Run C vs Run D (associativity effect, Random)
# - Differences between Run A vs Run C (replacement effect at 2-way)
# - Differences between Run B vs Run D (replacement effect at 4-way)
#
# If your Ripes version does NOT show "Random" in replacement policy:
# - Random is not supported in that build's cache UI.
# - Use FIFO as replacement-policy alternative (Run C/D become FIFO).
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

    # Block D (same-set target)
block_D:
    .word 0xDDDD0001, 0xDDDD0002, 0xDDDD0003, 0xDDDD0004

    # Result markers for quick correctness sanity
result_assoc: .word 0
result_repl:  .word 0

.text
.globl main

main:
    la   x10, block_A
    la   x11, block_B
    la   x12, block_C
    la   x13, block_D

    # ========================================================
    # Part 1: Set-Associative Comparison (A/B/C/D thrashing)
    # ========================================================
    # Warm-up: A, B, A, B
    lw   x20, 0(x10)
    lw   x21, 0(x11)
    lw   x22, 0(x10)
    lw   x23, 0(x11)

    # Bring C (conflict in 2-way set)
    lw   x24, 0(x12)

    # Thrashing sequence: A, B, C, D repeated
    # In 2-way: mostly misses. In 4-way: many hits after fill.
    li   x5, 8
assoc_loop:
    lw   x20, 0(x10)
    lw   x21, 0(x11)
    lw   x22, 0(x12)
    lw   x23, 0(x13)
    addi x5, x5, -1
    bnez x5, assoc_loop

    # Small marker computation
    add  x6, x20, x21
    add  x6, x6, x22
    add  x6, x6, x23
    la   x7, result_assoc
    sw   x6, 0(x7)

    # ========================================================
    # Part 2: Replacement Policy Comparison (LRU vs Random)
    # ========================================================
    # Core reuse pattern: A, B, A, C, A
    # LRU tends to keep recently-used A; Random may evict A.
    li   x5, 12
repl_loop:
    lw   x20, 0(x10)   # A
    lw   x21, 0(x11)   # B
    lw   x20, 0(x10)   # A (reuse)
    lw   x22, 0(x12)   # C (conflict)
    lw   x20, 0(x10)   # A again (policy-sensitive)
    addi x5, x5, -1
    bnez x5, repl_loop

    # Marker for end-of-run
    add  x6, x20, x21
    add  x6, x6, x22
    la   x7, result_repl
    sw   x6, 0(x7)

    li   x17, 10
    ecall
