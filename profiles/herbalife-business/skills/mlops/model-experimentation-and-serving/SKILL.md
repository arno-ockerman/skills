---
name: model-experimentation-and-serving
description: "Run the model lifecycle end-to-end: discover assets, iterate in notebooks, benchmark, track experiments, serve locally, and verify inference systems."
version: 1.0.0
author: Hermes Curator
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [mlops, llm, benchmarking, serving, notebooks, experiments, inference, huggingface, vllm, llama-cpp, wandb]
    related_skills: [huggingface-hub, jupyter-live-kernel, evaluating-llms-harness, weights-and-biases, llama-cpp, serving-llms-vllm]
---

# Model Experimentation and Serving

Use this umbrella when the task is part of the **same model-development lifecycle**: find assets, inspect them, run experiments, benchmark variants, track runs, or expose inference behind a usable interface.

This is intentionally broader than any one framework. The maintainer-facing class is the workflow, not the individual package name.

## When to use

Choose this skill for:
- discovering or downloading model artifacts
- fast notebook-style experimentation
- evaluating models with reproducible benchmarks
- tracking runs, artifacts, or sweeps
- deciding between local inference backends
- standing up or validating serving endpoints

## Lifecycle map

1. **Acquire / inspect assets** → Hugging Face Hub mode
2. **Iterate quickly on ideas** → Jupyter live kernel mode
3. **Benchmark behavior** → evaluation harness mode
4. **Track metrics and artifacts** → Weights & Biases mode
5. **Run local single-node inference** → llama.cpp mode
6. **Run high-throughput OpenAI-compatible serving** → vLLM mode

## Shared rules

- start from the exact model identifier, quantization, and hardware constraints
- keep benchmark/eval settings explicit so results are comparable
- verify the serving or inference surface with a real request before calling it done
- prefer workflows that leave behind reusable commands, configs, or notebooks

## Mode: Hugging Face Hub

Use for discovering repositories, resolving files, downloading checkpoints, and publishing assets.

Carry forward:
- treat repo/file resolution as a first-class step, not an afterthought
- verify artifact names and variants explicitly
- preserve provenance: repo, revision, file names, and token requirements

## Mode: Jupyter live kernel

Use for tight experiment loops where stateful Python iteration beats one-shot scripts.

Carry forward:
- prefer a live kernel when the task needs inspection, iteration, and re-use of intermediate state
- keep code cells composable so results can later graduate into scripts or notebooks
- use it to reduce friction, not to hide unreproducible manual steps

## Mode: Evaluation harness

Use for benchmark suites such as MMLU, GSM8K, and other lm-eval-harness tasks.

Carry forward:
- make task lists, few-shot settings, and backend choices explicit
- separate benchmark orchestration from subjective interpretation
- report metrics with enough context to reproduce the run

## Mode: Weights & Biases

Use for run logging, artifacts, dashboards, and sweeps.

Carry forward:
- define project/run naming clearly
- log configs and artifacts alongside metrics
- use W&B to preserve experiment lineage, not just charts

## Mode: llama.cpp

Use for lightweight local inference on GGUF models, especially when quantization choice and CPU/GPU portability matter.

Carry forward:
- choose quantizations deliberately against hardware and quality targets
- verify actual generation behavior, not just successful model load
- preserve the exact model file and launch command used

## Mode: vLLM

Use for higher-throughput serving, OpenAI-compatible APIs, and cases where batching/throughput are central.

Carry forward:
- treat startup flags, tensor parallel settings, and model format compatibility as part of the deliverable
- verify the endpoint with a real completion/chat request
- prefer operational clarity over cargo-cult server launches

## What changed in this umbrella

These narrower siblings are now represented here as labeled lifecycle stages instead of separate top-level discovery targets:
- `huggingface-hub`
- `jupyter-live-kernel`
- `evaluating-llms-harness`
- `weights-and-biases`
- `llama-cpp`
- `serving-llms-vllm`

Keep separate skills only when the task class is fundamentally different from the rest of the model lifecycle.
