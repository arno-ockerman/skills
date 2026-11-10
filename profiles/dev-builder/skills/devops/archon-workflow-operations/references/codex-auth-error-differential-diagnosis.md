# Codex auth-error differential diagnosis

Use this when Archon formats a failure as “Codex authentication error” but shared OAuth is expected to work.

## Why the message is not sufficient

Archon classifies provider failures and replaces the raw error with friendly guidance. Treat that text as a starting hypothesis, not evidence that the credential is invalid. Do not immediately rotate or re-login a shared credential that other consumers are successfully using.

## Verification ladder

1. Read `/api/config` and the codebase/workflow metadata to identify the effective provider, exact model, and reasoning effort.
2. Run `codex login status`, but do not stop there; status only proves credential metadata exists.
3. Run a minimal real prompt through the shared wrapper with the **exact configured model**. A different model can hide a CLI/model compatibility failure.
4. Verify the CLI version against the model's minimum requirement. Upgrade centrally when needed, preserve UID/GID ownership, and re-run the exact-model prompt.
5. In the actual Archon image and runtime UID, run the wrapper and a real prompt. Minimal images may lack Node, so the shared wrapper should invoke the installed Codex JS entry with the shared Bun runtime.
6. If raw CLI succeeds, run a minimal `@openai/codex-sdk` `startThread` + `runStreamed` probe inside the same image. This separates wrapper/auth/runtime failures from Archon's orchestration and request-option path.
7. Explicitly redeploy/recreate the main Archon service after changing a mounted CLI or wrapper. Compose can leave an unchanged main service running when only a sibling diagnostic service changed.
8. Finally create a disposable Web conversation against a Codex-backed codebase and require an assistant response. API health and raw CLI success are not end-to-end proof.

## Interpreting outcomes

- Login status fails: repair shared credential/home ownership.
- Status passes but exact-model CLI fails: inspect CLI version, model access, and environment overrides before reauthenticating.
- CLI fails only in the image: inspect runtime dependencies, wrapper shebang/runtime, UID, mounts, and environment.
- CLI passes but SDK fails: investigate Codex CLI/SDK compatibility and SDK options.
- CLI and SDK pass but Archon still formats an auth error: inspect the actual Codex child executable and environment, not only `command -v codex`. A source/dev-mode Archon image can deliberately ignore `CODEX_BIN_PATH` and let `@openai/codex-sdk` launch its bundled native binary from `/app/node_modules`; that child never passes through a shared wrapper that rewrites `HOME`. Capture `/proc/<child>/cmdline` and sanitized env metadata during a disposable chat turn. If the bundled child uses the app HOME while shared ChatGPT auth lives elsewhere, set the standard `CODEX_HOME` environment variable to the shared `.codex` directory (for de gebruiker: `/opt/ai-tools/config/codex/home/.codex`) through the TrueNAS Custom App config and recreate the app. Verify by A/B-running the bundled binary without/with `CODEX_HOME`, then run a disposable Web chat. Preserve `CODEX_HOME_DIR` only as the shared wrapper's own convention; the bundled Codex binary does not consume it.
- If executable and auth-home selection match but Archon still fails, the unresolved fault is inside Archon's orchestration/provider request path. Preserve the working shared login, obtain the raw server/provider log, and compare effective cwd, environment injection, resume session, model/effort, MCP config, output schema, and prompt options. Do not present re-login as the fix.

## Safe temporary diagnostic service

When Docker access is unavailable but TrueNAS `app.update` is authorized, a short-lived sibling service using the same image, UID, environment, and `/opt/ai-tools` mount can write a sanitized probe log to a shared diagnostics directory. Preserve the full structured Compose object, submit it through `midclt call -j app.update <app> -`, and remove the service afterward. Never print environment values or credential files.

## Full shared executable path in source-mode Docker

Setting `CODEX_HOME` fixes shared authentication but does not prove Archon uses the shared Codex executable. Capture the live child command line during a disposable chat turn. If it still starts `/app/node_modules/@openai/codex-<platform>/.../codex`, the source/dev-mode resolver is returning `undefined` before reading `CODEX_BIN_PATH`.

For a durable TrueNAS deployment, build a small derived image pinned to the currently verified upstream digest. Change only the resolver guard so source mode returns `undefined` when neither `CODEX_BIN_PATH` nor `assistants.codex.codexBinaryPath` is configured; explicit overrides must continue into the normal env/config resolution tiers. Keep the build context in the Archon deployment dataset. Configure the Custom App with the derived local image and `pull_policy: never`, otherwise TrueNAS may try to pull the local tag, stop the app, and never create a container. Preserve `CODEX_HOME` as a defensive auth fallback.

Verify all layers:

1. one-shot resolver import reports `/opt/ai-tools/bin/codex` with source `env`;
2. TrueNAS `app.config` contains the local image, `pull_policy: never`, `CODEX_BIN_PATH`, and `CODEX_HOME`;
3. the recreated container is healthy with stable restart count;
4. live process capture shows `/opt/ai-tools/bin/codex` followed by the native binary under the shared npm prefix, not `/app/node_modules`;
5. `codex --version` matches the shared wrapper version;
6. a disposable Web chat returns the expected assistant response and is then deleted.

## Cleanup and reporting

Remove temporary diagnostic services and files, restore any experimental config override, and report separately:

- confirmed working layers;
- the first failing boundary;
- whether the user actually needs to reauthenticate;
- the exact acceptance test still failing.
