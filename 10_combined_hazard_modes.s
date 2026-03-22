# ============================================================
# Program 10: Combined Hazard Demo (Single Program, 3 Modes)
# ============================================================
# Run the SAME file with these processor configs in Ripes v2.2.6:
# 1) No hazard handling:
#      --proc RV32_5S_NO_FW_HZ
# 2) With forwarding:
#      --proc RV32_5S
# 3) Without forwarding (hardware stalling / hazard detection):
#      --proc RV32_5S_NO_FW
#
# This program intentionally contains RAW and load-use hazards.
# - Mode 1 can produce wrong results.
# - Mode 2 and Mode 3 should be correct.
# - Mode 2 should usually be faster than Mode 3.
# ============================================================

.data
    result_raw:       .word 0   # expected 26
    result_chain:     .word 0   # expected 96
    result_loaduse:   .word 0   # expected 126
    result_loopsum:   .word 0   # expected 32
    result_signature: .word 0   # expected 280

    arr: .word 5, 7, 9, 11

.text
.globl main

main:
    # -----------------------------
    # A) Simple RAW hazard
    # -----------------------------
    li   x2, 10
    li   x3, 20
    li   x5, 4

    add  x1, x2, x3      # x1 = 30
    sub  x4, x1, x5      # x4 = 26 (RAW hazard on x1)

    la   x6, result_raw
    sw   x4, 0(x6)

    # -----------------------------
    # B) Back-to-back chain hazards
    # -----------------------------
    li   x10, 3
    li   x11, 8

    add  x12, x10, x11   # x12 = 11
    sll  x13, x12, x10   # x13 = 88
    add  x14, x13, x12   # x14 = 99
    sub  x15, x14, x10   # x15 = 96

    la   x6, result_chain
    sw   x15, 0(x6)

    # -----------------------------
    # C) Load-use hazard
    # -----------------------------
    la   x20, result_raw
    lw   x21, 0(x20)     # x21 = 26
    addi x22, x21, 100   # x22 = 126 (load-use hazard)

    la   x6, result_loaduse
    sw   x22, 0(x6)

    # -----------------------------
    # D) Loop-carried + load-use hazard
    # -----------------------------
    la   x30, arr
    li   x31, 4
    li   x18, 0
    li   x12, 0

sum_loop:
    slli x13, x12, 2
    add  x14, x30, x13
    lw   x15, 0(x14)
    add  x18, x18, x15
    addi x12, x12, 1
    blt  x12, x31, sum_loop

    la   x6, result_loopsum
    sw   x18, 0(x6)

    # Signature helps quick correctness check in memory viewer.
    # expected signature = 26 + 96 + 126 + 32 = 280
    add  x7, x4, x15
    add  x7, x7, x22
    add  x7, x7, x18

    la   x6, result_signature
    sw   x7, 0(x6)

    li   x17, 10
    ecall
