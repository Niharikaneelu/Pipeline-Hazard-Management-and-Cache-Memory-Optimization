# ============================================================
# Program 8: LRU vs FIFO Cache Replacement Policy Comparison
# ============================================================
# This program creates an access pattern where LRU and FIFO
# replacement policies produce DIFFERENT results.
#
# Cache Config:
#   Cache size: 256 bytes
#   Line size:  16 bytes
#   Associativity: 2-way
#   => 8 sets, 2 ways per set
#
# Key insight for LRU vs FIFO difference:
#   LRU: Evicts the LEAST RECENTLY USED line
#   FIFO: Evicts the line that was loaded FIRST (oldest)
#
#   Sequence: A, B, A, C
#   - LRU keeps A (recently used), evicts B
#   - FIFO evicts A (loaded first), keeps B
#   Then accessing A after C:
#   - Under LRU: A is still in cache -> HIT
#   - Under FIFO: A was evicted -> MISS
#
# Run this program TWICE in Ripes:
#   1) With replacement policy = LRU
#   2) With replacement policy = FIFO
# Compare the total hits and misses!
# ============================================================

.data
    # Blocks spaced 128 bytes apart -> all map to same set
    .align 4
    block_A: .word 0x11111111, 0x11111112, 0x11111113, 0x11111114
             .space 112

    block_B: .word 0x22222222, 0x22222223, 0x22222224, 0x22222225
             .space 112

    block_C: .word 0x33333333, 0x33333334, 0x33333335, 0x33333336

.text
.globl main

main:
    la   x10, block_A
    la   x11, block_B
    la   x12, block_C

    # ============================================
    # Test Pattern 1: A, B, A, C, A
    # ============================================
    # This pattern highlights the LRU vs FIFO difference

    # Step 1: Load A (MISS — compulsory)
    # Set 0: [A, -]
    lw   x20, 0(x10)     # A -> MISS (both policies)

    # Step 2: Load B (MISS — compulsory)
    # Set 0: [A, B]
    lw   x21, 0(x11)     # B -> MISS (both policies)

    # Step 3: Access A again (HIT — A is in cache)
    # LRU: A is now most recently used
    # FIFO: A is still the oldest entry (loaded first)
    # Set 0: [A, B] (no change)
    lw   x22, 0(x10)     # A -> HIT (both policies)

    # Step 4: Load C (MISS — conflict, must evict!)
    # LRU:  Evicts B (least recently used) -> Set 0: [A, C]
    # FIFO: Evicts A (oldest / first loaded) -> Set 0: [B, C]
    lw   x23, 0(x12)     # C -> MISS (both policies)

    # Step 5: Access A
    # LRU:  A is still in cache -> HIT!     Set 0: [A, C]
    # FIFO: A was evicted in step 4 -> MISS! Must reload A
    lw   x24, 0(x10)     # A -> HIT (LRU) / MISS (FIFO) <<<< DIFFERENCE!

    # ============================================
    # Test Pattern 2: Repeated A, B, A, C, A sequence
    # ============================================
    # Repeating the pattern amplifies the difference
    li   x5, 5           # Repeat 5 times

pattern_loop:
    lw   x20, 0(x10)     # A
    lw   x21, 0(x11)     # B
    lw   x20, 0(x10)     # A (re-access -> updates LRU status)
    lw   x22, 0(x12)     # C (conflict eviction)
    lw   x20, 0(x10)     # A (HIT under LRU, MISS under FIFO)
    addi x5, x5, -1
    bnez x5, pattern_loop

    # ============================================
    # Test Pattern 3: Sequential then re-access
    # ============================================
    # A, B, C, A, B, C — all misses for both policies
    # Then A, A, A — shows temporal locality effect
    lw   x20, 0(x10)     # A -> depends on state
    lw   x21, 0(x11)     # B -> conflict
    lw   x22, 0(x12)     # C -> conflict
    lw   x20, 0(x10)     # A -> MISS (evicted by B or C)
    lw   x20, 0(x10)     # A -> HIT  (just loaded)
    lw   x20, 0(x10)     # A -> HIT  (still in cache)

    # ============================================
    # Record your results:
    # ============================================
    # After running with LRU:
    #   Total Hits:   ___    Total Misses: ___
    #   Hit Rate:     ___%
    #
    # After running with FIFO:
    #   Total Hits:   ___    Total Misses: ___
    #   Hit Rate:     ___%
    #
    # Expected: LRU should have MORE hits because it keeps
    # the frequently re-accessed block A in cache.

    # ---- End ----
    li   a7, 10
    ecall
