# ArubaCentral — Security Test Plan

**Date:** 2026-07-03
**Scope:** ArubaCentral iOS app (SwiftUI, iOS 16+) + `relay/` Cloudflare Worker (webhook → APNs).
**Objective:** Discover vulnerabilities and produce a prioritized hardening backlog.
**Framework alignment:** OWASP MASVS 2.x / MASTG (mobile), OWASP ASVS + API Top 10 (relay backend).

> **Status: PLAN ONLY — no tests executed yet.** This document defines what to test,
> how, with which tools, and the expected/likely finding based on a static read of the
> current code. Each test cites the code location that motivates it.

---

## 0. Rules of engagement & prerequisites

Before any test runs:

- **Authorization:** This is the owner's own app and self-hosted relay. Confirm the Aruba
  Central tenant used for testing is a **non-production / lab tenant** with disposable API
  client credentials. Never test reboot/disconnect actions against production network gear.
- **Isolation:** Deploy the relay to a **separate Cloudflare Worker + KV namespace** (not the
  production `id` in `wrangler.toml`) so token-flooding tests don't poison real device tokens.
- **Test data:** Generate throwaway OAuth `client_id`/`client_secret`. Rotate/revoke after.
- **Devices:** One **jailbroken** device or iOS Simulator for filesystem/keychain inspection,
  plus one stock device for behavioral tests.
- **Build:** Test a **Release** build for platform/storage tests (DEBUG preview hooks and
  assertions change behavior); use Debug only for instrumented crash reproduction.
- **Environment capture:** Record app version/build, iOS version, and relay
  `compatibility_date` so findings are reproducible.

**Toolbox:** Frida / Objection, Burp Suite or mitmproxy, Xcode Instruments + Console.app,
`security`/`plutil`, iMazing or `idevicebackup2` (backup extraction), Hopper/Ghidra (optional),
`class-dump`/`otool`/`nm`, MobSF (static triage), `nuclei`/`ffuf` + `curl` (relay), `semgrep`
(source rules), `npm audit` / `osv-scanner` (relay deps).

---

## 1. Credential & sensitive-data storage (MASVS-STORAGE)

**Why:** The app stores `clientId`, `clientSecret`, `accessToken`, `tokenExpiry`, and `region`
in the Keychain via `KeychainManager` (`Core/Keychain/KeychainManager.swift`). The client
secret is a long-lived, high-value credential (full OAuth client-credentials grant to the
tenant). Storage accessibility class and access control are the crux.

| # | Test | Method | Motivating code | Expected/likely finding |
|---|------|--------|-----------------|--------------------------|
| 1.1 | Keychain accessibility class | Dump keychain item attributes (Frida/`SecItemCopyMatching` or jailbroken keychain dumper); confirm `kSecAttrAccessible` value | `KeychainManager.save` uses `kSecAttrAccessibleWhenUnlocked` (lines 33, 46) | Secrets are **backup-eligible and iCloud-Keychain-sync-eligible**. Not `...ThisDeviceOnly`. Recommend `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` at minimum. |
| 1.2 | Secret in device backup | Take an unencrypted + encrypted `idevicebackup2` backup; search for the secret/token | same as 1.1 | Because items are not `ThisDeviceOnly`, verify whether secret leaves the device via backup. |
| 1.3 | No biometric / access-control gating | Attempt to read items with device merely unlocked; check for `kSecAttrAccessControl` / `LAContext` | `save`/`retrieve` set no `kSecAttrAccessControl` | Any process with the app's entitlements (or on a jailbroken device, any root process) can read the secret while unlocked. Consider `SecAccessControlCreateWithFlags(.biometryCurrentSet)` for the secret. |
| 1.4 | Keychain access group / sharing | Inspect entitlements for keychain-access-groups | `ArubaCentral.entitlements` is currently empty | Confirm no unintended sharing; confirm the default access group is correct once Push entitlement is added. |
| 1.5 | Plaintext-at-rest elsewhere | Grep app sandbox (`Documents`, `Library`, `Caches`, `tmp`, `UserDefaults` plist) for `client`, `secret`, `Bearer`, token substrings | `UserDefaults` stores `selectedRegionId`, `appearance` (`ArubaCentralApp.swift`, `SettingsView`) — confirm no secret leaks there | UserDefaults should contain **no** credentials. Verify. |
| 1.6 | `URLCache` / response caching | After browsing devices/clients, inspect `Library/Caches` for cached API responses containing client PII (MACs, IPs, usernames) | `URLSession.shared` default cache | Telemetry with client PII may persist in the on-disk URL cache. Consider `.ephemeral` session or `URLCache` disabled. |
| 1.7 | Keychain residue after logout | Call `clearCredentials()` path, then dump keychain | `AuthTokenManager.clearCredentials` / `KeychainManager.clearAll` iterate `Key.allCases` | Confirm **all** five keys are actually removed (no orphaned token). |

---

## 2. Authentication, token & session management (MASVS-AUTH)

**Why:** OAuth2 client-credentials flow in `AuthTokenManager`. Token lifetime/refresh logic and
the meaning of "authenticated" affect account-takeover and stale-session risk.

| # | Test | Method | Motivating code | Expected/likely finding |
|---|------|--------|-----------------|--------------------------|
| 2.1 | Token-expiry trust | Manipulate the stored `tokenExpiry` keychain value (set far future) and observe whether app uses an expired/invalid token | `validToken()` trusts locally-stored expiry string (`AuthTokenManager.swift:18-26`) | App relies on client-side clock + stored expiry. A tampered expiry forces reuse of a dead token → handled server-side (401 → refresh), but verify no infinite-loop / lockout. |
| 2.2 | 401 refresh loop | Force repeated 401s (revoke token server-side) and watch `retryAfterRefresh` | `CentralAPIClient.retryAfterRefresh` refreshes once then retries | Confirm bounded retries (no unbounded recursion / credential hammering that could lock the OAuth client). |
| 2.3 | `isAuthenticated` correctness | Put a garbage `accessToken` in keychain, launch app | `init` sets `isAuthenticated = (retrieve(.accessToken) != nil)` (line 15) | "Authenticated" == "a token string exists," not "token is valid." UI may present an authenticated state with an unusable token. Low severity but note UX/security signal mismatch. |
| 2.4 | Credential-in-memory scraping | Frida-hook `fetchNewToken`; dump `clientSecret`/token from process memory | secret read into local at `AuthTokenManager.swift:30-31` | Expected on jailbroken device. Document as accepted risk unless anti-tamper is in scope. |
| 2.5 | Token endpoint request integrity | mitmproxy the token POST | body built at lines 33-43 | Confirm secret only ever goes to `sso.common.cloud.hpe.com` over TLS, form-encoded, POST body (not URL/query where it could hit logs). Confirmed by read; verify at runtime. |
| 2.6 | Concurrent-refresh race | Trigger many parallel API calls after expiry (search fans out `fetchAllPages_*` concurrently) | `searchDevices` runs 3 concurrent paginators; each may call `validToken()`/`fetchNewToken()` | Possible **thundering-herd of token refreshes** (no single-flight lock). May trip OAuth rate limits and/or race keychain writes. Recommend an actor-serialized single-flight refresh. |

---

## 3. Network communication / transport security (MASVS-NETWORK)

**Why:** All telemetry, actions, and the OAuth secret exchange happen over HTTPS via
`URLSession.shared`. No pinning is present.

| # | Test | Method | Motivating code | Expected/likely finding |
|---|------|--------|-----------------|--------------------------|
| 3.1 | TLS interception / no cert pinning | Install a proxy CA, MITM app traffic with Burp/mitmproxy | `URLSession.shared` everywhere; no `URLSessionDelegate` pinning | **No certificate/public-key pinning.** With a trusted proxy CA, all traffic (incl. token exchange, device actions) is interceptable. Recommend pinning `*.arubanetworks.com`, `sso.common.cloud.hpe.com`, and the relay host. |
| 3.2 | ATS posture | Inspect built app `Info.plist` for `NSAppTransportSecurity` overrides | Current `Info.plist` has no ATS keys (ATS defaults ON) | Confirm no `NSAllowsArbitraryLoads` or per-domain exceptions slipped in via build settings. Currently clean — assert it stays clean. |
| 3.3 | Cleartext fallback | Point `baseURL` / region at an `http://` origin (via manipulated `selectedRegionId` or a rogue region) and observe | `CentralRegion.all` are all `https://`; `updateBaseURL` accepts any `URL` | Verify no code path allows a non-TLS base URL; ATS should block it regardless. |
| 3.4 | Relay endpoint transport | Confirm the app talks to the relay only over HTTPS | (relay URL config — locate device-registration call once Push task 6 lands) | Ensure device-token registration to the relay is TLS + pinned. |
| 3.5 | Proxy-awareness / SSRF via region | Assess whether a compromised `selectedRegionId` in UserDefaults can redirect API calls | `ArubaCentralApp.init` reads region from UserDefaults unauthenticated | UserDefaults is attacker-writable on a jailbroken device/backup restore → could aim the client (and its Bearer token) at an attacker host. Validate region against an allowlist at use-time. |

---

## 4. Input validation & injection (MASVS-CODE)

**Why:** `CentralAPIClient.buildRequest` composes URLs by **string concatenation** with
**force-unwraps**, and interpolates `serial`, `site`, `search`, and pagination `next` cursors
directly into paths, filters, and query values. Serials/site names/cursors originate from
server data and (via search/settings) user input.

| # | Test | Method | Motivating code | Expected/likely finding |
|---|------|--------|-----------------|--------------------------|
| 4.1 | Force-unwrap crash / DoS | Drive a `serial`/`site`/`next` value containing characters that make `URLComponents(string:)` or `.url` return nil (spaces, `#`, `%`, control chars, unpaired `%`) | `buildRequest` force-unwraps `URLComponents(string: base + normalizedPath)!` and `components.url!` (`CentralAPIClient.swift:40,42`) | **Client-side crash (DoS) on malformed input.** A malicious/misconfigured API response with an exotic `next` cursor or serial can crash the app. Replace force-unwraps with safe construction + error. |
| 4.2 | Path injection | Craft `serial` = `../../network-config/v1/...` or containing `?`/`#`/`/` and observe resulting request | detail endpoints interpolate raw `serial`: `/aps/\(serial)`, `/switches/\(serial)/interfaces`, reboot/disconnect actions (lines 197-315) | Because paths are concatenated (comment explicitly avoids `appendingPathComponent` percent-encoding), a serial with path separators or query chars can **alter the request path / smuggle query params** — potentially invoking a different (destructive) endpoint with the app's Bearer token. Percent-encode path segments. |
| 4.3 | Filter (OData-style) injection | Set a site name containing a single quote or ` and `/` or ` operators, e.g. `foo' or siteName ne 'x` | filters built with raw interpolation: `"siteName eq '\(site)'"` (lines 190, 234) | **Server-side filter injection**: the quote breaks out of the literal, potentially widening the query or causing 400s. Test what the New Central API does with it. Encode/escape or reject quotes. |
| 4.4 | Query-parameter smuggling via `search`/`next` | Provide `search`/`next` with `&`, `=`, `#` | `next` and `limit` passed as `URLQueryItem` (auto-encoded — good), but `search` is filtered client-side in some paths and server-side in others | Verify `URLQueryItem` encoding holds; confirm `next` cursor from the server can't smuggle extra params. |
| 4.5 | Unbounded pagination DoS | Return an API response whose `next` cursor never terminates | `fetchAllPages_*` loop `while cursor != nil` with **no page cap** (`CentralAPIClient.swift:366-397`); `fetchAPClients` is capped at 5 | A hostile/looping `next` value causes an **infinite fetch loop / memory exhaustion**. Add a hard page/element cap to all paginators. |
| 4.6 | Response decoding robustness | Feed oversized, deeply-nested, or type-confused JSON (via MITM) to each decoder | `perform` decodes with `JSONDecoder`; models in `Core/Models/*` | Check for excessive memory on huge arrays, and that `decodingError` is surfaced (not crashed). Fuzz model decoding. |
| 4.7 | Search input reflection | Enter injection/emoji/RTL/very-long strings in Global Search and Settings fields | `GlobalSearchViewModel`, `SettingsViewModel` | Confirm no crash, no layout DoS, correct handling of `localizedCaseInsensitiveContains`. |

---

## 5. Platform interaction & data leakage (MASVS-PLATFORM)

**Why:** iOS-specific leakage vectors: logs, snapshots, pasteboard, screen recording, and the
secret-reveal toggle in Settings.

| # | Test | Method | Motivating code | Expected/likely finding |
|---|------|--------|-----------------|--------------------------|
| 5.1 | Log leakage | Run Release build, monitor Console.app / unified log & crash logs while authenticating and calling APIs; grep for secret/token/MAC/IP | No `print`/`os_log` of secrets found in static read (good) — verify at runtime incl. `URLError`/Foundation logging | Confirm no framework-level logging of the Authorization header or token exchange body. |
| 5.2 | Background snapshot exposure | Background the app on the Settings screen with the secret revealed (eye toggle), inspect `Library/Caches/Snapshots` | `SettingsView` `showingClientSecret` renders the secret in a plain `TextField` (lines 45-51) | The app-switcher snapshot may capture the **plaintext client secret**. Add a privacy overlay / obscure sensitive views on `scenePhase == .inactive`. |
| 5.3 | Pasteboard exposure | Copy from the secret field; check whether general pasteboard retains it / is readable by other apps | secret field | If copy is allowed, secret lands on the (universal, unexpiring) pasteboard. Consider marking sensitive fields / no auto-copy. |
| 5.4 | Screenshot/record of secret | Reveal secret, screenshot/record | 5.2 | Document exposure; consider `isSecureTextEntry`-equivalent even in "shown" mode is impractical, but snapshot protection is. |
| 5.5 | Keyboard cache / autofill | Type into Client ID/Secret fields; check keyboard learning DB | Client ID field uses `.username` content type; secret uses `.password` + `autocorrectionDisabled` + `SecureField` (good) | Confirm `SecureField` prevents keyboard caching; confirm the *revealed* `TextField` path (5.2) also disables it. |
| 5.6 | Deep-link / URL scheme abuse | Enumerate custom URL schemes & universal links | No `CFBundleURLSchemes` found in `Info.plist` | Confirm no unauthenticated deep-link entry points once notifications land. |
| 5.7 | Notification payload sensitivity | Inspect the APNs payload rendered on the lock screen | relay `handleWebhook` builds `alert.title/body` from webhook `site_name`/`device_serial`/`description` | Network topology / device serials shown on a locked screen = information disclosure. Consider generic lock-screen text with detail behind unlock. |
| 5.8 | Third-party keyboard / accessibility | N/A unless custom — verify no `RASP`-relevant exposure | — | Low priority. |

---

## 6. Resilience & anti-tampering (MASVS-RESILIENCE)

**Why:** Optional for this app class, but relevant because the app holds a tenant-wide OAuth
secret and can reboot APs / disconnect clients.

| # | Test | Method | Expected/likely finding |
|---|------|--------|--------------------------|
| 6.1 | Jailbreak detection | Run on jailbroken device | None expected (not implemented). Decide if in scope given credential sensitivity. |
| 6.2 | Frida/debugger attach | Attach Frida/lldb to Release build | No anti-debug/anti-hook. Document as accepted or add lightweight checks. |
| 6.3 | Binary hardening | `otool`/`nm` for PIE, stack canaries, symbol stripping; check for embedded secrets in the binary | Swift default is PIE + ARC; verify Release strips symbols and that **no secret/relay URL is hardcoded** in the binary. |
| 6.4 | DEBUG hooks in Release | Confirm `#if DEBUG` preview-arg entry (`ArubaCentralApp.swift`) is compiled out of Release | Preview bypass must not exist in Release. Verify. |

---

## 7. Relay backend — Cloudflare Worker (`relay/`) (OWASP API Top 10)

**Why:** The relay (`relay/src/index.ts`, `webhook.ts`, `tokens.ts`, `apns.ts`) is the
internet-facing component. It fans push notifications out to all registered devices and holds
the APNs signing key. This is the highest-value external attack surface.

| # | Test | Method | Motivating code | Expected/likely finding |
|---|------|--------|-----------------|--------------------------|
| 7.1 | **Unauthenticated device registration** | `curl -X POST /register` with arbitrary `device_token` | `handleRegister` has **no auth** (`index.ts:15-46`) | Anyone can register arbitrary/garbage tokens → pollutes the recipient set, inflates APNs load, enables push-spam amplification. Add a shared secret / app-attestation on `/register`. |
| 7.2 | **KV token-store DoS & unbounded growth** | Register thousands of tokens; measure KV value size & latency | all tokens in **one** KV key `registered_tokens`, full read-modify-write per registration (`tokens.ts:12-33`) | Single-key JSON array grows unbounded; each register rewrites the whole blob. **DoS / cost amplification / eventual KV value-size limit breach.** Redesign to one KV key per token + list, add caps. |
| 7.3 | **Registration race / lost updates** | Fire many concurrent `/register` calls | non-atomic read-modify-write on shared key (`saveToken`) | Concurrent writes clobber each other → lost/dropped tokens. Confirm and quantify. |
| 7.4 | **Webhook auth bypass when secret unset** | Deploy with `WEBHOOK_SECRET` unset; POST `/webhook` | check is `if (env.WEBHOOK_SECRET)` — **skipped entirely if empty** (`index.ts:49-54`) | If the secret env var is missing/empty, **anyone can push arbitrary notifications** to all devices (phishing/spoofed alerts). Fail closed: reject if secret not configured. |
| 7.5 | **Timing attack on webhook secret** | Statistical timing analysis of `X-Webhook-Secret` comparison | `provided !== env.WEBHOOK_SECRET` — non-constant-time (`index.ts:51`) | Byte-by-byte string compare leaks length/prefix. Use constant-time compare (e.g. `crypto.subtle` digest compare). |
| 7.6 | **Push-content injection / phishing** | POST `/webhook` with attacker-controlled `name`/`description`/`site_name` | `parseWebhook` copies fields straight into `title`/`body` (`webhook.ts:30-48`); no length/charset limits | Attacker crafts convincing fake alerts ("Critical: tap to re-auth …"). Enforce length caps, strip control chars, and (7.4) require auth. |
| 7.7 | Payload size / JSON bomb | POST oversized / deeply nested JSON to `/register` and `/webhook` | `request.json()` with no size guard | Verify Worker limits; add explicit body-size rejection. |
| 7.8 | APNs token as URL path | Send `device_token` with URL metacharacters through register→webhook→`sendPush` | token interpolated into `https://${host}/3/device/${token}` (`apns.ts:72`) | Validate token is hex/expected length before use; reject otherwise (defense-in-depth / request-smuggling to APNs host). |
| 7.9 | Secret management | Review `wrangler.toml` + deploy config | `wrangler.toml` has `APNS_ENVIRONMENT=development`, `APNS_BUNDLE_ID` in plaintext vars; `APNS_PRIVATE_KEY`/`WEBHOOK_SECRET` expected as Worker secrets | Confirm the **.p8 private key and webhook secret are Worker _secrets_, never committed**. Confirm prod flips `APNS_ENVIRONMENT=production`. Grep git history for any leaked `.p8`. |
| 7.10 | No unregister / token hygiene | Attempt to remove a token; observe APNs 410 handling | no delete path; `sendPush` ignores 410 Unregistered | Stale tokens accumulate forever (ties to 7.2). Add unregister + prune-on-410. |
| 7.11 | HTTP method / path fuzzing | `ffuf`/`nuclei` against relay routes | router only handles POST `/register`,`/webhook` else 404 (`index.ts:91-102`) | Confirm no verb-tampering or hidden routes; check CORS/OPTIONS behavior. |
| 7.12 | Rate limiting / abuse controls | Burst requests to both endpoints | none present | No rate limiting → spam/DoS/cost. Recommend Cloudflare rate-limiting rules or per-IP throttling. |

---

## 8. Supply chain & build configuration

| # | Test | Method | Expected/likely finding |
|---|------|--------|--------------------------|
| 8.1 | Relay dependency audit | `npm audit` / `osv-scanner` on `relay/package-lock.json` | Enumerate vulnerable transitive deps; wrangler/vitest toolchain. |
| 8.2 | Secrets-in-repo scan | `gitleaks`/`trufflehog` over full git history | Confirm no committed `.p8`, `client_secret`, tokens, or KV IDs that should be secret. (`wrangler.toml` KV `id` is present — assess sensitivity.) |
| 8.3 | Xcode build hardening | Review `project.pbxproj` for Release: symbol stripping, `SWIFT_OPTIMIZATION`, no `NSAllowsArbitraryLoads`, correct entitlements | `ArubaCentral.entitlements` currently empty — Push/aps-environment entitlement must be added correctly and scoped for Task 6. |
| 8.4 | `.gitignore` coverage | Verify `.p8`, `.dev.vars`, build artifacts, `*.xcuserdata` are ignored | Prevent future secret leakage. |
| 8.5 | Static analysis pass | `semgrep` (swift + typescript rulesets) + MobSF on the IPA | Automated triage to corroborate manual findings (force-unwraps, injection, insecure storage). |

---

## 9. Privacy / data handling

| # | Test | Focus |
|---|------|-------|
| 9.1 | PII inventory | Client MAC/IP/username/hostname flow through API client → views → search → (potentially) URL cache (§1.6) and notifications (§5.7). Confirm none is persisted or logged beyond need. |
| 9.2 | Analytics/telemetry | Confirm the app ships **no** third-party analytics/crash SDK that could exfiltrate PII/secrets. (None seen in static read — verify built IPA.) |
| 9.3 | Data retention | Relay KV retains device tokens indefinitely (§7.10). Define retention/pruning. |

---

## 10. Execution order & prioritization

Run in this order — cheapest/highest-signal first, destructive last:

1. **Static pass (§8.5, §4, §7):** semgrep/MobSF/`npm audit` + manual code review to confirm the
   flagged force-unwraps, injection points, and relay auth gaps. Zero risk, fastest ROI.
2. **Relay black-box (§7):** highest-value external surface — registration auth, webhook auth
   bypass, timing, push injection, KV DoS. Test against an **isolated** deployment.
3. **Storage & platform (§1, §5):** keychain accessibility, backup extraction, snapshot leak.
4. **Network (§3):** MITM to prove no pinning; region/SSRF check.
5. **Auth/session (§2):** refresh races, expiry tampering.
6. **Input/crash (§4.1–4.5):** drive malformed serials/cursors via MITM to reproduce crashes —
   run last since it may destabilize the app.

### Likely-finding summary (pre-test hypotheses to validate)

| Severity | Item |
|----------|------|
| **High** | 7.4 webhook auth bypass when secret unset; 7.1 unauthenticated `/register`; 3.1 no TLS pinning (secret interceptable). |
| **Medium** | 4.1 force-unwrap crash DoS; 4.2 path injection into device actions; 4.3 filter injection; 7.2/7.3 KV DoS & race; 7.5 timing side-channel; 1.1 keychain not `ThisDeviceOnly`; 5.2 secret in app-switcher snapshot; 2.6 token-refresh stampede; 4.5 unbounded pagination. |
| **Low / Info** | 2.3 `isAuthenticated` semantics; 1.6 URL cache PII; 5.7 notification content on lock screen; 6.x no anti-tamper; 3.5 region SSRF via UserDefaults. |

Each confirmed finding graduates into the hardening backlog with a concrete remediation
(mostly: encode path/query segments + drop force-unwraps; pin TLS; fail-closed relay auth +
constant-time compare + per-token KV + caps; `ThisDeviceOnly` + access-control on the secret;
snapshot privacy overlay).
```
