# Runtime context audit

Use this procedure when an agent UI reports a surprisingly large context value, requests become slow, or compression appears ineffective.

## 1. Disambiguate the meter

First establish whether the displayed number is:

- **capacity**: the provider-aware maximum context window;
- **current request size**: fixed prompt + tool schemas + active messages + output reservation;
- **cumulative usage**: input/cache/output tokens summed across many API calls.

A label such as `272k context` without a numerator, percentage, or full bar is not evidence that 272k tokens are already consumed. Provider routes can enforce a smaller window than the same model slug has on a direct API, so resolve model + provider + base URL together.

## 2. Confirm session identity and freshness

Inspect the live routing entry and canonical session store rather than assuming the visible chat is still attached to yesterday's session. Record:

- session ID and title;
- fresh/reset/resumed state;
- active message count and tool-call count;
- previous session link, if any.

Do not infer current prompt size from cumulative session token totals.

## 3. Separate fixed and growing context

Measure these independently:

### Fixed per request

- core system and safety instructions;
- profile/persona instructions;
- tool schemas or deferred tool catalog;
- skill names/descriptions;
- persistent user profile and memory;
- platform/runtime metadata.

Where supported, use the stored system-prompt hash to retrieve its exact character length without printing secrets or the whole prompt.

### Growing session history

Aggregate **active** messages by role and tool name. Count content plus serialized tool calls/reasoning fields that are actually sent. Large `terminal`, `read_file`, process-log, diff/patch, and fully loaded skill results are usual suspects. Keep compacted/inactive rows separate: database history size is not active prompt size.

Character totals are useful for attribution but are not exact token counts. Use provider/request telemetry for the final token figure.

## 4. Reconcile estimates with the real request

Compare:

1. active-history estimate;
2. provider-reported prompt/input tokens for the latest call;
3. provider-aware maximum context;
4. reserved output tokens.

Differences often come from tool schemas, system instructions, message serialization, tokenizer behavior, and output reservation. Report them as separate layers instead of forcing one approximate number to explain everything.

## 5. Audit compression as an executed gate

Do not stop at `compression.enabled: true`. Verify from telemetry:

- global and provider-specific effective threshold;
- estimated tokens before compression;
- auxiliary provider/model selected, including fallback;
- whether summary generation succeeded;
- whether the summary was committed;
- before/after active request size.

If compression failed due to auth, quota, or an unaffordable output reservation, describe that as the failed mechanism—not as a permanent limitation of compression. Configure a working auxiliary provider, then verify a later compression run actually reduces context.

## 6. Report in a decision-friendly format

Give the user:

1. **Capacity or usage?** One sentence.
2. **Current session:** fresh/resumed and measured current state.
3. **Largest contributors:** exact counts/percentages from active history.
4. **Why compression did or did not help.**
5. **Smallest fixes:** new session per work item, working summarizer, earlier threshold if justified, bounded tool output.

Never expose config secrets while auditing. Prefer targeted config fields, hashes, lengths, and redacted status commands over dumping complete configuration files.
