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
# This program intentionally contains RAW data hazards only.
# - Mode 1 can produce wrong results.
# - Mode 2 and Mode 3 should be correct.
# - Mode 2 should usually be faster than Mode 3.
# ============================================================

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

    # -----------------------------
    # B) Back-to-back chain hazards
    # -----------------------------
    li   x10, 3
    li   x11, 8

    add  x12, x10, x11   # x12 = 11
    sll  x13, x12, x10   # x13 = 88
    add  x14, x13, x12   # x14 = 99
    sub  x15, x14, x10   # x15 = 96

    # -----------------------------
    # C) Multi-source RAW hazards
    # -----------------------------
    li   x6, 2
    li   x7, 5
    li   x8, 9

    mul  x20, x6, x7     # producer
    add  x21, x20, x8    # RAW on x20
    sub  x22, x21, x20   # RAW on x21 and x20
    add  x23, x22, x21   # RAW on x22 and x21

    li   x17, 10
    ecall
