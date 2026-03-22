# ============================================================
# Program 5: Sequential Array Access (Cache-Friendly)
# ============================================================
# This program traverses a large array sequentially (stride-1).
# Sequential access exploits SPATIAL LOCALITY — when one word
# is loaded, the entire cache line is fetched, and subsequent
# accesses hit within that same line.
#
# Expected behavior in Ripes cache simulator:
#   - First access to each cache line = COMPULSORY MISS
#   - Remaining accesses within the line = HITS
#   - With 16-byte lines (4 words), expect ~25% miss rate
#   - With 32-byte lines (8 words), expect ~12.5% miss rate
#
# Ripes Cache Config for testing:
#   Cache size: 256 bytes
#   Line size:  16 bytes (4 words) or 32 bytes (8 words)
#   Associativity: 2-way set associative
#   Replacement: LRU
# ============================================================

.data
    # 64-element array = 256 bytes (fits various cache configs)
    .align 4
    array: .word  1,  2,  3,  4,  5,  6,  7,  8
           .word  9, 10, 11, 12, 13, 14, 15, 16
           .word 17, 18, 19, 20, 21, 22, 23, 24
           .word 25, 26, 27, 28, 29, 30, 31, 32
           .word 33, 34, 35, 36, 37, 38, 39, 40
           .word 41, 42, 43, 44, 45, 46, 47, 48
           .word 49, 50, 51, 52, 53, 54, 55, 56
           .word 57, 58, 59, 60, 61, 62, 63, 64

    total: .word 0

.text
.globl main

main:
    # ---- Sequential Traversal (Stride = 1 word = 4 bytes) ----
    la   x10, array       # x10 = base address
    li   x11, 64          # x11 = number of elements
    li   x12, 0           # x12 = loop counter (i)
    li   x13, 0           # x13 = running sum

seq_loop:
    slli x14, x12, 2     # x14 = i * 4 (byte offset)
    add  x15, x10, x14   # x15 = &array[i]
    lw   x16, 0(x15)     # x16 = array[i]  << CACHE ACCESS
    add  x13, x13, x16   # sum += array[i]
    addi x12, x12, 1     # i++
    blt  x12, x11, seq_loop

    # Store result
    la   x17, total
    sw   x13, 0(x17)     # total = sum of 1..64 = 2080

    # ---- PASS 2: Re-traverse (tests TEMPORAL LOCALITY) ----
    # Second pass over the same data. If cache is large enough,
    # all data is still cached — expect 100% hit rate on pass 2.
    li   x12, 0           # reset counter
    li   x13, 0           # reset sum

seq_loop2:
    slli x14, x12, 2
    add  x15, x10, x14
    lw   x16, 0(x15)     # << Should be ALL HITS on pass 2
    add  x13, x13, x16
    addi x12, x12, 1
    blt  x12, x11, seq_loop2

    # ---- End ----
    li   x17, 10
    ecall
