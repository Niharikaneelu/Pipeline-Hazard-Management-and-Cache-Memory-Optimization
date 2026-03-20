# ============================================================
# Program 3: Hazard Handling with Forwarding (Data Bypassing)
# ============================================================
# This program demonstrates instruction reordering to work
# optimally WITH hardware forwarding (data bypassing) enabled.
#
# When forwarding is enabled in Ripes:
#   - EX->EX forwarding: result from EX stage forwarded directly
#     to the next instruction's EX stage — NO stall needed.
#   - MEM->EX forwarding: loaded value forwarded from MEM to EX
#     — still requires 1 stall for load-use, which we fill with
#     an independent instruction (instruction scheduling).
#
# Key technique: Reorder independent instructions to fill
# "slots" that would otherwise be stalls.
# ============================================================

.data
    result1: .word 0
    result2: .word 0
    result3: .word 0
    result4: .word 0

.text
.globl main

main:
    # ---- Section A: EX->EX Forwarding — Zero stalls ----
    # With forwarding ON, the result of ADD is available at the
    # end of EX and forwarded directly to SUB's EX stage.
    li   x2, 10
    li   x3, 20
    li   x5, 5

    add  x1, x2, x3      # x1 = 30  -> forwarded from EX output
    sub  x4, x1, x5      # x4 = 25  <- receives x1 via forwarding path
    # NO stall needed! Forwarding resolves the hazard.

    la   x6, result1
    sw   x4, 0(x6)

    # ---- Section B: Chain with Forwarding — Zero stalls ----
    # Forwarding handles all EX->EX dependencies in the chain.
    li   x10, 3
    li   x11, 7

    add  x12, x10, x11   # x12 = 10   -> forwarded
    sll  x13, x12, x10   # x13 = 80   <- x12 forwarded, -> forwarded
    add  x14, x13, x12   # x14 = 90   <- x13 forwarded
    sub  x15, x14, x10   # x15 = 87   <- x14 forwarded
    # Full chain executes without stalls when forwarding is ON!

    la   x6, result2
    sw   x15, 0(x6)

    # ---- Section C: Load-Use with Instruction Scheduling ----
    # Even with forwarding, load-use hazards need 1 stall.
    # Solution: insert an INDEPENDENT instruction in the slot.
    la   x20, result1
    li   x28, 50          # Independent: prepare x28 for later use
    lw   x21, 0(x20)     # x21 = mem[result1]   (data ready after MEM)
    addi x29, x28, 25    # INDEPENDENT instruction fills load-use slot!
    addi x22, x21, 100   # x22 = x21 + 100  (x21 now forwarded from MEM)

    la   x6, result3
    sw   x22, 0(x6)

    # ---- Section D: Scheduled Multi-Producer ----
    # Reorder instructions to maximize forwarding effectiveness
    li   x7, 2
    li   x8, 4
    li   x9, 6

    mul  x23, x7, x8     # x23 = 8   -> forwarded
    add  x24, x23, x9    # x24 = 14  <- x23 forwarded, -> forwarded
    sub  x25, x24, x23   # x25 = 6   <- x24, x23 forwarded, -> forwarded
    add  x26, x25, x24   # x26 = 20  <- x25, x24 forwarded

    la   x6, result4
    sw   x26, 0(x6)

    # ---- Performance Summary ----
    # Compare clock cycles of this program vs Program 01 and 02:
    #   Program 01: Hazards cause hardware stalls -> slowest (without forwarding)
    #   Program 02: NOP stalls waste cycles -> still slow
    #   Program 03: Forwarding eliminates most stalls -> fastest

    li   a7, 10
    ecall
