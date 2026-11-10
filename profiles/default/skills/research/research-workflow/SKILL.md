---
name: research-workflow
description: "Complete research toolkit: arXiv paper search, RSS/blog monitoring (blogwatcher), LLM knowledge base (llm-wiki), prediction markets (Polymarket), ML paper writing (NeurIPS/ICML/ICLR). Use for literature review, domain recon, market monitoring, or academic writing."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [arXiv, blogwatcher, llm-wiki, Polymarket, paper-writing, literature-review, academic]
    related_skills: [productivity-tools, mlops-workflow, jupyter-live-kernel]
---

# Research Workflow — Complete Toolkit

Covers paper discovery, feed monitoring, knowledge base building, prediction markets, and academic writing.

---

## Quick Selection Guide

| Task | Tool | Subsection |
|------|------|------------|
| Search arXiv papers by keyword/author/category | arXiv CLI/API | **1. arXiv** |
| Monitor blogs/RSS/Atom feeds | blogwatcher | **2. Blogwatcher** |
| Build/query interlinked markdown KB | llm-wiki | **3. llm-wiki** |
| Query prediction markets | Polymarket | **4. Polymarket** |
| Write ML papers for top conferences | research-paper-writing | **5. Paper Writing** |

---

## 1. arXiv

### Search
```bash
# By keyword
arxiv search "transformer architecture" --max-results 10

# By author
arxiv search --author "Hinton" --max-results 20

# By category
arxiv search --category cs.LG --max-results 50

# By ID
arxiv fetch 2301.08727

# Combined
arxiv search "diffusion model" --category cs.CV --max-results 10 --sort relevance
```

### Python API
```python
import arxiv

search = arxiv.Search(
    query="transformer",
    max_results=10,
    sort_by=arxiv.SortCriterion.Relevance
)
for paper in search.results():
    print(f"{paper.title} ({paper.entry_id})")
```

### Key Categories
- `cs.LG` — Machine Learning
- `cs.CV` — Computer Vision
- `cs.CL` — Computation and Language (NLP)
- `cs.AI` — Artificial Intelligence
- `stat.ML` — Machine Learning (Statistics)
- `cs.RO` — Robotics

---

## 2. Blogwatcher

### Install
```bash
pip install blogwatcher-cli
```

### Monitor Feeds
```bash
# Add feed
blogwatcher add "https://blog.example.com/feed.xml" --name "Example Blog"

# List feeds
blogwatcher list

# Fetch new posts
blogwatcher fetch --all

# Fetch with filters
blogwatcher fetch --since 2024-01-01 --limit 10

# Export
blogwatcher export --format markdown --output ./posts/
```

### Use Cases
- Track competitor blogs
- Monitor research group publications
- Aggregate AI/ML newsletters
- Watch for specific keywords across feeds

---

## 3. llm-wiki (Karpathy's LLM Wiki)

Build and query an interlinked markdown knowledge base for LLM research.

### Structure
```
llm-wiki/
├── concepts/        # Core concepts (attention, transformer, RLHF)
├── papers/          # Paper summaries
├── models/          # Model cards
├── techniques/      # Training/inference techniques
├── benchmarks/      # Evaluation results
└── index.md         # Auto-generated index
```

### Workflow
```bash
# Initialize
llm-wiki init

# Add concept
llm-wiki add concept "FlashAttention" --content "..."

# Add paper
llm-wiki add paper "FlashAttention-2" --url "https://arxiv.org/abs/2307.08691" --tags "attention,optimization"

# Build index
llm-wiki build-index

# Search
llm-wiki search "attention"
llm-wiki search "RLHF" --tags "alignment"

# Query
llm-wiki query "What is the difference between FlashAttention and FlashAttention-2?"
```

### Linking
- Auto-links: `[[concept]]` syntax
- Manual cross-refs in frontmatter: `related: [attention, transformer]`
- Graph view: `llm-wiki graph --output wiki-graph.html`

---

## 4. Polymarket

Query prediction markets for research insights.

### Python API
```python
import requests

# Markets
markets = requests.get("https://gamma-api.polymarket.com/markets").json()

# Filter for AI-related
ai_markets = [m for m in markets if "ai" in m["question"].lower() or "model" in m["question"].lower()]

# Prices
for m in ai_markets[:5]:
    print(f"{m['question']}: Yes {m['yes_price']*100:.0f}¢, No {m['no_price']*100:.0f}¢")

# Orderbook
orderbook = requests.get(f"https://gamma-api.polymarket.com/orderbook?market={m['id']}").json()

# History
history = requests.get(f"https://gamma-api.polymarket.com/markets/{m['id']}/history").json()
```

### Common Queries
```bash
# All markets
curl -s "https://gamma-api.polymarket.com/markets" | jq '.[] | {question, yes_price, no_price, volume}'

# Active markets only
curl -s "https://gamma-api.polymarket.com/markets?active=true&closed=false"

# By category
curl -s "https://gamma-api.polymarket.com/markets?category=technology"
```

### Use Cases
- Track sentiment on AI capabilities timelines
- Monitor regulatory outcome probabilities
- Gauge market expectations for model releases
- Cross-reference with arXiv publication dates

---

## 5. Research Paper Writing (NeurIPS/ICML/ICLR)

### Pipeline
```
DESIGN → EXPERIMENTS → WRITE → REVISE → SUBMIT
```

### Design Phase
```markdown
# Paper Design Doc

## Core Contribution
One sentence: What is the new insight/result?

## Problem Statement
What is broken/suboptimal in current approaches?

## Hypothesis
What do you expect to show? (Falsifiable)

## Method Sketch
Key algorithm/architecture/component. Links to related work.

## Experiments
| Experiment | Purpose | Expected Outcome | Success Criterion |
|------------|---------|------------------|-------------------|
| Main | Show SOTA on X | > baseline by Y% | p < 0.05 |
| Ablation | Component importance | Drop > Z% when removed | Significant |
| Scaling | Model size effect | Predictable scaling law | R² > 0.9 |

## Risks
- Compute budget
- Data availability
- Reproducibility
```

### Writing Structure (ML Conference)
```
1. Abstract (150-250 words) — write last
2. Introduction (1-1.5 pages)
   - Hook, problem, approach, results preview, contributions
3. Related Work (0.5-1 page)
   - Group by theme, not chronological
   - Position your work clearly
4. Method (2-4 pages)
   - Algorithm, architecture, equations
   - Figures for intuition
5. Experiments (3-5 pages)
   - Setup (datasets, baselines, metrics)
   - Main results (tables with statistical significance)
   - Ablations (systematic)
   - Analysis (qualitative, failure cases)
6. Discussion/Limitations (0.5 page)
7. Conclusion (0.25 page)
```

### LaTeX Tips
```latex
% Use packages
\usepackage{booktabs}  % Professional tables
\usepackage{siunitx}   % Align numbers
\usepackage{subcaption} % Subfigures

% Table template
\begin{table}[t]
\caption{Main results on X benchmark.}
\label{tab:main}
\centering
\begin{tabular}{lcccc}
\toprule
Method & Metric A & Metric B & Metric C \\
\midrule
Baseline & 0.82 & 0.75 & 0.68 \\
Ours & \bf 0.87 & \bf 0.81 & \bf 0.74 \\
\bottomrule
\end{tabular}
\end{table}
```

### Submission Checklist
- [ ] Anonymized (no author names, no identifying URLs in code)
- [ ] Supplementary material separate
- [ ] Code released (or commitment to release)
- [ ] Compute budget disclosed (for ML conferences)
- [ ] Ethics/broader impact statement
- [ ] Reproducibility checklist (random seeds, hyperparameters)
- [ ] All figures vector (PDF) or high-res (300+ DPI)
- [ ] References complete, formatted to venue style

### Revision Strategy
1. **Address every reviewer point** — even if you disagree, acknowledge
2. **Make changes visible** — use `latexdiff` or highlight in rebuttal
3. **Run new experiments** if requested — don't argue
4. **Tone**: grateful, precise, not defensive

---

## Cross-Cutting Patterns

| Pattern | Tools |
|---------|-------|
| Lit review → paper ideas | arXiv → llm-wiki → Polymarket → design doc |
| Track field → writing | blogwatcher → llm-wiki → paper draft |
| Market signals → experiments | Polymarket → hypothesis → ablation study |
| Knowledge base → survey paper | llm-wiki → structured summary → arXiv submission |

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| arXiv rate limits | Use semantic search API, cache results |
| Blogwatcher duplicate posts | Use `--since` with last fetch timestamp |
| llm-wiki link rot | Periodic `llm-wiki check-links` |
| Polymarket low liquidity | Check volume > $1000 before citing |
| Paper design too vague | Make hypothesis falsifiable; define success criteria upfront |
| Writing intro first | Write abstract + intro LAST, after results are solid |
| Tables not camera-ready | Use `booktabs`, `siunitx`, check venue template |
| Rebuttal ignores minor points | Address every point; "We agree" + change is valid |