# Error-Tracking Activation (Expo + Vercel + EAS + Sentry)

Companion to the "Activating an error-tracking provider end to end" section of SKILL.md. Use it when an already-merged tracking integration must actually deliver events from a deployed app.

## Three layers, three owners

| Layer | Where | Who does it |
|---|---|---|
| SDK init, sanitization, tags, verification gate | repo code | the PR |
| Client DSN, environment name, upload token, temporary verification flag | Vercel / EAS project settings | agent via CLI |
| Project creation, alert rules, ownership, server-side scrubbing | provider dashboard | the user |

State which layer is still outstanding instead of reporting a single "done".

## Environment variables for an Expo app on Vercel

- The collector's DSN must be exposed under the `EXPO_PUBLIC_*` name the code reads; an unprefixed server-side name will not reach the web bundle.
- Set an explicit app-environment variable per target (`staging` on preview, `production` on production); events and the verification gate key off it.
- Set both per environment. A variable present on only one target silently disables tracking on the other.
- Client bundles bake env values at build time: after changing them, rebuild or redeploy and confirm the deployment is READY before verifying.

### CLI recipes

```bash
vercel env ls --project <project>
vercel env pull <tmpfile> --environment preview --project <project> --yes
vercel env add <NAME> <preview|production> --force --no-sensitive --project <project> --yes
vercel list <project> --json --limit 10
vercel redeploy <deployment-url> --target preview
```

- Read secrets only through `env pull` into a `chmod 600` file that the script deletes afterwards. Do not print values.
- `vercel list <project> --json` is how to find the deployment to redeploy; each entry carries the commit SHA, branch, and PR id in `meta`.
- A project with no local link needs `--project <name>` on every command.
- Environment variables contributed by an integration cannot be converted to the Secret type; rotate the credential at the provider if it was stored as readable config.

## Credential scopes

Two different jobs need two different credentials:

- **Source-map upload** needs only `project:read`-style scope. A token in this shape authenticates against the project endpoint (HTTP 200) but returns **403** on the issues endpoint.
- **Reading issues/events for analysis** needs `event:read`; without it the analyzer cannot list anything.

Probe the exact endpoint the job will call with the exact credential before enabling the job, and store the read credential where the scheduled job runs rather than in the product repository. Never echo the value: collect it through a hidden prompt (`getpass`) or a platform pull, validate it live, and only then persist it.

## Source maps

- Web: the export command must emit source maps and the upload hook must run with a token available. A missing token should skip the upload without failing the build, and generated maps must be removed from the deployable output afterwards.
- EAS: configure the upload through the Expo config plugin with project, organization, and a sensitive upload token; confirm the upload line in the build log before trusting symbolication.
- Native symbolication additionally requires the EAS project id. Web tracking works without it, so treat "native tracking" and "web tracking" as separately verifiable capabilities rather than one switch.

## Verification gate to design into the code

Guard the one-shot verification event on all of: a DSN present, environment not `production`, an explicit build-time opt-in flag, and an authenticated session with the required context. Send exactly one labelled event per runtime, and assert in the provider dashboard that the environment/release/platform/route/role tags are present, that PII and request bodies are absent, and that the top frame resolves to repository source rather than bundle code. Remove the opt-in flag right after.

## Headless limits

A protected preview answers any unauthenticated fetch with the platform's SSO login page (HTTP 200, redirected off-origin). Do not read that as a broken deployment and do not keep retrying: give the user the deployment URL, the flag that is temporarily on, and the exact list of tags and steps to confirm, then switch the flag off on their report.
