# RISC-V Pipelining & Memory Hierarchy — Ripes Project Guide

A complete guide for running 9 RISC-V assembly programs in the **Ripes simulator** to study processor pipelining, data hazards, cache organization, and performance analysis.

---

## Table of Contents

1. [Ripes Setup](#1-ripes-setup)
2. [Part 1: Pipeline & Data Hazards (Programs 01–04)](#2-part-1-pipeline--data-hazards)
3. [Part 2: Cache Memory Analysis (Programs 05–08)](#3-part-2-cache-memory-analysis)
4. [Part 3: Performance Benchmark (Program 09)](#4-part-3-performance-benchmark)
5. [Performance Metrics Tables](#5-performance-metrics-tables)
6. [Analysis Questions](#6-analysis-questions)

---

## 1. Ripes Setup

### Installing Ripes
1. Download Ripes from: **https://github.com/mortbopet/Ripes/releases**
2. Extract and run `Ripes.exe` (Windows) — no installation needed.

### Loading a Program
1. Open Ripes → Click **"File → Load Program"** or use the **Editor tab**
2. In the **Editor tab**: paste or open the `.s` assembly file
3. Click the **"Assemble"** button (hammer icon) to compile
4. If there are errors, they appear in the console at the bottom

### Selecting a Processor
Go to **"Processor" tab** (gear icon in top-left):

| Configuration | When to Use |
|---|---|
| **Single-cycle** | Baseline comparison (no pipeline) |
| **5-stage pipeline (no forwarding, no hazard detection)** | Programs 01–02: see raw hazards |
| **5-stage pipeline (with hazard detection)** | Programs 01–02: see automatic stalls |
| **5-stage pipeline (with forwarding)** | Programs 03–04: see forwarding in action |

**How to change processor:**
1. Click the **processor select** button (top-left corner, looks like a CPU chip)
2. Choose **"5-Stage Processor"**
3. Check/uncheck **"Enable forwarding"** and **"Enable hazard detection"** as needed

---

## 2. Part 1: Pipeline & Data Hazards

### Program 01: RAW Hazard Demonstration

**File:** `01_raw_hazard_no_handling.s`

**What it demonstrates:** Read-After-Write (RAW) data hazards where a register is written by one instruction and read by the very next instruction.

**Ripes Steps:**
1. Select **5-stage pipeline** processor
2. **Disable forwarding** and **disable hazard detection**
3. Load and assemble `01_raw_hazard_no_handling.s`
4. Click **"Run"** (play button) or **step through** instruction by instruction
5. Observe the **Pipeline Diagram** tab:
   - Look for instructions in the **same column** — this shows simultaneous execution
   - With hazard detection OFF, the results may be **INCORRECT** (wrong values in registers)
   - Check register x4: should be 25, but may be wrong without hazard handling
6. Now **enable hazard detection** (but keep forwarding OFF) and re-run:
   - You'll see **stall bubbles** automatically inserted by the hardware
   - Results should now be **CORRECT**
   - Count the number of stall cycles in the pipeline diagram

**What to record:**
- Number of clock cycles (shown at bottom of Ripes window)
- Number of stalls visible in the pipeline diagram
- Register values x4, x15, x22, x26

---

### Program 02: NOP Stalling

**File:** `02_hazard_stalling_nops.s`

**What it demonstrates:** Manually inserting NOP instructions to resolve RAW hazards.

**Ripes Steps:**
1. Select **5-stage pipeline, NO forwarding, NO hazard detection**
2. Load `02_hazard_stalling_nops.s`
3. Step through and observe:
   - NOPs appear as real instructions in the pipeline, taking up stages
   - The dependent instruction now reads the register AFTER the write completes
   - Results are **CORRECT** even without hardware hazard detection
4. Record the total clock cycles — compare with Program 01

**Key observation:** NOPs guarantee correctness but waste cycles. Each NOP uses pipeline resources without doing useful work.

---

### Program 03: Forwarding (Data Bypassing)

**File:** `03_hazard_forwarding.s`

**What it demonstrates:** How hardware forwarding eliminates stalls by routing results directly between pipeline stages.

**Ripes Steps:**
1. Select **5-stage pipeline WITH forwarding enabled**
2. Load `03_hazard_forwarding.s`
3. Step through and observe the **Pipeline Diagram**:
   - Look for **colored forwarding paths** (arrows bypassing pipeline stages)
   - In Section B (chain), all 4 instructions execute without any stall
   - In Section C, the independent instruction `addi x29, x28, 25` fills the load-use delay slot
4. Record total clock cycles — this should be **fewer** than Programs 01 and 02

**Key observation:** Compare the cycle counts:
- Program 01 (hardware stalls): _____ cycles
- Program 02 (NOP stalls): _____ cycles
- Program 03 (forwarding): _____ cycles — **fastest!**

---

### Program 04: Complex Hazard Scenarios

**File:** `04_complex_hazards.s`

**What it demonstrates:** Real-world hazard patterns: loop-carried dependencies, find-max with branches, dot product with double loads.

**Ripes Steps:**
1. **Run A**: With forwarding **OFF**, hazard detection **ON** → record cycles
2. **Run B**: With forwarding **ON** → record cycles
3. Step through the **sum_loop** section and observe:
   - `lw x15, 0(x14)` followed by `add x18, x18, x15` — load-use hazard
   - The branch `blt x12, x11, sum_loop` creates a control hazard
4. Verify final values:
   - `sum_val` memory = 55 (sum of 1..10)
   - `max_val` memory = 10
   - `dot_res` memory = 35

---

## 3. Part 2: Cache Memory Analysis

### Enabling the Cache in Ripes

1. Go to the **"Cache"** tab (or Memory tab, depending on Ripes version)
2. **Enable the data cache** by checking the cache checkbox
3. Configure the cache parameters as shown below

### Cache Configuration Table

| Parameter | Config A (Default) | Config B (Larger Lines) | Config C (Higher Assoc) |
|---|---|---|---|
| Cache Size | 256 bytes | 256 bytes | 256 bytes |
| Line Size | 16 bytes | 32 bytes | 16 bytes |
| Associativity | 2-way | 2-way | 4-way |
| Replacement | LRU | LRU | LRU |
| Sets | 8 | 4 | 4 |

---

### Program 05: Sequential Access (Cache-Friendly)

**File:** `05_cache_sequential.s`

**Ripes Steps:**
1. Configure cache as **Config A** (256B, 16B lines, 2-way, LRU)
2. Load and assemble `05_cache_sequential.s`
3. Click **Run** to execute completely
4. Go to the **Cache** tab and record:
   - **Hits:** _____
   - **Misses:** _____
   - **Hit Rate:** _____% 
5. **Reset** and re-run with **Config B** (32B lines)
6. Record again — hit rate should **improve** with larger lines

**Expected observations:**
- Pass 1: ~25% miss rate (1 miss per 4-word cache line)
- Pass 2: ~0% miss rate (all data still cached = temporal locality)
- Larger lines → lower miss rate (better spatial locality exploitation)

---

### Program 06: Strided Access (Cache-Unfriendly)

**File:** `06_cache_strided.s`

**Ripes Steps:**
1. Use **Config A**
2. Run and record cache stats for each stride section:

| Stride | Accesses | Expected Miss Rate | Your Hits | Your Misses | Your Hit Rate |
|---|---|---|---|---|---|
| 4 (16B) | 32 | ~100% (each access = new line) | | | |
| 8 (32B) | 16 | ~100% | | | |
| 16 (64B) | 8 | ~100% | | | |

**Key observation:** Compare with Program 05. Sequential access had ~75% hit rate; strided access has near 0% hit rate. This shows the importance of **spatial locality**.

---

### Program 07: Set-Associative Cache Conflicts

**File:** `07_cache_set_associative.s`

**Ripes Steps:**
1. **Run 1:** Config A (2-way associative)
   - Watch the cache tab during Phase 3 (thrashing loop)
   - All 4 blocks map to the same set, but only 2 ways → **100% miss rate in loop**
   - Record total hits and misses

2. **Run 2:** Config C (4-way associative)
   - Same program, but now 4 ways per set
   - All 4 blocks fit in the set → **thrashing loop should have hits**
   - Record total hits and misses

| Configuration | Hits | Misses | Hit Rate |
|---|---|---|---|
| 2-way (Config A) | | | |
| 4-way (Config C) | | | |

**Key observation:** Higher associativity reduces conflict misses at the cost of more complex hardware.

---

### Program 08: LRU vs FIFO Replacement

**File:** `08_cache_replacement.s`

**Ripes Steps:**
1. **Run 1:** Config A with **LRU replacement**
   - Record hits and misses
2. **Run 2:** Same config but switch replacement to **FIFO**
   - Record hits and misses
3. Compare the results:

| Replacement Policy | Hits | Misses | Hit Rate |
|---|---|---|---|
| LRU | | | |
| FIFO | | | |

**Key pattern:** The sequence A→B→A→C→A is designed so that:
- **LRU** keeps A (recently accessed), evicts B → A access = **HIT**
- **FIFO** evicts A (oldest loaded), keeps B → A access = **MISS**

---

## 4. Part 3: Performance Benchmark

### Program 09: Matrix Multiplication Benchmark

**File:** `09_performance_benchmark.s`

This is the final comprehensive benchmark. Run it under **all** combinations:

**Ripes Steps:**

**Step 1 — Pipeline comparison (no cache):**

| Pipeline Config | Clock Cycles | Stalls |
|---|---|---|
| Single-cycle processor | | N/A |
| 5-stage, no forwarding, hazard detection ON | | |
| 5-stage, with forwarding | | |

**Step 2 — Cache comparison (with forwarding ON):**

| Cache Config | Hits | Misses | Hit Rate |
|---|---|---|---|
| No cache (baseline) | N/A | N/A | N/A |
| 256B, 16B lines, 2-way, LRU | | | |
| 256B, 32B lines, 2-way, LRU | | | |
| 256B, 16B lines, 4-way, LRU | | | |
| 256B, 16B lines, 2-way, FIFO | | | |

**Verify correctness:**
Result matrix C should be:
```
C = [ 5,  2,  3,  5  ]
    [ 13, 6,  7,  13 ]
    [ 21, 10, 11, 21 ]
    [ 29, 14, 15, 29 ]
```
Check the memory viewer at address `matC` to confirm.

---

## 5. Performance Metrics Tables

### Pipeline Efficiency Metrics

Fill in after running Programs 01–04:

```
Pipeline Efficiency = (Useful Instructions) / (Total Clock Cycles)

                            | Cycles | Instructions | Efficiency | Stalls
Program 01 (no handling)    |        |              |            |
Program 02 (NOP stalling)   |        |              |            |
Program 03 (forwarding)     |        |              |            |
Program 04 (fwd OFF)        |        |              |            |
Program 04 (fwd ON)         |        |              |            |
```

### Cache Performance Metrics

Fill in after running Programs 05–08:

```
Hit Rate = Hits / (Hits + Misses) × 100%
Miss Rate = Misses / (Hits + Misses) × 100%
AMAT = Hit Time + (Miss Rate × Miss Penalty)
  (Assume: Hit Time = 1 cycle, Miss Penalty = 10 cycles)

                                  | Hits | Misses | Hit Rate | Miss Rate | AMAT
Prog 05 Sequential (16B lines)   |      |        |          |           |
Prog 05 Sequential (32B lines)   |      |        |          |           |
Prog 06 Stride-4                 |      |        |          |           |
Prog 06 Stride-8                 |      |        |          |           |
Prog 06 Stride-16                |      |        |          |           |
Prog 07 (2-way)                  |      |        |          |           |
Prog 07 (4-way)                  |      |        |          |           |
Prog 08 (LRU)                    |      |        |          |           |
Prog 08 (FIFO)                   |      |        |          |           |
```

---

## 6. Analysis Questions

Answer these after completing all experiments:

### Pipeline Analysis
1. **How many stall cycles** does Program 01 produce compared to Program 02? Why are they similar or different?
2. **What percentage improvement** in clock cycles does forwarding (Program 03) achieve over NOP stalling (Program 02)?
3. In Program 04, which section (sum, max, dot product) has the **most hazards per instruction**? Why?
4. Why can't forwarding fully eliminate the load-use hazard? What is the minimum stall for a load-use hazard even with forwarding?

### Cache Analysis
5. Calculate the **theoretical miss rate** for Program 05 with 16-byte cache lines. Does your measured result match?
6. Why does increasing the line size improve hit rate for sequential access but NOT for strided access?
7. In Program 07, what is the **minimum associativity** needed to eliminate all conflict misses in the thrashing loop?
8. For the A→B→A→C→A access pattern (Program 08), prove that **LRU produces 1 more hit** than FIFO.

### Overall Performance
9. For the matrix multiplication benchmark (Program 09):
   - What is the **optimal configuration** (pipeline + cache settings) for the lowest cycle count?
   - What is the **worst configuration**?
   - Calculate the **speedup** of optimal over worst.
10. If you could change ONE thing about the matrix multiplication code to improve cache performance, what would you change and why? (Hint: think about the access pattern of matrix B.)

---

## Quick Reference: Ripes Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| F5 | Run program |
| F6 | Step one clock cycle |
| F7 | Step one instruction |
| Ctrl+R | Reset simulation |
| Ctrl+O | Open/load file |

---

## Quick Reference: RISC-V Registers

| Register | ABI Name | Usage |
|---|---|---|
| x0 | zero | Always 0 |
| x1 | ra | Return address |
| x2 | sp | Stack pointer |
| x5-x7 | t0-t2 | Temporaries |
| x10-x17 | a0-a7 | Arguments/return values |
| x18-x27 | s2-s11 | Saved registers |
| x28-x31 | t3-t6 | Temporaries |
