# ============================================================
# Program 6: Strided Array Access (Cache-Unfriendly)
# ============================================================
# This program accesses an array with large strides, causing
# poor spatial locality. Each access likely falls on a different
# cache line, leading to high miss rates.
#
# We test multiple stride values:
#   Stride 1  (4 bytes):  Best locality — baseline
#   Stride 4  (16 bytes): Skips one cache line per access
#   Stride 8  (32 bytes): Skips multiple cache lines
#   Stride 16 (64 bytes): Worst locality — every access misses
#
# Expected: As stride increases, miss rate increases because
# fewer accesses benefit from prefetched cache line data.
# ============================================================

.data
    # 256-element array = 1024 bytes
    .align 4
    array: .word  0,  1,  2,  3,  4,  5,  6,  7
           .word  8,  9, 10, 11, 12, 13, 14, 15
           .word 16, 17, 18, 19, 20, 21, 22, 23
           .word 24, 25, 26, 27, 28, 29, 30, 31
           .word 32, 33, 34, 35, 36, 37, 38, 39
           .word 40, 41, 42, 43, 44, 45, 46, 47
           .word 48, 49, 50, 51, 52, 53, 54, 55
           .word 56, 57, 58, 59, 60, 61, 62, 63
           .word 64, 65, 66, 67, 68, 69, 70, 71
           .word 72, 73, 74, 75, 76, 77, 78, 79
           .word 80, 81, 82, 83, 84, 85, 86, 87
           .word 88, 89, 90, 91, 92, 93, 94, 95
           .word 96, 97, 98, 99,100,101,102,103
           .word 104,105,106,107,108,109,110,111
           .word 112,113,114,115,116,117,118,119
           .word 120,121,122,123,124,125,126,127

    sum1: .word 0
    sum2: .word 0
    sum3: .word 0

.text
.globl main

main:
    la   x10, array       # Base address

    # ============================================
    # Test 1: Stride = 4 (every 4th element = 16 bytes apart)
    # ============================================
    # Accesses: array[0], array[4], array[8], ...
    # Each access is on a NEW cache line (16-byte lines)
    li   x11, 32          # 32 accesses
    li   x12, 0           # counter
    li   x13, 0           # sum
    li   x17, 4           # stride in elements

stride4_loop:
    mul  x14, x12, x17   # element index = counter * stride
    slli x14, x14, 2     # byte offset
    add  x15, x10, x14   # address
    lw   x16, 0(x15)     # << CACHE ACCESS (likely miss each time)
    add  x13, x13, x16   # sum
    addi x12, x12, 1
    blt  x12, x11, stride4_loop

    la   x18, sum1
    sw   x13, 0(x18)

    # ============================================
    # Test 2: Stride = 8 (every 8th element = 32 bytes apart)
    # ============================================
    li   x11, 16          # 16 accesses
    li   x12, 0
    li   x13, 0
    li   x17, 8           # stride

stride8_loop:
    mul  x14, x12, x17
    slli x14, x14, 2
    add  x15, x10, x14
    lw   x16, 0(x15)     # << CACHE ACCESS (high miss rate)
    add  x13, x13, x16
    addi x12, x12, 1
    blt  x12, x11, stride8_loop

    la   x18, sum2
    sw   x13, 0(x18)

    # ============================================
    # Test 3: Stride = 16 (every 16th element = 64 bytes apart)
    # ============================================
    li   x11, 8           # 8 accesses
    li   x12, 0
    li   x13, 0
    li   x17, 16          # stride

stride16_loop:
    mul  x14, x12, x17
    slli x14, x14, 2
    add  x15, x10, x14
    lw   x16, 0(x15)     # << CACHE ACCESS (nearly 100% miss rate)
    add  x13, x13, x16
    addi x12, x12, 1
    blt  x12, x11, stride16_loop

    la   x18, sum3
    sw   x13, 0(x18)

    # ---- End ----
    li   a7, 10
    ecall
