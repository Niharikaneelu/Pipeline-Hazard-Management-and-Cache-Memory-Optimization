# ============================================================
# Program 1: RAW Data Hazard Demonstration (No Handling)
# ============================================================
# This program contains instruction sequences with Read-After-Write
# (RAW) data hazards. When run on a 5-stage pipelined processor
# WITHOUT forwarding, the pipeline must stall to resolve these.
#
# RISC-V 5-Stage Pipeline: IF -> ID -> EX -> MEM -> WB
#
# Hazard: A register written by one instruction is read by the
#         very next instruction before the write completes.
# ============================================================

.data
    result1: .word 0
    result2: .word 0
    result3: .word 0
    result4: .word 0

.text
.globl main

main:
    # ---- Section A: Simple RAW Hazard (EX -> EX) ----
    # x1 is written by ADD, then immediately read by SUB
    # Hazard: x1 not yet written back when SUB needs it in ID/EX
    li   x2, 10          # x2 = 10
    li   x3, 20          # x3 = 20
    li   x5, 5           # x5 = 5

    add  x1, x2, x3      # x1 = 10 + 20 = 30   (WB in cycle N+4)
    sub  x4, x1, x5      # x4 = x1 - 5 = 25    (needs x1 in cycle N+2) << RAW HAZARD

    la   x6, result1
    sw   x4, 0(x6)       # Store result1 = 25

    # ---- Section B: Back-to-Back RAW Hazard (chain) ----
    # Each instruction depends on the result of the previous one
    li   x10, 3           # x10 = 3
    li   x11, 7           # x11 = 7

    add  x12, x10, x11   # x12 = 3 + 7 = 10     << Producer
    sll  x13, x12, x10   # x13 = x12 << 3 = 80  << RAW on x12
    add  x14, x13, x12   # x14 = 80 + 10 = 90   << RAW on x13 AND x12
    sub  x15, x14, x10   # x15 = 90 - 3 = 87    << RAW on x14

    la   x6, result2
    sw   x15, 0(x6)      # Store result2 = 87

    # ---- Section C: Load-Use RAW Hazard (MEM -> EX) ----
    # Load followed by an instruction that uses the loaded value.
    # This is a special case � even with forwarding, a 1-cycle
    # stall is typically needed (load-use hazard).
    la   x20, result1
    lw   x21, 0(x20)     # x21 = mem[result1] = 25  (data available after MEM)
    addi x22, x21, 100   # x22 = x21 + 100 = 125    << LOAD-USE HAZARD

    la   x6, result3
    sw   x22, 0(x6)      # Store result3 = 125

    # ---- Section D: Multiple Producer-Consumer Hazards ----
    li   x7, 2
    li   x8, 4
    li   x9, 6

    mul  x23, x7, x8     # x23 = 2 * 4 = 8        << Producer
    add  x24, x23, x9    # x24 = 8 + 6 = 14       << RAW on x23
    sub  x25, x24, x23   # x25 = 14 - 8 = 6       << RAW on x24 AND x23
    add  x26, x25, x24   # x26 = 6 + 14 = 20      << RAW on x25 AND x24

    la   x6, result4
    sw   x26, 0(x6)      # Store result4 = 20

    # ---- End Program ----
    li   x17, 10          # ecall exit (a7)
    ecall
