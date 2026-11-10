# Local coding LLMs: capability levels and hardware sizing

For "can I run local models that actually help with coding on hardware X". Model landscape as of mid/late 2026 — names move fast, the VRAM math and levels are stable.

## The three levels of "helps with coding"

| Level | What it does | Min model class | Hardware |
|---|---|---|---|
| 1 — Fill-in-the-middle autocomplete | inline completion (Continue/Copilot style) | 7B-14B (qwen2.5-coder) | even CPU-only (7B ~5-10 tok/s, 14B ~3-6 tok/s on a Xeon W-2135 + DDR4-2666) |
| 2 — Code chat / refactor | explain, small refactors, single-file fixes | 14B-32B | 12-24 GB VRAM |
| 3 — Agentic coding | reads files, calls tools, multi-step tasks (Claude Code / Cursor replacement) | **qwen3-coder:30b** preferred; lighter agent models may fit below it | **24 GB VRAM for the preferred 30B class**; 16 GB can run selected lighter agents |

Only level 3 is a real coding-agent replacement; below it is assistance. Do not oversell CPU-only or 12 GB cards for the preferred 30B agentic workflow. Describe a 16 GB setup as a lighter compromise, not equivalent to 24 GB.

## Model → VRAM table (Q4_K_M approx)

| Model | Type | Size | Notes |
|---|---|---|---|
| qwen2.5-coder 7B / 14B | dense FIM | 5 / 9-10 GB | level 1 |
| gpt-oss:20b (OpenAI open weights) | instruct | ~16 GB | the only agent-ish model fitting 16 GB unified |
| devstral:24b (Mistral + All Hands) | agentic | ~14 GB | 46.8% SWE-Bench Verified; lightest real agent model |
| **qwen3-coder:30b** (MoE 30B/3.3B active) | agentic | ~19 GB | 256K ctx; the 2026 standard local coder; ~18 tok/s on a 3090; needs 24 GB (does NOT fit 16 GB cards) |
| qwen2.5-coder 32B | dense | 19-20 GB | prior-gen single-file workhorse |
| deepseek-r1 distill 32B | reasoning | ~20 GB | debug/reasoning |
| qwen3-coder:480b (MoE 35B active) | flagship | ~290 GB | multi-GPU/server only — not a desk machine |

Rule: size for model weights **plus KV cache and runtime overhead**. Keeping a 30B MoE fully in VRAM gives the predictable target; partial CPU offload can run but usually hurts prompt ingestion and agent latency. A 12 GB RTX 3060 does not hold the preferred 30B workflow. A 16 GB card can run selected lighter agentic models but leaves less context headroom. Prefer one 24 GB card over improvised 2x12 GB splitting.

## GPU tiers for the 24 GB target

| GPU | Verdict | Why |
|---|---|---|
| RTX 3060 12 GB | Autocomplete/chat tier | Efficient 7B/14B CUDA card; the preferred 30B Q4 weights do not fit |
| Tesla P40 24 GB | Budget experiment | 30B Q4 fits; optimized llama.cpp reports can reach usable MoE generation and ~10 tok/s on dense 32B, but long-prompt ingestion is the weak point |
| RTX 3090 24 GB | Durable level-3 choice | Tensor Cores, modern quant/runtime support, much faster prompt processing, normal active cooling |

### Tesla P40 integration rules

- Use GGUF through current llama.cpp/Ollama; do not select it for a vLLM-first stack because Pascal compute capability 6.1 is below vLLM's normal support floor and lacks modern attention kernels.
- Pin a compatible NVIDIA driver/CUDA 12.x-era userspace when needed; CUDA 13 removed Pascal compilation support, so future software friction is part of the purchase price.
- Budget for a fan shroud and high-static-pressure blower: P40 is passive and workstation airflow alone is not a safe assumption.
- Use the correct Tesla power adapter: its EPS-style 8-pin pinout is not interchangeable with ordinary PCIe GPU power. Verify the exact P520 PSU/cable path before energizing.
- P40 has no display output; retain a low-power display card or run headless.
- Buy target: ≤€180 including correct adapter/cooling; acceptable tested bundle ≤€220; skip above €250 and save for a 3090.

## CPU-only reality (no GPU, 64 GB RAM box)

Level 1 works. A dense 32B Q4 fits in RAM but is generally too slow on a 6-core Xeon W for daily agent loops. MoE results vary more; benchmark both prompt-processing and generation speed before calling a setup usable. GPU is the difference between a demo and a predictable daily driver.

## Wiring (all OpenAI-compatible)

```bash
ollama pull qwen3-coder:30b
# CRITICAL: default context is 2-4k tokens — useless for agents.
# Modelfile: PARAMETER num_ctx 32768   or   OLLAMA_CONTEXT_LENGTH=32768
```

- Ollama serves an OpenAI-compatible endpoint on :11434 — Continue (autocomplete), aider, Cline, and Codex CLI can all point at it.
- llama.cpp with tool-calling requires the `--jinja` flag or agentic tool calls silently fail.
- Macs: MLX path (LM Studio / Ollama MLX). 16 GB Macs cap at level 2; 32 GB unified ≈ 32 GB VRAM for these purposes (qwen3-coder:30b fits).
- Multiple concurrent agents later → vLLM instead of Ollama (needs NVIDIA/CUDA).
- Honest framing: even qwen3-coder:30b sits below Claude Sonnet/Opus + Claude Code for agentic quality. Local = privacy, no rate limits, no per-token cost — not a quality win.
