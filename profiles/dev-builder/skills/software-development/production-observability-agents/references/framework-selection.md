# Framework selection for production watchdogs

Use this decision process before committing to an agent framework.

## First classify the system

A production watchdog is normally workflow-first and agent-assisted. Its critical path is deterministic collection, persistence, deduplication, approval, and verification. LLM reasoning is one bounded step, not the runtime architecture.

Prefer an explicit workflow/state-machine runtime when incidents must resume reliably, branch by policy, wait for approval, and avoid duplicate side effects. Prefer a filesystem-first agent runtime when the main goal is rapid experimentation with tools, channels, schedules, and conversational sessions.

## Weighted criteria

Score each candidate from 1 to 5 and record evidence from official docs or a spike.

| Criterion | Suggested weight | Verification question |
|---|---:|---|
| Durable execution | 5 | Can work resume after process restart at a committed step? |
| Idempotency/replay model | 5 | Is replay behavior explicit enough to prevent duplicate issues or writes? |
| Human approval | 5 | Can execution park durably and resume with a decision? |
| Schedules and webhooks | 4 | Are both first-class in the intended deployment model? |
| Explicit workflow control | 4 | Can deterministic and LLM steps be mixed and inspected? |
| TypeScript support | 4 | Is the JS/TS implementation first-class, not secondary? |
| Self-hosting | 4 | Are persistence, workers, migrations, and scaling documented? |
| Observability | 4 | Are traces, step state, retries, cost, and failures inspectable? |
| Evals/testing | 3 | Can graphs/workflows and LLM behavior be tested independently? |
| Provider portability | 3 | Can ordinary typed adapters remain framework-agnostic? |
| Operational complexity | 3 | What databases, workers, control planes, and hosted services are required? |
| Ecosystem lock-in | 2 | Which useful features disappear outside the vendor platform? |

Calculate both the weighted score and the architectural fit. A high feature score does not compensate for a runtime model that fights the operational loop.

## Mandatory spike

Before choosing, implement the same small slice in the top two candidates:

1. scheduled collection from two fake providers
2. normalized signals persisted across restart
3. correlation into one finding
4. durable approval before a fake issue write
5. forced failure and retry
6. replay without duplicate action
7. trace or run inspection
8. one behavior eval

Time setup, implementation, failure diagnosis, and deployment. Record hidden infrastructure requirements and hosted-only features.

## Decision guidance

- Choose a graph/workflow framework when explicit branching, persisted state, retries, and approvals dominate.
- Choose an agent-first framework when fast tool composition, channels, and durable conversations dominate.
- Choose a general durable workflow engine plus a thin AI SDK when reliability, long-lived operations, and vendor independence outweigh implementation speed.
- Keep domain schemas and provider adapters outside the selected framework so a later runtime migration does not rewrite integrations.

## Re-evaluation gate

Re-evaluate after the first real app and again after integrating a second stack. Migration pressure appears when provider-specific behavior leaks into the core, replay semantics create duplicate actions, or hosted-only functionality becomes operationally mandatory.
