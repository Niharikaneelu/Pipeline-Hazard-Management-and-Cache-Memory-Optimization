# ============================================================
# Program 2: Hazard Handling with NOP Stalling
# ============================================================
# Same instruction sequences as Program 1, but with NOP
# instructions manually inserted to resolve RAW hazards.
#
# Strategy: Insert enough NOPs between producer and consumer
# so the result is written back before the consumer reads it.
#
# In a 5-stage pipeline WITHOUT forwarding:
#   - EX->EX hazard: need 2 NOPs (wait for WB to complete)
#   - MEM->EX hazard (load-use): need 2 NOPs
#
# Trade-off: Correctness is guaranteed, but throughput drops
# because NOP cycles are wasted doing no useful work.
# ============================================================

.data
    result1: .word 0
    result2: .word 0
    result3: .word 0
    result4: .word 0

.text
.globl main

main:
    # ---- Section A: Simple RAW Hazard — Resolved with NOPs ----
    li   x2, 10
    li   x3, 20
    li   x5, 5

    add  x1, x2, x3      # x1 = 30  (result in WB at cycle N+4)
    nop                   # Stall cycle 1
    nop                   # Stall cycle 2  — x1 now written back
    sub  x4, x1, x5      # x4 = 30 - 5 = 25  (safe to read x1)

    la   x6, result1
    sw   x4, 0(x6)

    # ---- Section B: Chain Hazard — Each dependency resolved ----
    li   x10, 3
    li   x11, 7

    add  x12, x10, x11   # x12 = 10
    nop
    nop
    sll  x13, x12, x10   # x13 = 10 << 3 = 80
    nop
    nop
    add  x14, x13, x12   # x14 = 80 + 10 = 90
    nop
    nop
    sub  x15, x14, x10   # x15 = 90 - 3 = 87

    la   x6, result2
    sw   x15, 0(x6)

    # ---- Section C: Load-Use Hazard — Resolved with NOPs ----
    la   x20, result1
    lw   x21, 0(x20)     # x21 = 25 (loaded from memory)
    nop                   # Stall cycle 1
    nop                   # Stall cycle 2
    addi x22, x21, 100   # x22 = 125

    la   x6, result3
    sw   x22, 0(x6)

    # ---- Section D: Multi-Producer — Resolved with NOPs ----
    li   x7, 2
    li   x8, 4
    li   x9, 6

    mul  x23, x7, x8     # x23 = 8
    nop
    nop
    add  x24, x23, x9    # x24 = 14
    nop
    nop
    sub  x25, x24, x23   # x25 = 6
    nop
    nop
    add  x26, x25, x24   # x26 = 20

    la   x6, result4
    sw   x26, 0(x6)

    # ---- End Program ----
    li   a7, 10
    ecall
