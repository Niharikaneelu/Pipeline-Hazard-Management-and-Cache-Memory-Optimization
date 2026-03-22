#!/usr/bin/env python3
"""
Automate Ripes CLI experiments for pipeline hazards and cache analysis.

This script runs the 9 assembly programs in this repository with a matrix of
processor/cache configurations, extracts metrics from Ripes output, computes
analysis values, and emits reports as JSON + Markdown.

Usage example:
  python ripes_cli_analyzer.py --ripes "C:/tools/Ripes.exe"

If your Ripes processor IDs differ, override with:
  --proc-single ... --proc-5s-base ... --proc-5s-hzd ... --proc-5s-fwd ...

If your Ripes build exposes cache CLI flags, pass them via:
  --cache-config-a-args "..."
  --cache-config-b-args "..."
  --cache-config-c-args "..."
  --cache-fifo-args "..."
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import statistics
import subprocess
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


@dataclass
class RunResult:
    name: str
    src: str
    proc: str
    args: List[str]
    returncode: int
    stdout: str
    stderr: str
    raw: Dict[str, Any]
    cycles: Optional[float]
    iret: Optional[float]
    cpi: Optional[float]
    ipc: Optional[float]
    cache_hits: Optional[float]
    cache_misses: Optional[float]


def run_command(cmd: List[str], cwd: Path) -> Tuple[int, str, str]:
    proc = subprocess.run(
        cmd,
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    return proc.returncode, proc.stdout, proc.stderr


def flatten_json(data: Any, prefix: str = "") -> Iterable[Tuple[str, Any]]:
    if isinstance(data, dict):
        for k, v in data.items():
            next_prefix = f"{prefix}.{k}" if prefix else str(k)
            yield from flatten_json(v, next_prefix)
    elif isinstance(data, list):
        for i, v in enumerate(data):
            next_prefix = f"{prefix}[{i}]"
            yield from flatten_json(v, next_prefix)
    else:
        yield prefix, data


def maybe_float(value: Any) -> Optional[float]:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        m = re.search(r"-?\d+(?:\.\d+)?", value)
        if m:
            return float(m.group(0))
    return None


def extract_metric(flat: List[Tuple[str, Any]], key_terms: List[str]) -> Optional[float]:
    key_terms = [k.lower() for k in key_terms]
    candidates: List[Tuple[int, float]] = []
    for key, value in flat:
        key_l = key.lower()
        if all(term in key_l for term in key_terms):
            val = maybe_float(value)
            if val is not None:
                score = sum(1 for t in key_terms if t in key_l)
                candidates.append((score, val))
    if not candidates:
        return None
    candidates.sort(key=lambda x: x[0], reverse=True)
    return candidates[0][1]


def parse_text_metric(text: str, patterns: List[str]) -> Optional[float]:
    for pat in patterns:
        m = re.search(pat, text, flags=re.IGNORECASE | re.MULTILINE)
        if m:
            try:
                return float(m.group(1))
            except ValueError:
                continue
    return None


def extract_known_metrics(raw: Dict[str, Any], text: str) -> Dict[str, Optional[float]]:
    flat = list(flatten_json(raw)) if raw else []

    cycles = extract_metric(flat, ["cycles"])
    iret = extract_metric(flat, ["iret"])
    if iret is None:
        iret = extract_metric(flat, ["instruction", "ret"])

    cpi = extract_metric(flat, ["cpi"])
    ipc = extract_metric(flat, ["ipc"])

    hits = extract_metric(flat, ["hit"])
    misses = extract_metric(flat, ["miss"])

    if cycles is None:
        cycles = parse_text_metric(
            text,
            [
                r"cycles\s*[:=]\s*(\d+(?:\.\d+)?)",
                r"report\s+cycles\s*[:=]\s*(\d+(?:\.\d+)?)",
            ],
        )
    if iret is None:
        iret = parse_text_metric(
            text,
            [r"iret\s*[:=]\s*(\d+(?:\.\d+)?)", r"instructions?\s+retired\s*[:=]\s*(\d+(?:\.\d+)?)"],
        )
    if cpi is None:
        cpi = parse_text_metric(text, [r"cpi\s*[:=]\s*(\d+(?:\.\d+)?)"])
    if ipc is None:
        ipc = parse_text_metric(text, [r"ipc\s*[:=]\s*(\d+(?:\.\d+)?)"])
    if hits is None:
        hits = parse_text_metric(text, [r"hits?\s*[:=]\s*(\d+(?:\.\d+)?)"])
    if misses is None:
        misses = parse_text_metric(text, [r"misses?\s*[:=]\s*(\d+(?:\.\d+)?)"])

    return {
        "cycles": cycles,
        "iret": iret,
        "cpi": cpi,
        "ipc": ipc,
        "cache_hits": hits,
        "cache_misses": misses,
    }


def parse_processor_ids_from_help(help_text: str) -> List[str]:
    ids = set()
    for m in re.finditer(r"\bRV\d+_[A-Za-z0-9_]+\b", help_text):
        ids.add(m.group(0))
    for m in re.finditer(r"\{([^{}]+)\}", help_text):
        for token in m.group(1).split(","):
            token = token.strip().strip('"\'')
            if re.match(r"^RV\d+_[A-Za-z0-9_]+$", token):
                ids.add(token)
    return sorted(ids)


def pick_proc(candidates: List[str], includes: List[str], excludes: Optional[List[str]] = None) -> Optional[str]:
    excludes = excludes or []
    for c in candidates:
        u = c.upper()
        if all(x.upper() in u for x in includes) and not any(e.upper() in u for e in excludes):
            return c
    return None


def detect_procs(ripes: Path, cwd: Path) -> Dict[str, str]:
    rc, out, err = run_command([str(ripes), "--help"], cwd)
    text = f"{out}\n{err}" if rc == 0 else ""
    procs = parse_processor_ids_from_help(text)

    # Prefer RV32 models and match common Ripes naming:
    # RV32_5S_NO_FW_HZ: no forwarding, no hazard detection
    # RV32_5S_NO_FW:    no forwarding, hazard detection enabled
    # RV32_5S:          forwarding + hazard detection enabled
    detected = {
        "single": (
            "RV32_SS"
            if "RV32_SS" in procs
            else pick_proc(procs, ["RV32", "SS"]) or "RV32_SS"
        ),
        "five_base": (
            "RV32_5S_NO_FW_HZ"
            if "RV32_5S_NO_FW_HZ" in procs
            else pick_proc(procs, ["RV32", "5S", "NO_FW", "HZ"]) or "RV32_5S_NO_FW_HZ"
        ),
        "five_hzd": (
            "RV32_5S_NO_FW"
            if "RV32_5S_NO_FW" in procs
            else pick_proc(procs, ["RV32", "5S", "NO_FW"], ["NO_FW_HZ"]) or "RV32_5S_NO_FW"
        ),
        "five_fwd": (
            "RV32_5S"
            if "RV32_5S" in procs
            else pick_proc(procs, ["RV32", "5S"], ["NO_FW", "NO_HZ"]) or "RV32_5S"
        ),
    }
    return detected


def format_pct(numer: Optional[float], denom: Optional[float]) -> Optional[float]:
    if numer is None or denom is None or denom == 0:
        return None
    return (numer / denom) * 100.0


def estimated_stalls(cycles: Optional[float], iret: Optional[float], pipelined: bool) -> Optional[float]:
    if cycles is None or iret is None or not pipelined:
        return None
    # 5-stage pipeline fill/drain overhead is roughly 4 cycles.
    return max(cycles - iret - 4.0, 0.0)


def to_str(v: Optional[float], digits: int = 2) -> str:
    if v is None:
        return "N/A"
    if abs(v - round(v)) < 1e-9:
        return str(int(round(v)))
    return f"{v:.{digits}f}"


def build_stride_variants(src: Path, out_dir: Path) -> Dict[str, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    text = src.read_text(encoding="utf-8")
    lines = text.splitlines()

    loop_labels = ["stride4_loop", "stride8_loop", "stride16_loop"]
    label_to_index: Dict[str, int] = {}
    for i, line in enumerate(lines):
        m = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*$", line)
        if m and m.group(1) in loop_labels:
            label_to_index[m.group(1)] = i

    if len(label_to_index) != 3:
        raise RuntimeError("Could not identify all stride loop labels in Program 06.")

    sorted_labels = sorted(loop_labels, key=lambda k: label_to_index[k])

    variants: Dict[str, Path] = {}
    for keep_label in sorted_labels:
        variant_lines = lines[:]
        for idx, label in enumerate(sorted_labels):
            start = label_to_index[label]
            end = label_to_index[sorted_labels[idx + 1]] if idx + 1 < len(sorted_labels) else len(lines)
            if label == keep_label:
                continue
            for j in range(start, end):
                if re.search(r"\blw\s+x16\s*,\s*0\(x15\)", variant_lines[j]):
                    indent = re.match(r"^(\s*)", variant_lines[j]).group(1)
                    variant_lines[j] = f"{indent}addi x16, x0, 0     # patched: disable cache access in non-target stride loop"

        out_path = out_dir / f"06_cache_strided_{keep_label}.s"
        out_path.write_text("\n".join(variant_lines) + "\n", encoding="utf-8")
        m = re.match(r"^stride(\d+)_loop$", keep_label)
        if not m:
            raise RuntimeError(f"Unexpected stride loop label: {keep_label}")
        stride_name = m.group(1)
        variants[stride_name] = out_path

    return variants


def sanitize_space_directives(src: Path, out_path: Path) -> Path:
    """Rewrite '.space N' into explicit data directives for assemblers without .space."""
    text = src.read_text(encoding="utf-8")
    out_lines: List[str] = []

    for line in text.splitlines():
        m = re.match(r"^(\s*)\.space\s+(\d+)\s*(?:#.*)?$", line)
        if not m:
            out_lines.append(line)
            continue

        indent = m.group(1)
        nbytes = int(m.group(2))
        out_lines.append(f"{indent}# patched: expanded .space {nbytes}")

        nwords = nbytes // 4
        rem = nbytes % 4
        if nwords:
            zeros = ", ".join(["0"] * nwords)
            out_lines.append(f"{indent}.word {zeros}")
        if rem:
            zeros_b = ", ".join(["0"] * rem)
            out_lines.append(f"{indent}.byte {zeros_b}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    return out_path


def run_ripes_once(
    ripes: Path,
    cwd: Path,
    src: Path,
    proc: str,
    isaexts: str,
    timeout_ms: int,
    extra_args: List[str],
    name: str,
    out_dir: Path,
) -> RunResult:
    out_json = out_dir / f"{name}.json"

    cmd = [
        str(ripes),
        "--mode",
        "cli",
        "--src",
        str(src),
        "-t",
        "asm",
        "--proc",
        proc,
        "--isaexts",
        isaexts,
        "--timeout",
        str(timeout_ms),
        "--json",
        "--all",
        "--output",
        str(out_json),
    ]
    cmd.extend(extra_args)

    rc, stdout, stderr = run_command(cmd, cwd)

    # Ripes may print an ERROR message but still return code 0.
    combined = f"{stdout}\n{stderr}"
    if rc == 0 and re.search(r"\bERROR\b", combined, flags=re.IGNORECASE):
        rc = 1

    raw: Dict[str, Any] = {}
    if out_json.exists():
        try:
            raw = json.loads(out_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            raw = {}

    metrics = extract_known_metrics(raw, combined)

    return RunResult(
        name=name,
        src=str(src),
        proc=proc,
        args=extra_args,
        returncode=rc,
        stdout=stdout,
        stderr=stderr,
        raw=raw,
        cycles=metrics["cycles"],
        iret=metrics["iret"],
        cpi=metrics["cpi"],
        ipc=metrics["ipc"],
        cache_hits=metrics["cache_hits"],
        cache_misses=metrics["cache_misses"],
    )


def compute_analysis(results: Dict[str, RunResult]) -> Dict[str, Any]:
    def rr(name: str) -> Optional[RunResult]:
        return results.get(name)

    def hit_rate(run: Optional[RunResult]) -> Optional[float]:
        if not run:
            return None
        if run.cache_hits is None or run.cache_misses is None:
            return None
        total = run.cache_hits + run.cache_misses
        return None if total == 0 else 100.0 * run.cache_hits / total

    def miss_rate_frac(run: Optional[RunResult]) -> Optional[float]:
        if not run:
            return None
        if run.cache_hits is None or run.cache_misses is None:
            return None
        total = run.cache_hits + run.cache_misses
        return None if total == 0 else run.cache_misses / total

    def amat(run: Optional[RunResult], hit_time: float = 1.0, miss_penalty: float = 10.0) -> Optional[float]:
        mr = miss_rate_frac(run)
        return None if mr is None else hit_time + mr * miss_penalty

    p02 = rr("p02_nop_stalling")
    p03 = rr("p03_forwarding")
    p04_off = rr("p04_forwarding_off")
    p04_on = rr("p04_forwarding_on")

    p09_runs = [
        rr("p09_pipeline_single"),
        rr("p09_pipeline_5s_hzd"),
        rr("p09_pipeline_5s_fwd"),
        rr("p09_cache_baseline"),
        rr("p09_cache_cfg_a"),
        rr("p09_cache_cfg_b"),
        rr("p09_cache_cfg_c"),
        rr("p09_cache_fifo"),
    ]
    p09_cycles = [(r.name, r.cycles) for r in p09_runs if r and r.cycles is not None]

    best = min(p09_cycles, key=lambda x: x[1]) if p09_cycles else None
    worst = max(p09_cycles, key=lambda x: x[1]) if p09_cycles else None
    speedup = None
    if best and worst and best[1] and worst[1] and best[1] > 0:
        speedup = worst[1] / best[1]

    analysis: Dict[str, Any] = {
        "pipeline_efficiency": {},
        "cache_performance": {},
        "question_answers": {},
        "p09_best": best,
        "p09_worst": worst,
        "p09_speedup": speedup,
    }

    for key, pipelined in [
        ("p01_no_handling", True),
        ("p02_nop_stalling", True),
        ("p03_forwarding", True),
        ("p04_forwarding_off", True),
        ("p04_forwarding_on", True),
    ]:
        run = rr(key)
        if not run:
            continue
        eff = None if run.cycles is None or run.iret is None or run.cycles == 0 else run.iret / run.cycles
        analysis["pipeline_efficiency"][key] = {
            "cycles": run.cycles,
            "instructions": run.iret,
            "efficiency": eff,
            "stalls_est": estimated_stalls(run.cycles, run.iret, pipelined),
        }

    for key in [
        "p05_cfg_a",
        "p05_cfg_b",
        "p06_stride4",
        "p06_stride8",
        "p06_stride16",
        "p07_cfg_a_2way",
        "p07_cfg_c_4way",
        "p08_lru",
        "p08_fifo",
    ]:
        run = rr(key)
        if not run:
            continue
        analysis["cache_performance"][key] = {
            "hits": run.cache_hits,
            "misses": run.cache_misses,
            "hit_rate_pct": hit_rate(run),
            "miss_rate_pct": None if hit_rate(run) is None else 100.0 - hit_rate(run),
            "amat": amat(run),
        }

    fwd_improvement = None
    if p02 and p03 and p02.cycles and p03.cycles and p02.cycles != 0:
        fwd_improvement = 100.0 * (p02.cycles - p03.cycles) / p02.cycles

    analysis["question_answers"] = {
        "q1": "Program 01 and Program 02 both resolve RAW timing gaps, but Program 02 pays explicit NOP costs; compare stalls_est values.",
        "q2_forwarding_improvement_pct": fwd_improvement,
        "q3_most_hazards_section": "Dot product section in Program 04 usually has highest hazards/instruction due to two loads feeding multiply + accumulator dependency.",
        "q4_load_use_min_stall": "Forwarding cannot bypass data before load MEM completes; minimum 1-cycle stall remains for load-use.",
        "q5_theoretical_prog05_16b_miss_rate": "Pass 1: 25% (1 miss per 4 words). Combined 2-pass rate is typically 12.5% if cache retains working set.",
        "q6_line_size_vs_stride": "Larger lines help sequential access via spatial locality, but large strides skip fetched words, so larger lines do not reduce misses much.",
        "q7_min_associativity_prog07": "4-way associativity is required to hold blocks A/B/C/D mapping to the same set without conflict evictions.",
        "q8_lru_vs_fifo_proof": "For A->B->A->C->A in 2-way set: LRU evicts B at C (A was recent) so final A hits; FIFO evicts A (oldest) so final A misses; LRU gains one hit.",
        "q9_optimal": best,
        "q9_worst": worst,
        "q9_speedup": speedup,
        "q10_one_code_change": "Transpose matrix B or reorder loops to access B row-major in inner loop; this improves spatial locality and cache hit rate.",
    }

    # Add a compact consistency check for Program 04 trend.
    if p04_off and p04_on and p04_off.cycles and p04_on.cycles:
        analysis["question_answers"]["p04_forwarding_cycle_delta"] = p04_off.cycles - p04_on.cycles

    return analysis


def make_markdown(results: Dict[str, RunResult], analysis: Dict[str, Any]) -> str:
    def r(name: str) -> Optional[RunResult]:
        return results.get(name)

    lines: List[str] = []
    lines.append("# Ripes CLI Automated Report")
    lines.append("")
    lines.append("## Run Summary")
    lines.append("")
    lines.append("| Run | RC | Cycles | IRet | CPI | IPC | Hits | Misses |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|")
    for name in sorted(results.keys()):
        rr = results[name]
        lines.append(
            f"| {name} | {rr.returncode} | {to_str(rr.cycles)} | {to_str(rr.iret)} | {to_str(rr.cpi)} | {to_str(rr.ipc)} | {to_str(rr.cache_hits)} | {to_str(rr.cache_misses)} |"
        )

    lines.append("")
    lines.append("## Pipeline Efficiency (Programs 01-04)")
    lines.append("")
    lines.append("| Program | Cycles | Instructions | Efficiency | Stalls (est.) |")
    lines.append("|---|---:|---:|---:|---:|")

    mapping = [
        ("p01_no_handling", "Program 01"),
        ("p02_nop_stalling", "Program 02"),
        ("p03_forwarding", "Program 03"),
        ("p04_forwarding_off", "Program 04 fwd OFF"),
        ("p04_forwarding_on", "Program 04 fwd ON"),
    ]
    pe = analysis.get("pipeline_efficiency", {})
    for key, label in mapping:
        row = pe.get(key, {})
        lines.append(
            f"| {label} | {to_str(row.get('cycles'))} | {to_str(row.get('instructions'))} | {to_str(row.get('efficiency') * 100 if row.get('efficiency') is not None else None)}% | {to_str(row.get('stalls_est'))} |"
        )

    lines.append("")
    lines.append("## Cache Performance (Programs 05-08)")
    lines.append("")
    lines.append("| Case | Hits | Misses | Hit Rate | Miss Rate | AMAT |")
    lines.append("|---|---:|---:|---:|---:|---:|")
    cp = analysis.get("cache_performance", {})
    cache_rows = [
        ("p05_cfg_a", "Prog 05 Sequential (16B lines)"),
        ("p05_cfg_b", "Prog 05 Sequential (32B lines)"),
        ("p06_stride4", "Prog 06 Stride-4"),
        ("p06_stride8", "Prog 06 Stride-8"),
        ("p06_stride16", "Prog 06 Stride-16"),
        ("p07_cfg_a_2way", "Prog 07 (2-way)"),
        ("p07_cfg_c_4way", "Prog 07 (4-way)"),
        ("p08_lru", "Prog 08 (LRU)"),
        ("p08_fifo", "Prog 08 (FIFO)"),
    ]
    for key, label in cache_rows:
        row = cp.get(key, {})
        lines.append(
            f"| {label} | {to_str(row.get('hits'))} | {to_str(row.get('misses'))} | {to_str(row.get('hit_rate_pct'))}% | {to_str(row.get('miss_rate_pct'))}% | {to_str(row.get('amat'))} |"
        )

    lines.append("")
    lines.append("## Program 09 Performance")
    lines.append("")
    lines.append("| Scenario | Cycles | Stalls (est.) |")
    lines.append("|---|---:|---:|")
    for key, label, pipelined in [
        ("p09_pipeline_single", "Single-cycle", False),
        ("p09_pipeline_5s_hzd", "5-stage no fwd, hazard ON", True),
        ("p09_pipeline_5s_fwd", "5-stage with forwarding", True),
    ]:
        rr = r(key)
        lines.append(
            f"| {label} | {to_str(rr.cycles if rr else None)} | {to_str(estimated_stalls(rr.cycles, rr.iret, pipelined) if rr else None)} |"
        )

    lines.append("")
    lines.append("| Cache Config (forwarding ON) | Hits | Misses | Hit Rate |")
    lines.append("|---|---:|---:|---:|")
    for key, label in [
        ("p09_cache_baseline", "No cache baseline"),
        ("p09_cache_cfg_a", "256B, 16B line, 2-way, LRU"),
        ("p09_cache_cfg_b", "256B, 32B line, 2-way, LRU"),
        ("p09_cache_cfg_c", "256B, 16B line, 4-way, LRU"),
        ("p09_cache_fifo", "256B, 16B line, 2-way, FIFO"),
    ]:
        rr = r(key)
        h = rr.cache_hits if rr else None
        m = rr.cache_misses if rr else None
        hr = None
        if h is not None and m is not None and h + m != 0:
            hr = 100.0 * h / (h + m)
        lines.append(f"| {label} | {to_str(h)} | {to_str(m)} | {to_str(hr)}% |")

    qa = analysis.get("question_answers", {})
    lines.append("")
    lines.append("## Analysis Answers")
    lines.append("")
    lines.append(f"1. {qa.get('q1', 'N/A')}")
    lines.append(f"2. Forwarding improvement over Program 02: {to_str(qa.get('q2_forwarding_improvement_pct'))}%")
    lines.append(f"3. {qa.get('q3_most_hazards_section', 'N/A')}")
    lines.append(f"4. {qa.get('q4_load_use_min_stall', 'N/A')}")
    lines.append(f"5. {qa.get('q5_theoretical_prog05_16b_miss_rate', 'N/A')}")
    lines.append(f"6. {qa.get('q6_line_size_vs_stride', 'N/A')}")
    lines.append(f"7. {qa.get('q7_min_associativity_prog07', 'N/A')}")
    lines.append(f"8. {qa.get('q8_lru_vs_fifo_proof', 'N/A')}")

    q9_opt = qa.get("q9_optimal")
    q9_worst = qa.get("q9_worst")
    lines.append(
        f"9. Optimal: {q9_opt[0] if q9_opt else 'N/A'} ({to_str(q9_opt[1] if q9_opt else None)} cycles); "
        f"Worst: {q9_worst[0] if q9_worst else 'N/A'} ({to_str(q9_worst[1] if q9_worst else None)} cycles); "
        f"Speedup: {to_str(qa.get('q9_speedup'))}x"
    )
    lines.append(f"10. {qa.get('q10_one_code_change', 'N/A')}")

    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- If cache hit/miss fields are N/A, your Ripes CLI build may not expose cache stats in report output or cache flags were not supplied.")
    lines.append("- Override processor IDs if auto-detection from --help does not match your Ripes build.")

    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Ripes CLI experiments and compute analysis tables.")
    parser.add_argument("--ripes", required=True, help="Path to Ripes executable")
    parser.add_argument("--workspace", default=".", help="Workspace/project root containing .s files")
    parser.add_argument("--out-dir", default="analysis_out", help="Output directory for reports")
    parser.add_argument("--isaexts", default="M", help="ISA extensions, comma-separated (default: M)")
    parser.add_argument("--timeout-ms", type=int, default=120000, help="Ripes simulation timeout in ms")

    parser.add_argument("--proc-single", default=None, help="Processor ID for single-cycle")
    parser.add_argument("--proc-5s-base", default=None, help="Processor ID for 5-stage no fwd/no hazard")
    parser.add_argument("--proc-5s-hzd", default=None, help="Processor ID for 5-stage hazard detection")
    parser.add_argument("--proc-5s-fwd", default=None, help="Processor ID for 5-stage forwarding")

    parser.add_argument("--cache-config-a-args", default="", help="Extra CLI args for Cache Config A")
    parser.add_argument("--cache-config-b-args", default="", help="Extra CLI args for Cache Config B")
    parser.add_argument("--cache-config-c-args", default="", help="Extra CLI args for Cache Config C")
    parser.add_argument("--cache-fifo-args", default="", help="Extra CLI args for FIFO policy config")

    args = parser.parse_args()

    workspace = Path(args.workspace).resolve()
    ripes = Path(args.ripes).resolve()
    out_dir = (workspace / args.out_dir).resolve()
    runs_dir = out_dir / "runs"
    tmp_src_dir = out_dir / "tmp_sources"
    out_dir.mkdir(parents=True, exist_ok=True)
    runs_dir.mkdir(parents=True, exist_ok=True)

    if not ripes.exists():
        print(f"ERROR: Ripes executable not found: {ripes}", file=sys.stderr)
        return 2

    detected = detect_procs(ripes, workspace)
    proc_single = args.proc_single or detected["single"]
    proc_5s_base = args.proc_5s_base or detected["five_base"]
    proc_5s_hzd = args.proc_5s_hzd or detected["five_hzd"]
    proc_5s_fwd = args.proc_5s_fwd or detected["five_fwd"]

    proc_map = {
        "single": proc_single,
        "five_base": proc_5s_base,
        "five_hzd": proc_5s_hzd,
        "five_fwd": proc_5s_fwd,
    }

    for k, v in proc_map.items():
        if not v:
            print(f"ERROR: Missing processor ID for {k}.", file=sys.stderr)
            return 2

    src = {
        "p01": workspace / "01_raw_hazard_no_handling.s",
        "p02": workspace / "02_hazard_stalling_nops.s",
        "p03": workspace / "03_hazard_forwarding.s",
        "p04": workspace / "04_complex_hazards.s",
        "p05": workspace / "05_cache_sequential.s",
        "p06": workspace / "06_cache_strided.s",
        "p07": workspace / "07_cache_set_associative.s",
        "p08": workspace / "08_cache_replacement.s",
        "p09": workspace / "09_performance_benchmark.s",
    }

    missing = [str(p) for p in src.values() if not p.exists()]
    if missing:
        print("ERROR: Missing source files:", file=sys.stderr)
        for m in missing:
            print(f"  - {m}", file=sys.stderr)
        return 2

    stride_variants = build_stride_variants(src["p06"], tmp_src_dir)
    p07_sanitized = sanitize_space_directives(src["p07"], tmp_src_dir / "07_cache_set_associative_sanitized.s")
    p08_sanitized = sanitize_space_directives(src["p08"], tmp_src_dir / "08_cache_replacement_sanitized.s")

    cfg_a = shlex.split(args.cache_config_a_args)
    cfg_b = shlex.split(args.cache_config_b_args)
    cfg_c = shlex.split(args.cache_config_c_args)
    cfg_fifo = shlex.split(args.cache_fifo_args)

    plan: List[Tuple[str, Path, str, List[str]]] = [
        # Program 01-04 pipeline hazard analysis
        ("p01_no_handling", src["p01"], proc_map["five_base"], []),
        ("p01_with_hazard_detection", src["p01"], proc_map["five_hzd"], []),
        ("p02_nop_stalling", src["p02"], proc_map["five_base"], []),
        ("p03_forwarding", src["p03"], proc_map["five_fwd"], []),
        ("p04_forwarding_off", src["p04"], proc_map["five_hzd"], []),
        ("p04_forwarding_on", src["p04"], proc_map["five_fwd"], []),

        # Program 05-08 cache analysis
        ("p05_cfg_a", src["p05"], proc_map["five_fwd"], cfg_a),
        ("p05_cfg_b", src["p05"], proc_map["five_fwd"], cfg_b),
        ("p06_stride4", stride_variants["4"], proc_map["five_fwd"], cfg_a),
        ("p06_stride8", stride_variants["8"], proc_map["five_fwd"], cfg_a),
        ("p06_stride16", stride_variants["16"], proc_map["five_fwd"], cfg_a),
        ("p07_cfg_a_2way", p07_sanitized, proc_map["five_fwd"], cfg_a),
        ("p07_cfg_c_4way", p07_sanitized, proc_map["five_fwd"], cfg_c),
        ("p08_lru", p08_sanitized, proc_map["five_fwd"], cfg_a),
        ("p08_fifo", p08_sanitized, proc_map["five_fwd"], cfg_fifo),

        # Program 09 benchmark
        ("p09_pipeline_single", src["p09"], proc_map["single"], []),
        ("p09_pipeline_5s_hzd", src["p09"], proc_map["five_hzd"], []),
        ("p09_pipeline_5s_fwd", src["p09"], proc_map["five_fwd"], []),
        ("p09_cache_baseline", src["p09"], proc_map["five_fwd"], []),
        ("p09_cache_cfg_a", src["p09"], proc_map["five_fwd"], cfg_a),
        ("p09_cache_cfg_b", src["p09"], proc_map["five_fwd"], cfg_b),
        ("p09_cache_cfg_c", src["p09"], proc_map["five_fwd"], cfg_c),
        ("p09_cache_fifo", src["p09"], proc_map["five_fwd"], cfg_fifo),
    ]

    results: Dict[str, RunResult] = {}
    failures: List[str] = []

    for idx, (name, src_path, proc, extra) in enumerate(plan, start=1):
        print(f"[{idx}/{len(plan)}] Running {name} | proc={proc} | src={src_path.name}")
        rr = run_ripes_once(
            ripes=ripes,
            cwd=workspace,
            src=src_path,
            proc=proc,
            isaexts=args.isaexts,
            timeout_ms=args.timeout_ms,
            extra_args=extra,
            name=name,
            out_dir=runs_dir,
        )
        results[name] = rr
        if rr.returncode != 0:
            failures.append(name)
            print(f"  WARN: non-zero exit code for {name}: {rr.returncode}")

    analysis = compute_analysis(results)

    results_json = {
        "meta": {
            "workspace": str(workspace),
            "ripes": str(ripes),
            "proc_map": proc_map,
            "cache_args": {
                "cfg_a": cfg_a,
                "cfg_b": cfg_b,
                "cfg_c": cfg_c,
                "fifo": cfg_fifo,
            },
            "failures": failures,
        },
        "runs": {k: asdict(v) for k, v in results.items()},
        "analysis": analysis,
    }

    json_path = out_dir / "analysis_report.json"
    md_path = out_dir / "analysis_report.md"

    json_path.write_text(json.dumps(results_json, indent=2), encoding="utf-8")
    md_path.write_text(make_markdown(results, analysis), encoding="utf-8")

    print("\nDone.")
    print(f"Report JSON: {json_path}")
    print(f"Report MD:   {md_path}")
    if failures:
        print(f"Runs with non-zero exit code: {', '.join(failures)}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
