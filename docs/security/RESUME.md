# ArubaCentral Security Assessment — Resume Prompt

Paste the block below into a fresh session to continue. (Same-session resume: skip this —
just name the finding to fix first.)

**Last updated:** 2026-07-03 — assessment complete, remediation drafted, nothing applied yet.

---

```
You are a cybersecurity expert resuming an AUTHORIZED, defensive hardening engagement on
software I own: the ArubaCentral iOS app (SwiftUI) and its Cloudflare Worker relay.

STEP 1 — Load context before doing anything else:
  - ArubaCentral/docs/security/findings.md          (findings log + per-finding runtime evidence)
  - ArubaCentral/docs/security/remediation-drafts.md (every proposed fix, code + recommended order)
  - ArubaCentral/docs/security/2026-07-03-security-test-plan.md (original MASVS / API-Top-10 plan)
  - Memory: project-aruba-central, aruba-central-security-test-plan, security-remediation-workflow

STEP 2 — Confirm state (should already be true; verify against the docs):
  - Assessment is DONE. No production code changed. Fixes are drafted, not applied.
  - App-side findings proven by 15 green XCTest cases in ArubaCentralTests/ across 4 classes:
    InputValidationSecurityTests, AuthSecurityTests, StorageSecurityTests, NetworkSecurityTests.
    Each test currently asserts the VULNERABLE behavior.
  - Relay §7 findings confirmed via local `wrangler dev` black-box (Phase 2 scripts in scratchpad).
  - Open (High) items to fix first: R-1 webhook fail-open, R-2 unauth /register.
  - Already refuted, do NOT "fix": A-1 (iOS 26.5 Foundation is lenient — no crash),
    A-5 (URLQueryItem encodes), N-2/3.5 (region allowlist enforced).

STEP 3 — Proceed under MY remediation workflow (strict):
  Fix ONE finding at a time -> apply the code change -> INVERT that finding's security test so
  it asserts the HARDENED behavior -> re-run only that test to green -> STOP and report for my
  review before touching the next finding. Never apply a fix without my explicit go-ahead for
  that specific finding.

STEP 4 — First message to me: propose the fix order (draft recommends the relay auth trio:
  R-1 fail-closed + R-3 constant-time compare, then R-2 register-auth + R-7 token validation),
  ask which finding to start with, and get my decision on the two still-undrafted items:
    (a) R-8 rate limiting — Cloudflare native rules (config) vs Durable Object limiter?
    (b) §6 resilience (jailbreak / anti-debug) — accept-risk vs implement?

ENVIRONMENT & GUARDRAILS (verified 2026-07-03):
  - Xcode 26.6; only the iOS 26.5 Simulator (iPhone 17) is installed. App deployment target is
    iOS 26.5 (older notes said "iOS 16+" — that is stale).
  - Test target uses filesystem-synchronized groups: a new .swift file dropped in
    ArubaCentralTests/ is auto-compiled; no project.pbxproj edits.
  - Run tests: xcodebuild test -scheme ArubaCentral
    -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ArubaCentralTests/<Class>
  - Relay: test ONLY via local `wrangler dev` (miniflare, local KV). Never use the production
    KV id in relay/wrangler.toml; never touch a live Aruba tenant. Ask before anything
    internet-facing or before any remote deploy.
  - Tooling present and already run clean: semgrep (+ custom rules at
    docs/security/semgrep-rules/aruba-custom.yml), gitleaks, osv-scanner. mitmproxy is NOT installed.
  - Ignore the "No such module 'XCTest'" editor diagnostic on the test files — SourceKit
    artifact; the tests build and run.
```
