# ============================================================
# Program 4: Complex Pipeline Hazard Scenarios
# ============================================================
# This program demonstrates multiple types of pipeline hazards
# in realistic code patterns:
#   A) Loop with loop-carried RAW dependency
#   B) Function-call-style register hazards
#   C) Memory address computation hazards
#   D) Branch and control hazards
#
# Run this with forwarding ON and OFF to compare behavior.
# ============================================================

.data
    array:   .word 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    sum_val: .word 0
    max_val: .word 0
    dot_a:   .word 3, 1, 4, 1, 5
    dot_b:   .word 2, 7, 1, 8, 2
    dot_res: .word 0

.text
.globl main

main:
    # ============================================
    # Section A: Loop-Carried RAW Dependency
    # ============================================
    # Sum of array: accumulator x18 is written and read each
    # iteration — classic loop-carried dependency.
    la   x10, array       # x10 = base address of array
    li   x11, 10          # x11 = number of elements
    li   x18, 0           # x18 = accumulator (sum = 0)
    li   x12, 0           # x12 = loop counter

sum_loop:
    slli x13, x12, 2     # x13 = counter * 4 (byte offset)  << RAW: x12
    add  x14, x10, x13   # x14 = &array[i]                  << RAW: x13
    lw   x15, 0(x14)     # x15 = array[i]                   << RAW: x14 (addr)
    add  x18, x18, x15   # sum += array[i]       << RAW: x15 (load-use!) AND x18
    addi x12, x12, 1     # i++                              << RAW: x12
    blt  x12, x11, sum_loop  # branch:                      << RAW: x12 (control)

    la   x6, sum_val
    sw   x18, 0(x6)      # Store sum = 55

    # ============================================
    # Section B: Find Maximum (conditional hazards)
    # ============================================
    la   x10, array
    li   x11, 10
    lw   x19, 0(x10)     # x19 = max = array[0] = 1       << load-use potential
    li   x12, 1          # Start from index 1

max_loop:
    slli x13, x12, 2
    add  x14, x10, x13
    lw   x15, 0(x14)     # x15 = array[i]                  << load-use
    bge  x19, x15, skip_update  # if max >= array[i], skip  << RAW: x15, x19
    mv   x19, x15        # max = array[i]                  << RAW: x15

skip_update:
    addi x12, x12, 1
    blt  x12, x11, max_loop

    la   x6, max_val
    sw   x19, 0(x6)      # Store max = 10

    # ============================================
    # Section C: Dot Product (double load-use)
    # ============================================
    # dot = sum(a[i] * b[i]) — two loads followed by multiply
    la   x20, dot_a       # base of array A
    la   x21, dot_b       # base of array B
    li   x22, 5           # length
    li   x23, 0           # dot product accumulator
    li   x24, 0           # loop counter

dot_loop:
    slli x25, x24, 2     # offset = i * 4                   << RAW: x24
    add  x26, x20, x25   # &a[i]                            << RAW: x25
    add  x27, x21, x25   # &b[i]                            << RAW: x25
    lw   x28, 0(x26)     # x28 = a[i]                       << RAW: x26
    lw   x29, 0(x27)     # x29 = b[i]                       << RAW: x27
    mul  x30, x28, x29   # x30 = a[i]*b[i]     << RAW: x28 AND x29 (load-use!)
    add  x23, x23, x30   # dot += a[i]*b[i]    << RAW: x30 AND x23
    addi x24, x24, 1
    blt  x24, x22, dot_loop

    la   x6, dot_res
    sw   x23, 0(x6)      # Store dot product = 3*2+1*7+4*1+1*8+5*2 = 6+7+4+8+10 = 35

    # ============================================
    # Section D: Branch Hazard Demonstration
    # ============================================
    # Tight branch sequence — the branch decision depends on a
    # just-computed value, causing control hazard.
    li   x5, 1
    li   x6, 10
    li   x7, 0            # result counter

branch_loop:
    addi x7, x7, 1       # x7++
    rem  x8, x7, x5      # x8 = x7 % 1 = 0 always          << RAW: x7
    beqz x8, continue    # branch depends on x8              << RAW: x8 (control)
    j    done             # never reached in this case

continue:
    blt  x7, x6, branch_loop  # loop while x7 < 10          << RAW: x7

done:
    # x7 should be 10 after the loop

    # ---- End Program ----
    li   a7, 10
    ecall
