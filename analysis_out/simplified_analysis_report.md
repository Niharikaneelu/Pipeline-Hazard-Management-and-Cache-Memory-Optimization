# Simplified Ripes Analysis Report

This report is a simplified version of the full output and focuses on:
- data hazards
- hazard handling (stalling, forwarding)
- L1 set-associative cache behavior
- replacement policy comparison (LRU vs Random)
- performance comparison and optimal configuration

Data source:
- Pipeline metrics were measured from the latest rerun using Ripes CLI.
- Cache hit and miss counters are not exposed by this Ripes CLI build, so cache tables below use analytical values from program access patterns.

## 1) Data Hazards Observed

Programs 01 to 04 show classic hazards:
- RAW hazards: instruction uses a register before prior writeback.
- Load-use hazard: value from load is needed immediately in next instruction.
- Control hazard: branch depends on recently produced value.

Examples:
- Program 01: back-to-back dependencies and load-use sequence.
- Program 04: loop-carried dependencies, branch hazards, and multi-load dependency chains.

## 2) How Hazards Are Handled

Methods used:
- No handling: hazards can produce wrong results or force severe stalls.
- Stalling with NOPs: correctness guaranteed, but cycles are wasted.
- Forwarding (bypassing): value sent directly from later stage to dependent stage, reducing stalls.
- Scheduling: independent instruction fills load-use gap to reduce bubbles.

Measured comparison (Ripes CLI cycles):

| Case | Cycles | Instructions Retired | Pipeline Efficiency |
|---|---:|---:|---:|
| Program 01 (no forwarding, no hazard detection) | 36 | 32 | 88.89% |
| Program 01 (hazard detection, no forwarding) | 82 | 36 | 43.90% |
| Program 02 (manual NOP stalling) | 52 | 48 | 92.31% |
| Program 03 (forwarding) | 44 | 38 | 86.36% |
| Program 04 (forwarding OFF) | 591 | 239 | 40.44% |
| Program 04 (forwarding ON) | 349 | 239 | 68.48% |

Key throughput result:
- Program 04 forwarding ON vs OFF cycle reduction:
  - (591 - 349) / 591 = 40.95% improvement

## 3) L1 Cache Structure (Set-Associative)

Reference structure from the project setup:
- L1 data cache size: 256 bytes
- Config A: 16-byte lines, 2-way set-associative, 8 sets
- Config B: 32-byte lines, 2-way set-associative, 4 sets
- Config C: 16-byte lines, 4-way set-associative, 4 sets

Why set-associative helps:
- Direct-mapped caches are sensitive to conflicts.
- Higher associativity allows multiple lines mapping to same set, reducing conflict misses.

## 4) Cache Replacement: LRU vs Random

Program 08 pattern core: A -> B -> A -> C -> A (same set pressure)

Per 5 accesses (2-way set):
- LRU:
  - Hits: 2
  - Misses: 3
  - Hit rate: 40%
  - Miss rate: 60%
  - AMAT (Hit time 1, Miss penalty 10): 1 + 0.60*10 = 7.0 cycles
- Random (expected):
  - Hits: 1.5 (expected)
  - Misses: 3.5 (expected)
  - Hit rate: 30% (expected)
  - Miss rate: 70% (expected)
  - AMAT: 1 + 0.70*10 = 8.0 cycles

Conclusion:
- LRU outperforms Random for reuse-heavy patterns because it preserves recently reused blocks.

## 5) Cache Hit, Miss, AMAT (Analytical)

Assumptions:
- Hit time = 1 cycle
- Miss penalty = 10 cycles
- Program 06 values are for isolated stride sections used by the analyzer.

| Scenario | Hits | Misses | Hit Rate | Miss Rate | AMAT |
|---|---:|---:|---:|---:|---:|
| Program 05, 16B lines (2 passes total) | 112 | 16 | 87.50% | 12.50% | 2.25 |
| Program 05, 32B lines (2 passes total) | 120 | 8 | 93.75% | 6.25% | 1.63 |
| Program 06, stride 4 | 0 | 32 | 0.00% | 100.00% | 11.00 |
| Program 06, stride 8 | 0 | 16 | 0.00% | 100.00% | 11.00 |
| Program 06, stride 16 | 0 | 8 | 0.00% | 100.00% | 11.00 |
| Program 07, 2-way (thrashing loop only) | 0 | 16 | 0.00% | 100.00% | 11.00 |
| Program 07, 4-way (thrashing loop only) | 12 | 4 | 75.00% | 25.00% | 3.50 |
| Program 08, LRU (pattern expected) | 2 | 3 | 40.00% | 60.00% | 7.00 |
| Program 08, Random (pattern expected) | 1.5 | 3.5 | 30.00% | 70.00% | 8.00 |

## 6) Performance Comparison and Optimal Configurations

Pipeline (Program 09 measured):

| Pipeline Configuration | Cycles |
|---|---:|
| Single-cycle | 1062 |
| 5-stage, no forwarding (hazard detection ON) | 2776 |
| 5-stage, forwarding ON | 1258 |

Key comparison:
- Forwarding vs no-forwarding (both pipelined):
  - (2776 - 1258) / 2776 = 54.68% fewer cycles

Overall recommendation:
- For pipelined designs: enable forwarding and hazard detection.
- For cache behavior on these workloads: prefer larger lines for sequential workloads and higher associativity for conflict-heavy workloads.
- For replacement: LRU is preferred over Random for temporal-locality patterns.

Practical best configuration for this project goals:
- Pipeline: 5-stage with forwarding enabled
- Cache: set-associative with higher associativity where conflicts are high (Program 07), and larger lines where access is sequential (Program 05)
- Replacement policy: LRU over Random

## 7) Files Used

- Full detailed run output: [analysis_out/analysis_report.md](analysis_out/analysis_report.md)
- Full machine-readable output: [analysis_out/analysis_report.json](analysis_out/analysis_report.json)
