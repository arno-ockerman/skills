---
name: mlops-workflow
description: "Complete MLOps toolkit: local GGUF inference (llama.cpp), high-throughput serving (vLLM), model benchmarking (lm-eval-harness), HF Hub operations, experiment tracking (W&B), declarative LM programs (DSPy), abliteration, SAM segmentation, AudioCraft generation. Use for any ML model lifecycle task — inference, evaluation, serving, tracking, or model surgery."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [llama.cpp, GGUF, vLLM, lm-eval, HuggingFace, W&B, DSPy, abliteration, SAM, AudioCraft, MLOps, inference, evaluation, serving]
    related_skills: [coding-agents, jupyter-live-kernel, visual-creative]
---

# MLOps Workflow — Complete Toolkit

Covers the full ML model lifecycle: local inference, serving, evaluation, tracking, model hub ops, and model surgery.

---

## Quick Selection Guide

| Task | Tool | Subsection |
|------|------|------------|
| Local CPU/Apple Silicon/GPU inference with GGUF | llama.cpp | **1. llama.cpp (Local Inference)** |
| High-throughput OpenAI-compatible serving | vLLM | **2. vLLM (Serving)** |
| Benchmark models (MMLU, GSM8K, etc.) | lm-eval-harness | **3. lm-eval-harness (Benchmarking)** |
| Search/download/upload models & datasets | HuggingFace Hub | **4. HuggingFace Hub** |
| Log experiments, sweeps, model registry | Weights & Biases | **5. Weights & Biases (Tracking)** |
| Declarative LM programs, auto-optimize prompts, RAG | DSPy | **6. DSPy (LM Programs)** |
| Remove refusals from models (diff-in-means) | OBLITERATUS | **7. OBLITERATUS (Abliteration)** |
| Zero-shot image segmentation | Segment Anything (SAM) | **8. SAM (Segmentation)** |
| Text-to-music (MusicGen), text-to-sound (AudioGen) | AudioCraft | **9. AudioCraft (Audio Generation)** |

---

## 1. llama.cpp (Local GGUF Inference)

### Install
```bash
brew install llama.cpp          # macOS
winget install llama.cpp        # Windows
# Or build from source for CUDA/Metal/ROCm
```

### URL-First Discovery (Recommended)
1. Search: `https://huggingface.co/models?apps=llama.cpp&sort=trending`
2. Filter: `search=<term>`, `num_parameters=min:0,max:24B`
3. View local-app page: `https://huggingface.co/<repo>?local-app=llama.cpp`
4. Copy exact `llama-server`/`llama-cli` command from HF page
5. Verify via tree API: `https://huggingface.co/api/models/<repo>/tree/main?recursive=true`

### Run
```bash
# Direct from HF Hub (shorthand)
llama-cli -hf bartowski/Llama-3.2-3B-Instruct-GGUF:Q8_0
llama-server -hf bartowski/Llama-3.2-3B-Instruct-GGUF:Q8_0

# Exact file (when tree API shows custom naming)
llama-server --hf-repo microsoft/Phi-3-mini-4k-instruct-gguf \
    --hf-file Phi-3-mini-4k-instruct-q4.gguf -c 4096
```

### Python (llama-cpp-python)
```python
from llama_cpp import Llama

llm = Llama(
    model_path="./model-q4_k_m.gguf",
    n_ctx=4096,
    n_gpu_layers=35,  # 0=CPU, 99=all
    n_threads=8,
)

# Streaming
for chunk in llm("Explain quantum computing:", max_tokens=256, stream=True):
    print(chunk["choices"][0]["text"], end="", flush=True)

# From HF Hub directly
llm = Llama.from_pretrained(
    repo_id="bartowski/Llama-3.2-3B-Instruct-GGUF",
    filename="*Q4_K_M.gguf",
    n_gpu_layers=35,
)
```

### Quant Selection
- Start with `Q4_K_M` for general chat
- Code/tech: `Q5_K_M` or `Q6_K` if memory allows
- Tight RAM: `Q3_K_M`, `IQ` variants
- Respect HF page labels (e.g., `UD-Q4_K_M`, `IQ4_NL_XL`) — don't normalize

---

## 2. vLLM (High-Throughput Serving)

### Install
```bash
pip install vllm
# CUDA: pip install vllm --extra-index-url https://download.pytorch.org/whl/cu121
```

### OpenAI-Compatible Server
```bash
vllm serve meta-llama/Llama-3.1-8B-Instruct \
    --tensor-parallel-size 2 \
    --max-model-len 8192 \
    --gpu-memory-utilization 0.9

# Test
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "meta-llama/Llama-3.1-8B-Instruct", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Key Flags
| Flag | Purpose |
|------|---------|
| `--tensor-parallel-size N` | Multi-GPU sharding |
| `--max-model-len N` | Context window |
| `--gpu-memory-utilization 0.9` | VRAM budget |
| `--quantization awq/gptq` | Quantized models |
| `--dtype half/bfloat16` | Precision |

### Python Client
```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8000/v1", api_key="none")
client.chat.completions.create(model="meta-llama/Llama-3.1-8B-Instruct", messages=[...])
```

---

## 3. lm-eval-harness (Benchmarking)

### Install
```bash
pip install lm-eval
# Or: pip install -e ".[dev]" from https://github.com/EleutherAI/lm-evaluation-harness
```

### Run Benchmarks
```bash
# Local model (llama.cpp server)
lm_eval --model openai-completions \
    --model_args base_url=http://localhost:8080/v1,model=model-name \
    --tasks mmlu,gsm8k,humaneval \
    --batch_size 4

# HF model
lm_eval --model hf \
    --model_args pretrained=meta-llama/Llama-3.1-8B-Instruct \
    --tasks mmlu,arc_challenge,hellaswag \
    --device cuda --batch_size auto
```

### Common Tasks
| Category | Tasks |
|----------|-------|
| Knowledge | mmlu, arc_easy, arc_challenge, hellaswag, piqa, winogrande |
| Reasoning | gsm8k, math, GPQA, bbh |
| Code | humaneval, mbpp, apps |
| Chat | mt_bench, alpaca_eval |

### Output
```bash
lm_eval --model hf --model_args pretrained=... --tasks mmlu --output_path results/
# Creates results/YYYY-MM-DD_HH-MM-SS.json with scores
```

---

## 4. HuggingFace Hub (HF Hub Operations)

### CLI (hf)
```bash
pip install -U "huggingface_hub[cli]"
hf auth login
```

### Search & Download
```bash
# Search models
hf search llama.cpp --sort trending --limit 10

# Download repo
hf download meta-llama/Llama-3.1-8B-Instruct --local-dir ./model

# Download specific files
hf download bartowski/Llama-3.1-8B-Instruct-GGUF \
    --include "*Q4_K_M.gguf" --local-dir ./gguf
```

### Python API
```python
from huggingface_hub import HfApi, snapshot_download

api = HfApi()
# List files
files = api.list_repo_files("bartowski/Llama-3.1-8B-Instruct-GGUF")
ggufs = [f for f in files if f.endswith(".gguf")]

# Download with progress
snapshot_download(repo_id="meta-llama/Llama-3.1-8B-Instruct", local_dir="./model")
```

### Upload
```bash
hf upload my-username/my-model ./model_dir --repo-type model
```

---

## 5. Weights & Biases (Experiment Tracking)

### Install & Auth
```bash
pip install wandb
wandb login
```

### Basic Logging
```python
import wandb

wandb.init(project="llm-finetune", config={"lr": 1e-4, "batch": 8})
wandb.log({"loss": 0.5, "step": 100})
wandb.finish()
```

### Sweeps
```yaml
# sweep.yaml
program: train.py
method: bayes
metric: {name: eval_loss, goal: minimize}
parameters:
  lr: {min: 1e-5, max: 1e-3, distribution: log_uniform}
  batch_size: {values: [4, 8, 16]}
```
```bash
wandb sweep sweep.yaml
wandb agent SWEEP_ID
```

### Model Registry
```python
artifact = wandb.Artifact("my-model", type="model")
artifact.add_file("model.pt")
wandb.log_artifact(artifact)
```

---

## 6. DSPy (Declarative LM Programs)

### Install
```bash
pip install dspy
```

### Core Concept
```python
import dspy

# Configure LM
lm = dspy.LM("openai/gpt-4o", api_key=os.getenv("OPENAI_API_KEY"))
dspy.configure(lm=lm)

# Define signature
class QA(dspy.Signature):
    """Answer questions with citations."""
    question: str = dspy.InputField()
    answer: str = dspy.OutputField(desc="Concise answer with citations")

# Build module
qa = dspy.ChainOfThought(QA)

# Run
pred = qa(question="What causes climate change?")
print(pred.answer)
```

### Optimization (MIPROv2 / BootstrapFewShot)
```python
from dspy.teleprompt import BootstrapFewShot

trainset = [dspy.Example(question="...", answer="...").with_inputs("question") for ...]
optimizer = BootstrapFewShot(metric=lambda gold, pred: gold.answer in pred.answer)
optimized_qa = optimizer.compile(qa, trainset=trainset)
```

### RAG Pipeline
```python
class RAG(dspy.Module):
    def __init__(self, retriever):
        self.retrieve = dspy.Retrieve(k=3, retriever=retriever)
        self.generate = dspy.ChainOfThought("context, question -> answer")
    def forward(self, question):
        context = self.retrieve(question).passages
        return self.generate(context=context, question=question)
```

---

## 7. OBLITERATUS (Abliteration)

Remove model refusals via diff-in-means ablation.

### Install
```bash
pip install obliteratus
```

### Usage
```python
from obliteratus import abliterate

# Get directions from harmful/harmless pairs
directions = abliterate.get_refusal_directions(model, tokenizer, harmful_prompts, harmless_prompts)

# Ablate
abliterated_model = abliterate.apply_ablation(model, directions, layers=range(10, 20))
```

### CLI
```bash
obliteratus ablate --model meta-llama/Llama-3.1-8B-Instruct \
    --harmful harmful.json --harmless harmless.json \
    --output ./abliterated-model
```

---

## 8. Segment Anything Model (SAM)

Zero-shot image segmentation via points, boxes, masks.

### Install
```bash
pip install segment-anything
# Or: pip install git+https://github.com/facebookresearch/segment-anything.git
```

### Usage
```python
from segment_anything import sam_model_registry, SamPredictor

sam = sam_model_registry["vit_h"](checkpoint="sam_vit_h_4b8939.pth")
predictor = SamPredictor(sam)

predictor.set_image(image)
masks, scores, logits = predictor.predict(
    point_coords=np.array([[x, y]]),
    point_labels=np.array([1]),
    multimask_output=True,
)
```

### Automatic Mask Generator
```python
from segment_anything import SamAutomaticMaskGenerator

mask_generator = SamAutomaticMaskGenerator(sam)
masks = mask_generator.generate(image)
# Returns list of dicts with segmentation, bbox, area, stability_score, etc.
```

---

## 9. AudioCraft (MusicGen / AudioGen)

Text-to-music and text-to-sound generation.

### Install
```bash
pip install audiocraft
```

### MusicGen (Text → Music)
```python
from audiocraft.models import MusicGen

model = MusicGen.get_pretrained("facebook/musicgen-large")
model.set_generation_params(duration=30)

descriptions = ["80s synthwave, driving bass, retro drums"]
wav = model.generate(descriptions)  # [B, C, T] tensor
```

### AudioGen (Text → Sound Effects)
```python
from audiocraft.models import AudioGen

model = AudioGen.get_pretrained("facebook/audiogen-medium")
model.set_generation_params(duration=5)

descriptions = ["door creaking open", "rain on window"]
wav = model.generate(descriptions)
```

---

## Cross-Cutting Patterns

### Model Discovery → Inference → Evaluation
1. **HF Hub** → search `apps=llama.cpp` → find `bartowski/Llama-3.1-8B-GGUF`
2. **llama.cpp** → serve local or `vllm serve` for throughput
3. **lm-eval** → benchmark against MMLU/ARC/GSM8K
4. **W&B** → log results, track model versions

### Ablation → Serving
1. **OBLITERATUS** → get abliterated model
2. **vLLM** → serve abliterated model via OpenAI API
3. **lm-eval** → verify refuse rate dropped, scores maintained

### Local Dev → Cloud Deploy
1. **llama.cpp** → iterate fast on CPU/Apple Silicon
2. **W&B** → log experiments, sweeps
3. **vLLM** → deploy to GPU cluster with tensor parallelism
4. **HF Hub** → upload final model / GGUFs

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| HF Hub local-app page not text-visible | Fall back to tree API + GGUF extraction |
| llama.cpp quant label not in tree API | Use exact HF page snippet; don't normalize labels |
| vLLM OOM on startup | Reduce `--max-model-len` or `--gpu-memory-utilization` |
| lm-eval batch size too large | Use `--batch_size auto` or explicit small value |
| W&B runs not appearing | Check `wandb.login()` and project name |
| DSPy optimizer needs trainset | Build minimal trainset (10-50 examples) first |
| OBLITERATUS directions need pairs | Use 50-100 harmful/harmless prompt pairs |
| SAM checkpoint missing | Download `sam_vit_h_4b8939.pth` from Facebook repo |
| AudioCraft slow on CPU | Use GPU; `device="cuda"` in model config |