# ============================================================
# Program 7: Set-Associative Cache Conflict Demonstration
# ============================================================
# This program creates access patterns that cause conflicts
# in a set-associative cache by accessing addresses that all
# map to the SAME cache set.
#
# Cache Configuration for this demo:
#   Cache size: 256 bytes
#   Line size:  16 bytes (4 words per line)
#   Associativity: 2-way set associative
#   => Number of sets = 256 / (16 * 2) = 8 sets
#   => Set index bits: 3 (bits 4-6 of address)
#   => A set can hold 2 lines before eviction
#
# Set mapping formula:
#   Set index = (address / line_size) mod num_sets
#   Set index = (address / 16) mod 8
#
# To cause conflicts: access addresses that differ by
#   set_count * line_size = 8 * 16 = 128 bytes
# These all map to the same set!
#
# With 2-way associativity, the 3rd distinct address mapping
# to the same set MUST evict one of the previous two.
# ============================================================

.data
    # Create data blocks spaced 128 bytes apart
    # All these blocks map to SET 0 in our cache config
    .align 4
    block_A: .word 0xAAAA0001, 0xAAAA0002, 0xAAAA0003, 0xAAAA0004
             .space 112   # padding to reach 128 bytes total

    block_B: .word 0xBBBB0001, 0xBBBB0002, 0xBBBB0003, 0xBBBB0004
             .space 112

    block_C: .word 0xCCCC0001, 0xCCCC0002, 0xCCCC0003, 0xCCCC0004
             .space 112

    block_D: .word 0xDDDD0001, 0xDDDD0002, 0xDDDD0003, 0xDDDD0004

.text
.globl main

main:
    # Get base addresses of each block
    la   x10, block_A
    la   x11, block_B
    la   x12, block_C
    la   x13, block_D

    # ============================================
    # Phase 1: Access A and B — both fit in 2-way set
    # ============================================
    # Access A -> MISS (compulsory), loads into set 0, way 0
    lw   x20, 0(x10)     # Load block_A[0] -> MISS
    # Access B -> MISS (compulsory), loads into set 0, way 1
    lw   x21, 0(x11)     # Load block_B[0] -> MISS
    # Re-access A -> HIT (still in set 0, way 0)
    lw   x22, 0(x10)     # Load block_A[0] -> HIT
    # Re-access B -> HIT (still in set 0, way 1)
    lw   x23, 0(x11)     # Load block_B[0] -> HIT

    # ============================================
    # Phase 2: Access C — CONFLICT! Evicts A or B
    # ============================================
    # Set 0 is full (A in way0, B in way1)
    # C maps to set 0 too — must evict one entry!
    lw   x24, 0(x12)     # Load block_C[0] -> MISS (conflict eviction!)

    # Now try to access A again — it was evicted!
    lw   x25, 0(x10)     # Load block_A[0] -> MISS (evicted by C!)

    # Try B — may or may not be evicted depending on policy
    lw   x26, 0(x11)     # Load block_B[0] -> depends on replacement

    # ============================================
    # Phase 3: Thrashing — cycle through A, B, C, D
    # ============================================
    # With only 2 ways, cycling through 4 blocks causes
    # EVERY access to be a miss (thrashing)
    li   x5, 4           # repeat 4 times

thrash_loop:
    lw   x20, 0(x10)     # block_A -> MISS (evicts someone)
    lw   x21, 0(x11)     # block_B -> MISS (evicts someone)
    lw   x22, 0(x12)     # block_C -> MISS (evicts someone)
    lw   x23, 0(x13)     # block_D -> MISS (evicts someone)
    addi x5, x5, -1
    bnez x5, thrash_loop

    # ============================================
    # Phase 4: Demonstrate HIGHER associativity helps
    # ============================================
    # When you change to 4-way associativity in Ripes,
    # Phase 3 should have NO conflict misses because
    # all 4 blocks fit in the 4 ways of a single set.
    # (Re-run this program with 4-way config to compare)

    # Final accesses to see hit/miss pattern
    lw   x20, 0(x10)     # A
    lw   x21, 0(x11)     # B
    lw   x22, 0(x12)     # C
    lw   x23, 0(x13)     # D

    # ---- End ----
    li   a7, 10
    ecall
