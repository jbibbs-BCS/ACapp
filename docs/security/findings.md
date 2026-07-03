# ArubaCentral — Security Findings Log

**Assessment type:** Authorized static analysis (owner's own app + self-hosted relay).
**Phases covered:** 1 — Static pass (§8.5 + §4 + §7 + statically-verifiable §1/§2), zero runtime risk · 2 — Relay black-box against **local isolated** `wrangler dev` (§7). See [Phase 2 runtime results](#phase-2--relay-black-box-local-isolation-runtime-results).
**Date:** 2026-07-03
**Method:** Manual source review against current code + available static tooling (`npm audit`, git-history secret grep). `semgrep`, `osv-scanner`, `gitleaks`, `trufflehog` are **not installed** — see [Tooling gaps](#tooling-gaps) for install/run commands.
**Reference plan:** `docs/security/2026-07-03-security-test-plan.md`

> Status legend: **Confirmed** (proven from code) · **Refuted** (hypothesis disproven, code is safe) · **Confirmed-code / Needs-runtime** (code defect proven statically; live impact needs an isolated deployment to quantify) · **Needs-runtime** (cannot be judged without execution).
> **No code was modified. Assessment only.**

---

## Summary table

| ID | Plan § | Title | Severity | Status |
|----|--------|-------|----------|--------|
| R-1 | 7.4 | `/webhook` auth fails open when `WEBHOOK_SECRET` unset/empty | **High** | ✅ **REMEDIATED** (fail-closed, test-guarded) |
| R-2 | 7.1 | `/register` is fully unauthenticated | **High** | ✅ **REMEDIATED** (X-App-Secret, fail-closed) |
| R-3 | 7.5 | Non-constant-time webhook-secret comparison | Medium | ✅ **REMEDIATED** (constant-time, test-guarded) |
| R-4 | 7.2 | All tokens in one KV key; full read-modify-write per register | Medium | ✅ **REMEDIATED** (per-token keys) |
| R-5 | 7.3 | Non-atomic read-modify-write → lost-update race | Medium | ✅ **REMEDIATED** (independent puts) |
| R-6 | 7.6 | Push-content injection / phishing (no length/charset caps) | Medium | ✅ **REMEDIATED** (strip + cap in parseWebhook) |
| R-7 | 7.8 | APNs `device_token` interpolated into URL path, unvalidated | Medium | ✅ **REMEDIATED** (hex/length validated at register) |
| R-8 | 7.12 | No rate limiting on either endpoint | ~~Medium~~ Low | 🅰️ **ACCEPTED** (personal scale, push dormant) |
| R-9 | 7.10 | No unregister path; APNs 410 (Unregistered) ignored | Low | ✅ **REMEDIATED** (prune on 410/400 + /unregister) |
| R-10 | 7.7 | No application-level body-size guard on `request.json()` | Low | ✅ **REMEDIATED** (16 KB cap → 413) |
| R-11 | 7.11 | No CORS/OPTIONS handling; verb/path model minimal | Low | Confirmed |
| R-12 | 7.9 / 8.2 | Secret management posture (secrets not committed; KV id in toml) | Low / Info | Confirmed |
| R-13 | apns.ts | APNs JWT regenerated per-push per-token (no caching) | Low | Confirmed |
| A-1 | 4.1 | Force-unwraps in `buildRequest` → client-side crash DoS | ~~Medium~~ Low | ✅ **RESOLVED** (guarded; force-unwraps removed) |
| A-2 | 4.2 | Path injection: raw `serial` interpolated into request paths | Medium | ✅ **REMEDIATED** (percent-encoded segments) |
| A-3 | 4.3 | OData filter injection: raw `site` in `siteName eq '…'` | Medium | ✅ **REMEDIATED** (quotes escaped) |
| A-4 | 4.5 | Unbounded pagination loops (`fetchAllPages_*`, no page cap) | Medium | ✅ **REMEDIATED** (50-page cap) |
| A-5 | 4.4 | Query-param smuggling via `next`/`search` | Low | **Refuted (runtime test)** — safe |
| A-6 | 1.1 | Keychain uses `kSecAttrAccessibleWhenUnlocked` (not `…ThisDeviceOnly`) | Medium | ✅ **REMEDIATED** (ThisDeviceOnly, test-guarded) |
| A-7 | 2.6 | No single-flight token refresh → refresh stampede | Medium | ✅ **REMEDIATED** (single-flight coalescing) |
| A-8 | 2.3 | `isAuthenticated` == "a token string exists", not "valid" | Low | ✅ **REMEDIATED** (requires unexpired token) |
| A-9 | 6.4 | `#if DEBUG` preview bypass compiled out of Release | Info | Confirmed (clean) |
| A-10 | 3.2 / 5.6 | No ATS overrides; no custom URL schemes | Info | Confirmed (clean) |
| A-11 | 5.2 | Client secret rendered in plain `TextField` (snapshot risk) | Low | ✅ **REMEDIATED** (scenePhase collapse; verify snapshot manually) |
| N-1 | 3.1 | No TLS certificate/public-key pinning | ~~Medium~~ Low | 🅰️ **ACCEPTED** (personal scope; pin-rotation burden > benefit) |
| N-2 | 3.5 | Region-SSRF via UserDefaults `selectedRegionId` | ~~Low~~ Info | **Refuted** + ✅ residual **REMEDIATED** (`updateBaseURL` allowlisted) |
| B-1 | 8.1 | Relay dependency audit | Info | Confirmed (clean) |
| B-2 | 8.4 | `.gitignore` does not cover `.p8`/`.dev.vars`/xcuserdata | Low | Confirmed |
| B-3 | 8.3 | Empty entitlements (Push/keychain-group not yet added) | Info | Confirmed (expected) |

---

## Relay (Cloudflare Worker) — §7

### R-1 — `/webhook` auth fails open when `WEBHOOK_SECRET` unset/empty  — **High** — Confirmed
**Evidence:** `relay/src/index.ts:49-54`
```ts
if (env.WEBHOOK_SECRET) {                       // ← whole check is skipped when unset/empty
  const provided = request.headers.get('X-Webhook-Secret') ?? '';
  if (provided !== env.WEBHOOK_SECRET) {
    return new Response('Forbidden', { status: 403 });
  }
}
```
If `WEBHOOK_SECRET` is unset, empty, or `""`, the guard is skipped entirely and **any unauthenticated caller can POST `/webhook`** and fan a spoofed push to every registered device (phishing, e.g. "Critical: tap to re-authenticate…"). A misconfigured deploy silently downgrades to no auth.
**Remediation:** Fail **closed** — if `!env.WEBHOOK_SECRET`, return `503`/`500` and refuse to process. Treat a missing secret as a hard configuration error, never as "auth disabled." Combine with R-3 (constant-time compare).

**✅ REMEDIATED (2026-07-03)** — `handleWebhook` (`relay/src/index.ts`) now returns **503** when `WEBHOOK_SECRET` is unset/empty, before any processing. The `!==` compare is left in place (R-3, separate). Guarded by `relay/test/webhook-auth.test.ts` (4 tests): unset→503, set+missing→403, set+wrong→403, set+correct→200. Full relay suite: **28/28 passing**. Constant-time compare (R-3) still open.

### R-2 — `/register` is fully unauthenticated — **High** — Confirmed
**Evidence:** `relay/src/index.ts:15-46` (`handleRegister` performs no authentication/attestation), `tokens.ts:24-33` (`saveToken`).
Anyone who knows the URL can POST arbitrary `device_token` values. Impact: pollute the recipient set with junk tokens, inflate APNs load, and — combined with R-4/R-5 — grow/corrupt the KV blob. No proof the token belongs to a genuine install.
**Remediation:** Require a shared secret header on `/register` and/or Apple **App Attest / DeviceCheck** so only genuine app instances register. Validate token shape server-side (see R-7). Add per-IP throttling (R-8).

**✅ REMEDIATED (2026-07-03)** — `handleRegister` now fails closed if `REGISTER_SECRET` is unset (503) and requires a matching `X-App-Secret` header via the constant-time `timingSafeEqual` (403 otherwise). Guarded by `relay/test/register-auth.test.ts`. **Follow-ups:** (1) `REGISTER_SECRET` must be provisioned as a Worker **secret** (like `WEBHOOK_SECRET`) — config/ops; (2) the iOS registration call (Push/Task 6, not yet built) must send `X-App-Secret`; (3) a shipped shared secret is a stopgap — **App Attest / DeviceCheck** remains the robust control (open).

### R-3 — Non-constant-time webhook-secret comparison — **Medium** — Confirmed
**Evidence:** `relay/src/index.ts:51` — `provided !== env.WEBHOOK_SECRET`.
JS `!==` on strings short-circuits on the first differing byte and length, leaking timing about prefix/length. Over many requests this is a theoretical secret-recovery side channel.
**Remediation:** Constant-time compare. Hash both sides and compare fixed-length digests, e.g. `crypto.subtle.digest('SHA-256', …)` on each then a length-safe byte compare (or compare HMACs). Reject early only on the fail-closed check (R-1), not on content.

**✅ REMEDIATED (2026-07-03)** — added `timingSafeEqual(a, b)` (`relay/src/index.ts`): SHA-256-digests both sides then XOR-compares the fixed 32-byte results, so the compare is independent of length/prefix. `handleWebhook` now uses it instead of `!==`. Guarded by 3 added cases in `webhook-auth.test.ts` (short-prefix, long-prefix, empty → all 403; correct → 200). Relay suite: **31/31 passing**.

### R-4 — Single KV key + full read-modify-write per registration — **Medium** — Confirmed
**Evidence:** `relay/src/tokens.ts:12-33` — one key `registered_tokens` holds a JSON array of **all** tokens; `saveToken` does `loadTokens()` → mutate array → `kv.put(entire array)`.
Every registration reads and rewrites the whole blob. As token count grows this trends toward the KV value-size limit (25 MB) and rising latency/cost; each webhook also `loadTokens()` the entire array (`index.ts:68`).
**Remediation:** One KV entry per token (`token:<hash>` → record), enumerate with `kv.list()` (or maintain a paginated index). Add a registration cap. This also fixes R-5.

**✅ REMEDIATED (2026-07-03)** — `tokens.ts` rewritten to per-token keys (`token:<device_token>`): `saveToken` is a single independent `put` (upsert), `loadTokens` paginates `kv.list({prefix})`, and a new `deleteToken` supports pruning. The single `registered_tokens` blob is gone. Guarded by `tokens.test.ts` (8 pre-existing behavior tests pass unchanged + 2 new: one-key-per-token, delete). **Trade-off (noted):** webhook fan-out is now list + N gets — move to a Durable Object index at large scale. **Optional (open):** add a max-registrations cap.

### R-5 — Registration race / lost updates — **Medium** — Confirmed
**Evidence:** `relay/src/tokens.ts:24-33` — read-modify-write is not atomic; KV has no compare-and-swap. Concurrent `/register` calls each read the same array and the last `put` wins, silently dropping the others' tokens.
**Remediation:** Per-token keys (R-4) eliminate the shared-array contention. If a shared structure is required, use a Durable Object to serialize writes.

**✅ REMEDIATED (2026-07-03)** — resolved by the R-4 per-token-key redesign: each register is an independent `put` to its own key, so concurrent registrations can no longer clobber one another (no read-modify-write on a shared array).

### R-6 — Push-content injection / phishing — **Medium** — Confirmed
**Evidence:** `relay/src/webhook.ts:30-48` copies `raw.name`/`site_name`/`device_serial`/`description` straight into `title`/`body`; `index.ts:71-79` puts them into `aps.alert`. No length caps, no control-char stripping.
An attacker who can reach `/webhook` (trivially so under R-1) fully controls lock-screen alert text.
**Remediation:** Enforce max lengths on title/body, strip control/RTL characters, and gate behind real auth (R-1/R-2). Consider generic lock-screen copy with detail behind unlock (plan §5.7).

**✅ REMEDIATED (2026-07-03)** — `parseWebhook` (`relay/src/webhook.ts`) now runs `title`/`body` through `clean()`: strips C0 controls, DEL, and bidi override/isolate chars (` -‪-‮⁦-⁩`) and caps title=120 / body=240. Combined with R-1 (auth) this closes the phishing vector. Guarded by 6 cases in `webhook.test.ts` (control/DEL strip, bidi strip, newline/tab strip, title & body length caps, normal content preserved). Suite: **50/50**. *(Lock-screen "generic copy" per §5.7 is a separate app-side UX choice, still open.)*

### R-7 — APNs `device_token` interpolated into URL path, unvalidated — **Medium** — Confirmed
**Evidence:** `relay/src/apns.ts:72` — `fetch(\`https://${host}/3/device/${token}\`, …)`. `token` originates from unauthenticated `/register` (R-2) and is never validated for shape.
A token containing URL metacharacters is smuggled into the request line to Apple's host (defense-in-depth / request-smuggling concern).
**Remediation:** Validate at registration and before send: APNs device tokens are lowercase hex, typically 64+ chars. Reject anything not matching `^[0-9a-fA-F]{64,200}$`; optionally `encodeURIComponent`.

**✅ REMEDIATED (2026-07-03)** — `handleRegister` rejects any `device_token` not matching `^[0-9a-fA-F]{64,200}$` with 400, so only well-formed tokens are ever stored (and thus ever reach `sendPush`'s URL interpolation). Guarded by 7 cases in `register-auth.test.ts` (non-hex, traversal, CRLF, too-short, oversized, non-string → 400; canonical 64-hex → 200). **Optional defense-in-depth (open, Low):** repeat the check in `apns.ts` `sendPush` before the `${token}` interpolation.

### R-8 — No rate limiting — **Medium** — Confirmed
**Evidence:** `relay/src/index.ts` router (lines 91-102) has no throttling on `/register` or `/webhook`. Enables spam/DoS/cost amplification, and makes R-3's timing attack and R-2's token flooding practical.
**Remediation:** Add Cloudflare rate-limiting rules (or a Durable-Object/KV per-IP counter) on both routes.

**🅰️ ACCEPTED / DEFERRED (2026-07-03)** — per the personal-use scope (3-4 devices, relay push dormant due to Apple Developer status), abuse/DoS/cost-amplification is negligible. Decision: accept for now; add a Cloudflare native rate-limiting rule (config, no code) **only if the relay is ever made public**. See memory `aruba-central-usage-scope`.

### R-9 — No unregister; APNs 410 ignored — **Low** — Confirmed
**Evidence:** No delete route in the router; `apns.ts:82` returns `{ ok, status }` but `index.ts:81-83` (`Promise.allSettled`) discards it, so a `410 Unregistered` never prunes the token. Stale tokens accumulate forever (compounds R-4).
**Remediation:** Add an unregister endpoint and prune on `410` (and `400 BadDeviceToken`) responses from APNs.

**✅ REMEDIATED (2026-07-03)** — the webhook fan-out now inspects each `sendPush` result and calls `deleteToken` on `410`/`400`; a new authenticated `POST /unregister` route (X-App-Secret, token-shape validated) lets a device remove its token. Guarded by `relay/test/token-hygiene.test.ts` (6 tests: 410/400 prune, 200 keep, unregister with/without auth, malformed token). Suite: **60/60**.

### R-10 — No app-level body-size guard — **Low** — Confirmed-code / Needs-runtime
**Evidence:** `index.ts:18` and `:58` call `request.json()` with no size/depth check. Cloudflare imposes a platform request-size ceiling, but there is no explicit application guard, and a large-but-under-limit body still forces a full parse.
**Remediation:** Check `Content-Length` and reject oversized bodies early; cap parsed field sizes. Quantify Worker limits at runtime in Phase 2.

**✅ REMEDIATED (2026-07-03)** — `readLimitedText` fast-paths on `Content-Length` then enforces on the actual body length, rejecting >16 KB with **413** before `JSON.parse`, on all three POST routes. Guarded by `relay/test/body-size.test.ts` (register/webhook/unregister oversized → 413; normal → 200). Suite: **60/60**.

### R-11 — No CORS/OPTIONS handling; minimal verb/path model — **Low** — Confirmed
**Evidence:** `index.ts:91-102` — only `POST /register` and `POST /webhook`; everything else (incl. `OPTIONS`) returns `404`. No hidden routes (good), but no explicit CORS policy. Confirm behavior with `ffuf`/`nuclei` in Phase 2.
**Remediation:** Decide CORS posture explicitly (these are server-to-server + app endpoints; likely no CORS needed — return 405 for wrong verbs to be unambiguous).

### R-12 — Secret management posture — **Low / Info** — Confirmed
**Evidence:** `relay/wrangler.toml` contains only `APNS_BUNDLE_ID` and `APNS_ENVIRONMENT="development"` under `[vars]`; `APNS_PRIVATE_KEY` and `WEBHOOK_SECRET` are **not** in the toml (expected as Worker secrets — good). Git-history grep found **no** committed `.p8`, private-key PEM body, or `client_secret` value (only source code and a test-only `generateTestP8()` runtime generator). `.dev.vars` was never committed. **Corroborated by `gitleaks detect` (RUN 2026-07-03): 91 commits / ~911 KB scanned, "no leaks found."**
- The KV `id = "2f6cbcafd95542358bd3e5f9b5294792"` (and `preview_id`) is in the toml (`wrangler.toml:7-8`). A KV namespace id is an account-scoped identifier, not a credential (it is useless without Cloudflare account auth), so **low sensitivity** — but per rules of engagement, Phase 2 must deploy to a **separate** namespace, never this production id.
- `APNS_ENVIRONMENT="development"` must flip to `production` for a prod build.
**Remediation:** Keep `.p8`/webhook secret as Worker secrets (confirmed). Document the prod-vs-lab namespace + `APNS_ENVIRONMENT` switch. No secret rotation required from history findings.

### R-13 — APNs JWT regenerated per-push per-token — **Low** — Confirmed
**Evidence:** `apns.ts:66-67` — `sendPush` calls `importAPNsKey` + `makeAPNsJWT` on **every** send; `index.ts:82` maps `sendPush` over all eligible tokens, so a fan-out imports the key and signs a fresh JWT N times. Apple recommends reusing a provider JWT (valid ~20–60 min) and can return `429 TooManyProviderTokenUpdates` for excessive regeneration.
**Remediation:** Import the key and mint the JWT once per webhook invocation (or cache ~50 min) and reuse across all sends.

---

## App (SwiftUI client) — §4 / §1 / §2 / §3 / §5 / §6

### A-1 — Force-unwraps in `buildRequest` → client-side crash DoS — ~~Medium~~ **Low** — **REFUTED on the deployment target (runtime evidence)**
**Evidence:** `ArubaCentral/Core/API/CentralAPIClient.swift:40,42`
```swift
var components = URLComponents(string: base + normalizedPath)!   // line 40
var request = URLRequest(url: components.url!)                    // line 42
```
**Phase-1 hypothesis (from static read):** `URLComponents(string:)` returns `nil` for spaces/control chars/unpaired `%`, so a malformed server-supplied `serial` traps the `!` → remote DoS.

**Runtime finding (REFUTED):** the app's `IPHONEOS_DEPLOYMENT_TARGET` is **26.5** (not "iOS 16+" as the project notes stated). iOS 26.5 ships the new **swift-foundation** URL parser, which is lenient — it lazily percent-encodes and returns a **non-nil** value for every hostile input tested. Verified two ways:
- Command-line probe (Xcode 26 toolchain): 18 hostile serials (space, tab, newline, `\u{7f}`, null, unpaired `%`, `%zz`, `#`, `?`, `[]`, `^`, backtick, braces, pipe, `<>`, quote, backslash, mid-path space) → **all built without nil**.
- XCTest `test_A1_refuted_malformedSerialsDoNotTrapOnDeploymentTarget` (iOS 26.5 Simulator) → **passes**: none of these trap.

On older Foundation (iOS ≤ 18) the space case *would* have crashed, but this app does not target those OSes. **A-1 is not an exploitable crash on the supported runtime.**
**Residual (Low):** the force-unwrap is still non-idiomatic and would resurface as a crash if the deployment target is ever lowered. **The raw interpolation remains an injection vector regardless — see A-2 (unaffected by this re-grade).**
**Remediation (defensive, de-prioritised):** still worth replacing the `!` with guarded construction that `throw`s `APIError`; primary value now is enabling A-2's percent-encoding fix, not crash-prevention.
**Process note:** the project memory `project-aruba-central.md` records "iOS 16+", which is stale vs the pbxproj (26.5). Worth correcting to avoid future mis-analysis.

### A-2 — Path injection via raw `serial` — **Medium** — Confirmed-code / Needs-runtime
**Evidence:** `CentralAPIClient.swift:198,203,208-217,242,247,253,259,300,306,312` — `serial` is interpolated raw into paths, e.g. `"/network-monitoring/v1/aps/\(serial)"` and, critically, into **action** endpoints `/network-troubleshooting/v1alpha1/aps/\(serial)/reboot` and `…/disconnect-clients`. The `buildRequest` comment (lines 33-34) deliberately avoids `appendingPathComponent` to skip percent-encoding, so a `serial` containing `/`, `?`, `#`, or `../` can alter the path or append a query string, potentially redirecting the app's Bearer token to a different (possibly destructive) endpoint.
**Note:** Serials come from server data, so exploitability requires a malicious/MITM'd API response; live impact against New Central needs Phase-2/6 runtime testing.
**Remediation:** Percent-encode each interpolated path segment with `addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)` minus `/`, or validate serial against an expected charset (`^[A-Za-z0-9._-]+$`) before use. Keep multi-segment *literals* in code, encode only the variable.

### A-3 — OData filter injection via raw `site` — **Medium** — Confirmed-code / Needs-runtime
**Evidence:** `CentralAPIClient.swift:190,234` — `filters.append("siteName eq '\(site)'")`. A `site` value containing `'` breaks out of the OData string literal (e.g. `foo' or siteName ne 'x`), potentially widening the server-side query or forcing a 400. The filter string itself is passed as a `URLQueryItem` (so it is transport-encoded correctly), but the **injection is into the filter grammar**, not the URL.
**Remediation:** Escape single quotes per OData (`'` → `''`) or reject site values containing quotes; ideally validate against the known site list. Confirm New Central's filter parser behavior in Phase 2.

### A-4 — Unbounded pagination loops — **Medium** — Confirmed
**Evidence:** `CentralAPIClient.swift:366-397` — `fetchAllPages_APs/_Switches/_Clients` all `repeat { … } while cursor != nil` with **no page or element cap**. A hostile or buggy `next` cursor that never terminates causes an infinite fetch loop / unbounded memory growth. (Contrast `fetchAPClients` at lines 208-225, which correctly caps at 5 pages.)
**Remediation:** Add a hard cap (e.g. max 50 pages or N elements) to all three paginators; break and surface a partial-result/error when exceeded.

### A-5 — Query-param smuggling via `next`/`search` — **Low** — **Refuted (safe)**
**Evidence:** `CentralAPIClient.swift:188,215,232,269,282` — `next`, `limit`, and `search` are passed as `URLQueryItem` values; `URLComponents.queryItems` percent-encodes `&`, `=`, `#` in values. A server-supplied `next` cursor therefore **cannot** smuggle additional query parameters. The plan's hypothesis is disproven; this path is safe as written. (The residual risk is A-1, where a value invalid enough to make `components.url` nil crashes rather than smuggles.)
**Remediation:** None required. Keep using `URLQueryItem`; do not switch to manual query-string concatenation.

### A-6 — Keychain accessibility not `ThisDeviceOnly` — **Medium** — Confirmed
**Evidence:** `Core/Keychain/KeychainManager.swift:33,46` — both `save` and `retrieve` use `kSecAttrAccessibleWhenUnlocked`. There is no `kSecAttrAccessControl`/`LAContext`. Consequently the `clientSecret` (a long-lived, tenant-wide OAuth credential) and `accessToken` are **eligible for iCloud Keychain sync and device backups** and readable by the app whenever the device is merely unlocked.
**Remediation:** Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` at minimum (blocks backup/sync egress). For the `clientSecret` specifically, consider `SecAccessControlCreateWithFlags(..., .biometryCurrentSet)` to gate reads behind biometrics.
*(Backup-egress and biometric-gating behavior to be proven at runtime in Phase 3.)*

**✅ REMEDIATED (2026-07-03)** — `KeychainManager.save` now uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; the `kSecAttrAccessible` line was removed from `retrieve`'s query so reclassified items still resolve. Guarded by `StorageSecurityTests` (asserts ThisDeviceOnly for secret + token, plus a save/retrieve round-trip). Verified no regression: 24/24 across Storage/Keychain/AuthToken/AuthSecurity classes. Biometric gating on the secret intentionally **not** applied (would break silent token refresh) — accepted per personal-use scope.

### A-7 — No single-flight token refresh → refresh stampede — **Medium** — Confirmed
**Evidence:** `AuthTokenManager.swift:18-26` (`validToken`) and `29-63` (`fetchNewToken`) have no coalescing lock. `searchDevices` (`CentralAPIClient.swift:343-364`) fans out three paginators concurrently via `async let`; on an expired token each concurrently calls `validToken()` → `fetchNewToken()`, producing a thundering herd of token POSTs to `sso.common.cloud.hpe.com` plus racing keychain writes (`save(.accessToken)`/`save(.tokenExpiry)` at lines 58-59). Risk: OAuth rate-limit/lockout and inconsistent stored token/expiry.
**Remediation:** Serialize refresh with an actor-based single-flight: if a refresh is in progress, await the same `Task`; only one network call per expiry window.

### A-8 — `isAuthenticated` reflects presence, not validity — **Low** — Confirmed
**Evidence:** `AuthTokenManager.swift:15` — `isAuthenticated = (try? keychain.retrieve(for: .accessToken)) != nil`. "Authenticated" means "a token string exists," so a garbage/expired token still presents an authenticated UI until the first 401. Security-signal/UX mismatch, low impact.
**Remediation:** Treat auth state as "has valid, unexpired token" or reconcile on launch with a lightweight `validToken()`/`testConnection()`; downgrade UI on 401/`sessionExpired`.

### A-9 — DEBUG preview bypass compiled out of Release — **Info** — Confirmed (clean)
**Evidence:** `ArubaCentralApp.swift:50-59` — the `-PreviewMode`/`PreviewRootView()` entry is inside `#if DEBUG … #else rootView #endif`, so it is absent from Release builds. Plan §6.4 hypothesis holds: **no** preview bypass ships. No action.

### A-10 — ATS and URL-scheme posture clean — **Info** — Confirmed (clean)
**Evidence:** `Info.plist` contains no `NSAppTransportSecurity`/`NSAllowsArbitraryLoads` (ATS defaults ON) and no `CFBundleURLSchemes` (no custom deep-link entry points). Plan §3.2/§5.6 hold. **Assert this stays clean** in build settings as Push/Task-6 lands.

### A-11 — Client secret rendered in plain `TextField` — **Low** — Confirmed-code / Needs-runtime
**Evidence:** `Features/Settings/SettingsView.swift:45-51` — when `showingClientSecret` is true the secret renders in a plain `TextField` (the hidden state correctly uses `SecureField`). There is no `scenePhase`-driven privacy overlay, so the app-switcher snapshot may capture the plaintext secret while revealed.
**Remediation:** Obscure sensitive views on `scenePhase == .inactive/.background` (blur/redaction overlay). Snapshot capture to be reproduced at runtime in Phase 3/5.

---

## Supply chain & build config — §8

### B-1 — Relay dependency audit — **Info** — Confirmed (clean)
**Evidence:** `npm audit` in `relay/` → **0 vulnerabilities** (info/low/moderate/high/critical all 0). **Corroborated by `osv-scanner --lockfile relay/package-lock.json` (RUN 2026-07-03): 160 packages scanned, "No issues found."** Both agree: no known-vulnerable dependencies in the relay toolchain.

### B-2 — `.gitignore` under-covers sensitive artifacts — **Low** — Confirmed
**Evidence:** `.gitignore` contains only `.superpowers/`. It does **not** ignore `*.p8`, `.dev.vars`, `DerivedData/`, or `xcuserdata/`. Currently `ArubaCentral.xcodeproj/xcuserdata/joshuaebibbs.xcuserdatad/…/xcschememanagement.plist` **is tracked** (hygiene, not a secret). The gap means a future `.p8` or `.dev.vars` could be committed accidentally.
**Remediation:** Add `*.p8`, `.dev.vars`, `relay/.dev.vars`, `**/xcuserdata/`, `DerivedData/`, `build/` to `.gitignore`; `git rm --cached` the tracked xcuserdata plist.

### B-3 — Empty entitlements — **Info** — Confirmed (expected)
**Evidence:** `ArubaCentral/ArubaCentral.entitlements` is an empty `<dict/>`. No `keychain-access-groups` (so no unintended keychain sharing — good) and no `aps-environment` yet (expected: Push/Task-6 is still blocked per project notes). When Push lands, add `aps-environment` correctly and confirm the default keychain access group.

---

## Static tooling — all run 2026-07-03

Summary of automated corroboration (all four plan-mandated tools now installed and run):

| Tool | Command | Result | Corroborates |
|------|---------|--------|--------------|
| `npm audit` | `npm audit` in `relay/` | 0 vulnerabilities | B-1 |
| `osv-scanner` | `osv-scanner --lockfile relay/package-lock.json` | 160 packages, no issues | B-1 |
| `gitleaks` | `gitleaks detect --source . --redact -v` | 91 commits, no leaks | R-12 / §8.2 |
| `semgrep` | `--config p/typescript --config p/swift --config p/secrets .` | 0 findings (thin rule coverage) | no anti-pattern deps/secrets — does NOT refute manual findings |

**Key caveat:** the 3× "0 findings / clean" scanner results corroborate the supply-chain and secrets posture only. **None refutes any of the 22 manual findings** — every Phase-1 issue is a logic/design flaw (fail-open auth, non-constant-time compare, single-key RMW race, OData injection, unbounded pagination, keychain accessibility, URL force-unwraps) outside generic ruleset coverage.

### Custom rules (close the coverage gap)

To machine-detect the logic flaws the community packs miss, custom rules were authored at
`docs/security/semgrep-rules/aruba-custom.yml` and **validated to fire on the exact finding
lines with zero false positives** (RUN 2026-07-03: 13 matches, 0 errors):

| Rule | Finding | Matches |
|------|---------|---------|
| `relay-auth-fail-open-on-secret` | R-1 | `relay/src/index.ts:49` |
| `relay-non-constant-time-secret-compare` | R-3 | `relay/src/index.ts:51` |
| `swift-interpolated-request-path` | A-2 | `CentralAPIClient.swift` ×9 (all raw-serial path sites) |
| `swift-url-construction-force-unwrap` | A-1 | `CentralAPIClient.swift:40,42` |

Run: `semgrep --config docs/security/semgrep-rules/aruba-custom.yml .` (cwd = repo root).
Suggested CI use: run this ruleset as a blocking gate so these patterns cannot regress.
Not yet covered by a custom rule (candidates for expansion): A-3 OData filter injection,
A-4 unbounded pagination, R-4/R-5 single-key KV read-modify-write.

Commands for reproduction (**cwd = repo root `ArubaCentral/`**; adjust if run from outer `XCodeProj/`):

# Semgrep — RUN 2026-07-03: `--config p/typescript --config p/swift --config p/secrets`
#   Result: 0 findings. 38 rules ran across 68 files (only 2 Swift rules).
#   Interpretation: corroborates "no committed secrets / no anti-pattern deps," but does
#   NOT refute any manual finding — every Phase-1 issue is a logic/design flaw (fail-open
#   auth, non-constant-time compare, single-key RMW, OData injection, unbounded pagination,
#   keychain accessibility, URL force-unwraps) that community rulesets do not cover. The
#   thin p/swift pack has no force-unwrap-in-URL rule, so A-1 was not machine-flagged.
#   Recommend `semgrep login` for expanded registry rules + custom rules for these patterns.

```bash
# Semgrep — Swift + TypeScript source rules (§8.5)
brew install semgrep   # or: pipx install semgrep
semgrep --config p/typescript --config p/swift --config p/secrets .

# osv-scanner — dependency CVEs, cross-checks npm audit (§8.1)
brew install osv-scanner
osv-scanner --lockfile relay/package-lock.json

# gitleaks — full-history secret scan (§8.2)
brew install gitleaks
gitleaks detect --source . --redact -v

# MobSF — static triage of the built IPA (§8.5) — requires an archived .ipa (Phase 2+)
```
Manual substitutes already run: `npm audit` (0 vulns, B-1) and a git-history grep for `.p8`/PEM/`client_secret` (no committed secrets, R-12).

---

## Remediation status (as of 2026-07-03)

**Assessment + remediation complete.** Every High/Medium finding in scope is fixed and test-guarded; the rest are accepted with rationale under the personal-use scope (`aruba-central-usage-scope`).

**Fixed (17):** R-1, R-2, R-3, R-4, R-5, R-6, R-7, R-9, R-10 (relay); A-1, A-2, A-3, A-4, A-6, A-7, A-8, A-11, N-2-residual (app). *(A-11 is code-verified; snapshot behavior warrants one manual check.)*
**Accepted / deferred (with rationale):** R-8 (rate limiting), N-1 (TLS pinning), §6 (resilience) — accepted at personal scale; R-11, R-13, R-12 — deferred while the relay push path is dormant.
**Refuted at runtime (no action):** A-1 crash (iOS 26.5 Foundation), A-5 (URLQueryItem), N-2 region-SSRF (allowlist).
**Test coverage:** relay 60/60 (vitest); app 185/185 (XCTest). Security tests were inverted to assert the hardened behavior and now serve as regression guards.

---

## Phase 2 — Relay black-box (local isolation) runtime results

**Date:** 2026-07-03 · **Target:** local `wrangler dev` (workerd/miniflare) on `127.0.0.1:8787`, KV in `local` mode — **production KV untouched**, no internet exposure, disposable lab secret passed via `--var`. Scripts + runbook: `<scratchpad>/phase2/`. Two server modes: **A** = `WEBHOOK_SECRET` set, **B** = unset.

| ID | Prior status | Runtime result | Evidence |
|----|--------------|----------------|----------|
| R-1 | Confirmed (code) | **CONFIRMED (runtime)** | Mode B (secret unset): no-header `POST /webhook` → **`200 {"ok":true,"recipients":157}`** — fanned out to all registered devices unauthenticated. Mode A control: no-header & wrong-secret → `403`, correct secret → `200`. |
| R-2 | Confirmed (code) | **CONFIRMED (runtime)** | `POST /register` with no auth → `200 {"ok":true}`. |
| R-7 | Confirmed (code) | **CONFIRMED (runtime)** | Garbage `device_token`s all accepted `200`: `not-a-real-token`, `../../etc/passwd`, `tok%0d%0ainjected` (CRLF), 500-char string. No shape validation. |
| R-6 | Confirmed (code) | **CONFIRMED (runtime)** | Phishing title *"Security Alert: tap to re-authenticate…"* → `200`; 5000-char title → `200` (no length cap). *(Note: the control-char case returned `400 Invalid JSON` — a shell UTF-8 encoding artifact before the request, **not** a relay defense; [1]/[2] already prove the finding.)* |
| R-8 | Confirmed (code) | **CONFIRMED (runtime)** | 100 rapid `/register` hits → **0** rejected. No throttling. |
| R-10 | Confirmed-code / Needs-runtime | **CONFIRMED (runtime)** | 1 MB `device_token` → `200` accepted (**took 1.05 s** — latency signal, feeds R-4); 5000-deep nested JSON fully parsed then `400 Missing device_token`. No early `413`, no app-level size/depth guard. |
| R-11 | Confirmed (code) | **CONFIRMED (runtime)** | Wrong verbs (`GET`/`PUT`/`DELETE`) on both routes → `404` (not `405`); `OPTIONS` → `404` with **no `Access-Control-Allow-Origin`** header; 9 hidden-route probes (`/admin`,`/unregister`,`/tokens`,`/..%2f`,…) all `404`. No hidden routes, no CORS. |

**End-to-end chain demonstrated:** R-2 (register 157 arbitrary/junk tokens unauthenticated) → R-1 (unauthenticated `/webhook` in Mode B pushes to all 157). This is the full spoofed-push-to-all-devices attack, reproduced locally.

**Not exercised (need remote / real APNs), unchanged from Phase 1:** R-4/R-5 (real eventually-consistent KV race & scale — local miniflare KV is strongly consistent), R-9/R-13 (real APNs 410 pruning & per-push JWT). The 1.05 s latency on a single 1 MB write is a local lower-bound hint toward R-4 but does not quantify the production case.

**Owner decision (2026-07-03):** remote isolated deployment **declined for now**. R-4, R-5, R-9, R-13 therefore remain **Confirmed by code review** (all four are unambiguous in source — single-key read-modify-write, non-atomic write, no 410 handling, per-push JWT); only their production-scale *quantification* is deferred. Remediation priority is unchanged. Revisit with a short-lived isolated Worker + KV + throwaway `.p8` if quantification is later required.

**Isolation confirmed:** binding table reported `KV Namespace … local`; both dev servers were torn down (`port 8787 free`) after the run. No production resources, credentials, or live tenant were touched.

---

## Phase 3 — §4 app-side input validation (XCTest harness) results

**Date:** 2026-07-03 · **Target:** `CentralAPIClient` under XCTest on **iOS 26.5 Simulator** (iPhone 17), via `MockURLProtocol` request capture. Harness: `ArubaCentralTests/Core/API/InputValidationSecurityTests.swift` (8 tests, **all passing**). No production code modified.

| ID | Prior status | Test result | What the test proves |
|----|--------------|-------------|----------------------|
| A-1 | Confirmed (code, Medium) | **REFUTED → Low** | On iOS 26.5, malformed serials do not make `URLComponents`/`.url` nil → force-unwraps don't trap. Crash DoS does not reproduce on the deployment target (see A-1 detail). |
| A-2 | Confirmed-code | **CONFIRMED (runtime)** | `serial="REAL?injected=evil"` → request `query == "injected=evil"`; `rebootAP(serial:"REAL/extra/segment")` → path `/aps/REAL/extra/segment/reboot`; `serial="REAL?x=y"` → `/reboot` suffix absorbed into query, path collapses to `/aps/REAL`. Raw serial injects path/query into destructive endpoints. |
| A-3 | Confirmed-code | **CONFIRMED (runtime)** | `site="x' or siteName ne 'y"` → decoded `filter` = `siteName eq 'x' or siteName ne 'y'`; the unescaped quote broke out of the OData literal. |
| A-4 | Confirmed (code) | **CONFIRMED (runtime)** | With a server returning a fresh `next` for 250 pages, the 3 paginators followed **≥750** pages with no client-side cap (vs `fetchAPClients`'s cap of 5). A never-null cursor → infinite loop / memory-exhaustion DoS. |
| A-5 | Refuted (code) | **REFUTED confirmed (runtime)** | `next="cursor with space"` did not crash and came out percent-encoded (`cursor%20with%20space`) — `URLQueryItem` prevents smuggling. |

**Net effect on the backlog:** A-1 drops from Medium→Low (defensive-only), but A-2 (path/query injection into `reboot`/`disconnect` endpoints) and A-3 (filter injection) are now **runtime-proven** — the "encode path segments + escape filter literals" remediation is the same and is now the top *app-side* priority. A-4's pagination cap is confirmed needed.

**✅ REMEDIATED (2026-07-03):** `CentralAPIClient` now percent-encodes serial path segments via `pathSegment()` (A-2), escapes OData single quotes via `odataEscaped()` (A-3), caps the search paginators at `maxSearchPages = 50` (A-4), and `buildRequest` uses guarded `URLComponents`/`.url` (drops the A-1 force-unwraps; new `APIError.invalidRequest`). The §4 tests were **inverted** to assert the hardened behavior: A-2 (encoded `%3F`/`%2F`, no query/path smuggling, `/reboot` preserved), A-3 (quotes doubled), A-4 (stops at 3×50=150 pages). Verified: 8/8 InputValidationSecurityTests + 11/11 CentralAPIClientTests, no regression.

### §2 auth harness (`AuthSecurityTests.swift`, 3 tests, all passing)

| ID | Prior status | Test result | What the test proves |
|----|--------------|-------------|----------------------|
| A-7 | ✅ REMEDIATED | **CONFIRMED → FIXED** | Was: 10 concurrent `validToken()` → >1 token POSTs. Now: `fetchNewToken` coalesces via a MainActor-isolated in-flight `refreshTask`, so 10 concurrent refreshes → exactly **1** fetch. Test inverted to assert `hits == 1`. |
| A-8 | Confirmed (code) | **CONFIRMED (runtime)** | A garbage `accessToken` string → `isAuthenticated == true` (presence, not validity). Control: no token → `false`. |

### §1 storage harness (`StorageSecurityTests.swift`, 2 tests, all passing)

| ID | Prior status | Test result | What the test proves |
|----|--------------|-------------|----------------------|
| A-6 | Confirmed (code) | **CONFIRMED (runtime)** | Read the persisted `kSecAttrAccessible` for `clientSecret` and `accessToken` → both equal `kSecAttrAccessibleWhenUnlocked`, not `...ThisDeviceOnly`. Secrets are backup/iCloud-sync-eligible. (1.7 residue-after-logout already covered by `testClearCredentialsRemovesAllKeys`.) |

### §3 network harness (`NetworkSecurityTests.swift`, 2 tests, all passing)

| ID | Prior status | Test result | What the test proves |
|----|--------------|-------------|----------------------|
| N-2 (3.5) | Low / Needs-runtime | **REFUTED (runtime)** | 7 hostile `selectedRegionId` values (rogue URLs, `' OR '1'='1`, empty, wrong-case) all resolve to an **allowlisted https** region via `CentralRegion.all.first{…} ?? defaultRegion`. Region-SSRF via UserDefaults is not possible. **Residual (Low, defense-in-depth):** `CentralAPIClient.updateBaseURL(_:)` still accepts any `URL`; no attacker-controlled URL reaches it today, but it should validate against the allowlist. |
| N-1 (3.1) | — | **Confirmed (code)** | No `URLSessionDelegate`/pinning anywhere; `URLSession.shared` throughout. Not unit-testable — needs a MITM proxy (mitmproxy not installed) to demonstrate interception. Remediation drafted regardless. |

---

## Phase 1 conclusion

- **All five top pre-flagged High/Medium hypotheses CONFIRMED** against current code: R-1 (webhook fail-open), R-2 (unauth register), R-4/R-5 (single-key KV + race), A-1 (force-unwrap DoS), A-6 (keychain not `ThisDeviceOnly`).
- **One hypothesis REFUTED (good news):** A-5 — `next`/`search` use `URLQueryItem`, so query-param smuggling is not possible as written.
- **Clean/expected (no action or assert-stays-clean):** A-9 (DEBUG bypass), A-10 (ATS/URL schemes), B-1 (deps), B-3 (entitlements), and secrets-in-history (R-12).
- **New finding not separately pre-flagged:** R-13 (per-push JWT regeneration).

**Highest-priority remediation (when the fix phase begins):** fail-closed webhook auth + constant-time compare (R-1/R-3), authenticate `/register` (R-2), redesign KV to per-token keys (R-4/R-5), drop the `buildRequest` force-unwraps + encode path segments (A-1/A-2), and switch the keychain secret to `…ThisDeviceOnly` + access-control (A-6).
```
