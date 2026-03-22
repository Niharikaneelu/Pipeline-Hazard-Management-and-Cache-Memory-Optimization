# Ripes CLI Automated Report

## Run Summary

| Run | RC | Cycles | IRet | CPI | IPC | Hits | Misses |
|---|---:|---:|---:|---:|---:|---:|---:|
| p01_no_handling | 0 | 36 | 32 | 1.12 | 0.89 | N/A | N/A |
| p01_with_hazard_detection | 0 | 82 | 36 | 2.28 | 0.44 | N/A | N/A |
| p02_nop_stalling | 0 | 52 | 48 | 1.08 | 0.92 | N/A | N/A |
| p03_forwarding | 0 | 44 | 38 | 1.16 | 0.86 | N/A | N/A |
| p04_forwarding_off | 0 | 591 | 239 | 2.47 | 0.40 | N/A | N/A |
| p04_forwarding_on | 0 | 349 | 239 | 1.46 | 0.68 | N/A | N/A |
| p05_cfg_a | 0 | 1166 | 780 | 1.49 | 0.67 | N/A | N/A |
| p05_cfg_b | 0 | 1166 | 780 | 1.49 | 0.67 | N/A | N/A |
| p06_stride16 | 0 | 537 | 417 | 1.29 | 0.78 | N/A | N/A |
| p06_stride4 | 0 | 561 | 417 | 1.35 | 0.74 | N/A | N/A |
| p06_stride8 | 0 | 545 | 417 | 1.31 | 0.77 | N/A | N/A |
| p07_cfg_a_2way | 0 | 58 | 46 | 1.26 | 0.79 | N/A | N/A |
| p07_cfg_c_4way | 0 | 58 | 46 | 1.26 | 0.79 | N/A | N/A |
| p08_fifo | 0 | 69 | 55 | 1.25 | 0.80 | N/A | N/A |
| p08_lru | 0 | 69 | 55 | 1.25 | 0.80 | N/A | N/A |
| p09_cache_baseline | 0 | 1258 | 1062 | 1.18 | 0.84 | N/A | N/A |
| p09_cache_cfg_a | 0 | 1258 | 1062 | 1.18 | 0.84 | N/A | N/A |
| p09_cache_cfg_b | 0 | 1258 | 1062 | 1.18 | 0.84 | N/A | N/A |
| p09_cache_cfg_c | 0 | 1258 | 1062 | 1.18 | 0.84 | N/A | N/A |
| p09_cache_fifo | 0 | 1258 | 1062 | 1.18 | 0.84 | N/A | N/A |
| p09_pipeline_5s_fwd | 0 | 1258 | 1062 | 1.18 | 0.84 | N/A | N/A |
| p09_pipeline_5s_hzd | 0 | 2776 | 1062 | 2.61 | 0.38 | N/A | N/A |
| p09_pipeline_single | 0 | 1062 | 1062 | 1 | 1 | N/A | N/A |

## Pipeline Efficiency (Programs 01-04)

| Program | Cycles | Instructions | Efficiency | Stalls (est.) |
|---|---:|---:|---:|---:|
| Program 01 | 36 | 32 | 88.89% | 0 |
| Program 02 | 52 | 48 | 92.31% | 0 |
| Program 03 | 44 | 38 | 86.36% | 2 |
| Program 04 fwd OFF | 591 | 239 | 40.44% | 348 |
| Program 04 fwd ON | 349 | 239 | 68.48% | 106 |

## Cache Performance (Programs 05-08)

| Case | Hits | Misses | Hit Rate | Miss Rate | AMAT |
|---|---:|---:|---:|---:|---:|
| Prog 05 Sequential (16B lines) | N/A | N/A | N/A% | N/A% | N/A |
| Prog 05 Sequential (32B lines) | N/A | N/A | N/A% | N/A% | N/A |
| Prog 06 Stride-4 | N/A | N/A | N/A% | N/A% | N/A |
| Prog 06 Stride-8 | N/A | N/A | N/A% | N/A% | N/A |
| Prog 06 Stride-16 | N/A | N/A | N/A% | N/A% | N/A |
| Prog 07 (2-way) | N/A | N/A | N/A% | N/A% | N/A |
| Prog 07 (4-way) | N/A | N/A | N/A% | N/A% | N/A |
| Prog 08 (LRU) | N/A | N/A | N/A% | N/A% | N/A |
| Prog 08 (FIFO) | N/A | N/A | N/A% | N/A% | N/A |

## Program 09 Performance

| Scenario | Cycles | Stalls (est.) |
|---|---:|---:|
| Single-cycle | 1062 | N/A |
| 5-stage no fwd, hazard ON | 2776 | 1710 |
| 5-stage with forwarding | 1258 | 192 |

| Cache Config (forwarding ON) | Hits | Misses | Hit Rate |
|---|---:|---:|---:|
| No cache baseline | N/A | N/A | N/A% |
| 256B, 16B line, 2-way, LRU | N/A | N/A | N/A% |
| 256B, 32B line, 2-way, LRU | N/A | N/A | N/A% |
| 256B, 16B line, 4-way, LRU | N/A | N/A | N/A% |
| 256B, 16B line, 2-way, FIFO | N/A | N/A | N/A% |

## Analysis Answers

1. Program 01 and Program 02 both resolve RAW timing gaps, but Program 02 pays explicit NOP costs; compare stalls_est values.
2. Forwarding improvement over Program 02: 15.38%
3. Dot product section in Program 04 usually has highest hazards/instruction due to two loads feeding multiply + accumulator dependency.
4. Forwarding cannot bypass data before load MEM completes; minimum 1-cycle stall remains for load-use.
5. Pass 1: 25% (1 miss per 4 words). Combined 2-pass rate is typically 12.5% if cache retains working set.
6. Larger lines help sequential access via spatial locality, but large strides skip fetched words, so larger lines do not reduce misses much.
7. 4-way associativity is required to hold blocks A/B/C/D mapping to the same set without conflict evictions.
8. For A->B->A->C->A in 2-way set: LRU evicts B at C (A was recent) so final A hits; FIFO evicts A (oldest) so final A misses; LRU gains one hit.
9. Optimal: p09_pipeline_single (1062 cycles); Worst: p09_pipeline_5s_hzd (2776 cycles); Speedup: 2.61x
10. Transpose matrix B or reorder loops to access B row-major in inner loop; this improves spatial locality and cache hit rate.

## Notes

- If cache hit/miss fields are N/A, your Ripes CLI build may not expose cache stats in report output or cache flags were not supplied.
- Override processor IDs if auto-detection from --help does not match your Ripes build.
