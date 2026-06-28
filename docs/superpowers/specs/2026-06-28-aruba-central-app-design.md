# Aruba Central iOS App — Design Spec
**Date:** 2026-06-28
**Status:** Approved

---

## 1. Overview

A SwiftUI iOS app targeting iPhone and iPad (iOS 16+) that pulls telemetry from HPE Aruba Networking **New Central** and displays it in a native mobile interface. The app is optimized individually for iPhone (tab + navigation stack) and iPad (split view with sidebar), and targets network admins and field techs who need mobile visibility into APs, switches, clients, and alerts.

**Xcode project:** `/Users/joshuaebibbs/XcodeProj/ArubaCentral/`

---

## 2. Scope

**In scope:**
- Access Points and Switches (device types)
- Sites, Clients (wireless + wired), Alerts
- Five light write actions: Reboot AP, Blink AP LED, Bounce Switch Port, Disconnect Client, Acknowledge Alert
- Real-time push notifications via webhook relay → APNs
- Single Central account; region selected from pre-populated list in Settings

**Out of scope (v1):**
- Gateways and other device types
- Configuration changes beyond the five listed actions
- Multiple account support
- Offline data persistence (last-known data is in-memory only)

---

## 3. Architecture

**Pattern:** MVVM + async/await

- Each screen has a dedicated ViewModel owning its API calls, pagination, and state
- `CentralAPIClient` is a single actor-isolated class injected as `@EnvironmentObject` at the app root
- `AuthTokenManager` handles OAuth token lifecycle (Keychain storage, proactive refresh, retry on 401)
- Models are pure `Codable` structs — no business logic, no SwiftUI imports
- All network calls use Swift structured concurrency (`async/await`, `async let` for parallel fetches)

### Project Structure

```
ArubaCentral/
├── App/
│   └── ArubaCentralApp.swift
├── Core/
│   ├── API/
│   │   ├── CentralAPIClient.swift
│   │   ├── AuthTokenManager.swift
│   │   └── APIError.swift
│   ├── Models/
│   │   ├── Site.swift
│   │   ├── AccessPoint.swift
│   │   ├── Switch.swift
│   │   ├── Client.swift
│   │   └── Alert.swift
│   └── Keychain/
│       └── KeychainManager.swift
├── Features/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── DashboardViewModel.swift
│   │   └── SiteDetail/
│   │       ├── SiteDetailView.swift
│   │       └── SiteDetailViewModel.swift
│   ├── Devices/
│   │   ├── DevicesView.swift
│   │   ├── DevicesViewModel.swift
│   │   ├── APDetail/
│   │   │   ├── APDetailView.swift
│   │   │   └── APDetailViewModel.swift
│   │   └── SwitchDetail/
│   │       ├── SwitchDetailView.swift
│   │       └── SwitchDetailViewModel.swift
│   ├── Clients/
│   │   ├── ClientsView.swift
│   │   └── ClientsViewModel.swift
│   ├── Alerts/
│   │   ├── AlertsView.swift
│   │   └── AlertsViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── Shared/
│   ├── Components/
│   └── Extensions/
└── Notifications/
    └── PushNotificationHandler.swift
```

### ViewModel State

All ViewModels use a shared state enum:

```swift
enum LoadState<T> {
    case idle
    case loading
    case loaded(T)
    case error(APIError)
}
```

---

## 4. New Central API Integration

### Authentication

OAuth 2.0 client credentials via HPE SSO:

```
POST https://sso.common.cloud.hpe.com/as/token.oauth2
Content-Type: application/x-www-form-urlencoded
Body: grant_type=client_credentials&client_id=...&client_secret=...

Response:
{
  "access_token": "<token>",
  "token_type": "Bearer",
  "expires_in": 7199
}
```

- Token lifetime: 2 hours (Central credentials)
- `AuthTokenManager` refreshes proactively with a 60-second buffer before expiry
- On 401: refresh token once and retry; if refresh fails, post a `NotificationCenter` event to prompt re-auth in Settings
- Credentials (Client ID + Secret) stored in iOS Keychain only

### API Base URLs (Pre-populated Region List)

| Region Label | Base URL |
|-------------|----------|
| US-1 | `https://us1.api.central.arubanetworks.com` |
| US-2 | `https://us2.api.central.arubanetworks.com` |
| US-West-4 | `https://us4.api.central.arubanetworks.com` |
| US-West-5 | `https://us5.api.central.arubanetworks.com` |
| US-East-1 | `https://us6.api.central.arubanetworks.com` |
| Canada-1 | `https://ca1.api.central.arubanetworks.com` |
| EU-1 | `https://de1.api.central.arubanetworks.com` |
| EU-Central-2 | `https://de2.api.central.arubanetworks.com` |
| EU-Central-3 | `https://de3.api.central.arubanetworks.com` |
| UK | `https://gb1.api.central.arubanetworks.com` |
| APAC-1 | `https://in1.api.central.arubanetworks.com` |
| APAC-East-1 | `https://jp1.api.central.arubanetworks.com` |
| APAC-South-1 | `https://au1.api.central.arubanetworks.com` |
| UAE | `https://ae1.api.central.arubanetworks.com` |

User selects their region in Settings. The base URL is resolved from the selection — no manual URL entry.

**Rate limit:** 10 API calls per second across the entire Central account.

### API Endpoints (New Central MRT)

| Feature | Method | Endpoint |
|---------|--------|----------|
| Site health | GET | `/getsitehealthv1` |
| List APs | GET | `/accesspointsv1` |
| AP detail | GET | `/accesspointdetailsv1` |
| AP radio list | GET | `/accesspointradiolistv1` |
| AP throughput | GET | `/accesspointthroughputv1` |
| AP WLAN list | GET | `/accesspointwlanlistv1` |
| List switches | GET | `/switchesv1` |
| Switch detail | GET | `/switchv1` |
| Switch interfaces/ports | GET | `/listinterfacesv1` |
| Switch VLANs | GET | `/listvlansv1` |
| Switch stack members | GET | `/liststackmembersv1` |
| Unified clients list | GET | `/listunifiedclients` |
| Client detail | GET | `/getclientdetails` |
| Alerts list | GET | `/getalertlistv1` |
| Clear/acknowledge alert | POST | `/clearalerts` |
| Reboot AP | POST | `/rebootapv1` |
| Blink/Locate AP LED | POST | `/locateapv1` |
| Disconnect all clients from AP | POST | `/disconnectallusersapv1` |

> **Open item #1:** Bounce switch port — confirm New Central MRT endpoint name before implementation.
> **Open item #2:** Disconnect individual client — confirm per-client endpoint; fallback is `/disconnectallusersapv1` (disconnects all clients on the AP).

### Data Loading Strategy — Tiered (Option C)

- **Dashboard:** Loads site-level summaries only (`/getsitehealthv1`) — small, fast payload
- **Site Detail:** Loads devices for the selected site paginated (page size 100, infinite scroll)
- **Device Detail:** Loads on tap; parallel fetches via `async let` where multiple endpoints needed
- **Clients tab:** Loads clients for a selected site; default state is empty until site is picked or search is entered
- **Global search:** API-backed, debounced 300ms, queries across all devices/clients server-side — searches by MAC address, IP address, and hostname. Works regardless of what has been loaded locally.
- **Pagination:** ViewModel tracks `currentOffset` and `hasMore`; next page loads when user scrolls within ~3 rows of the list bottom

### Data Freshness

Pull-to-refresh only — no auto-refresh timer. Views load data on appear and on explicit pull. This keeps battery usage and API rate limit consumption minimal.

---

## 5. Navigation

### iPhone — Tab Bar + Navigation Stack

```
TabView
├── Dashboard    → NavigationStack → DashboardView → SiteDetailView → DeviceDetailView
├── Devices      → NavigationStack → DevicesView → APDetailView | SwitchDetailView
├── Clients      → NavigationStack → ClientsView → ClientDetailView
├── Alerts (🔴)  → NavigationStack → AlertsView → AlertDetailView
└── Settings     → NavigationStack → SettingsView
```

Each tab owns its own `NavigationStack` — position within a tab is preserved when switching tabs. Alerts tab badge shows unacknowledged alert count.

### iPad — NavigationSplitView

Two-column split for all tabs. Sidebar lists the five tabs; content column shows the primary list for the selected tab; drilling deeper pushes within the content column's `NavigationStack`.

Three-column layout activates on iPad Pro 12.9" for the Devices tab only:

```
┌──────────┬──────────────────┬───────────────────────────┐
│ Sidebar  │  Device List     │  Device Detail            │
│ (tabs)   │  (APs/Switches)  │  (Overview/Radios/Ports)  │
└──────────┴──────────────────┴───────────────────────────┘
```

### Global Search

Search bar in the navigation bar of Dashboard, Devices, and Clients tabs. Searches MAC address, IP address, and hostname via API. Debounced 300ms. Results shown in a unified list with device-type icons. On iPhone: expands inline. On iPad: sits persistently in the content column header.

---

## 6. Screen Designs

### Dashboard Tab
- Site list from `/getsitehealthv1`
- Each row: site name, health badge (green/yellow/red), AP count, Switch count, Client count
- Pull-to-refresh reloads list
- Offline banner + "last updated" timestamp when connectivity lost
- Tap site → Site Detail

### Site Detail
- Health summary card: overall score, up/down device counts
- Two paginated sections: APs and Switches (100 per page, infinite scroll)
- Each device row: name, model, status badge, uptime
- Tap device → AP Detail or Switch Detail

### AP Detail (3 tabs)
- **Overview:** Name, model, serial, firmware, IP, uptime, throughput chart, power consumption, client count
- **Radios:** Band, channel, SSID, client count, throughput per radio (from `/accesspointradiolistv1`)
- **Clients:** Clients connected to this AP (from `/listunifiedclients` filtered by AP)
- Action menu: Reboot AP | Blink LED (each requires confirmation)

### Switch Detail (3 tabs)
- **Overview:** Name, model, serial, firmware, IP, uptime; stack members if applicable
- **Ports:** Visual port diagram — grid colored by status (up=green, down=gray, error=red). Tap port for detail: speed, VLAN, connected device, Tx/Rx. Action: Bounce Port (confirmation required). *(Open item #1)*
- **VLANs:** VLAN ID, name, tagged/untagged ports (from `/listvlansv1`)

### Devices Tab
- Filterable list: all APs and Switches across all sites
- Filters: site picker, device type (AP/Switch), status (All/Up/Down)
- Search bar: debounced API-backed search
- Infinite scroll with pagination
- iPad: device list in content column, detail in detail column

### Clients Tab
- Search bar (IP, MAC, hostname) + site picker pill
- Default state: empty with instruction text
- Selecting a site loads clients via `/listunifiedclients` grouped into Wireless and Wired sections
- Global search queries across all sites regardless of site picker
- Each row: hostname, IP, MAC, connection type icon, AP or switch name, SSID or port/VLAN
- Tap → Client Detail: signal strength, data usage, session duration, connected device
- Action: Disconnect Client *(Open item #2)*

### Alerts Tab
- List from `/getalertlistv1`, sorted newest first
- Each row: severity icon, alert name, device name, site, timestamp
- Unacknowledged: colored left border
- Tab bar badge: unacknowledged count
- Tap → Alert Detail: description, affected device (tappable), recommended action
- Action: Acknowledge → POST `/clearalerts`
- Push notifications deep-link to Alert Detail

### Settings Tab
Four sections:
1. **Account:** Client ID, Client Secret (masked), Region picker (14 pre-populated regions), "Test Connection" button
2. **Notifications:** Severity toggles — Critical, Major, Minor, Info
3. **Appearance:** Segmented control — System / Light / Dark
4. **About:** App version, build number

Credentials saved to Keychain. Region and appearance saved to `UserDefaults`.

---

## 7. Error Handling

| Scenario | Behavior |
|----------|----------|
| No network on launch | Offline banner + last-known in-memory data with timestamp |
| Token expired, refresh fails | Alert: "Session expired — please re-authenticate" → Settings |
| 401 after one retry | Same as above |
| 403 Forbidden | Inline: "Your account doesn't have permission to view this" |
| 429 Rate limit | Exponential backoff: 1s → 2s → 4s, max 3 retries, then surface error |
| 500 Server error | Inline error card with retry button |
| Action failure | Dismisses confirmation sheet, shows `.alert` with error message |
| JSON decode failure | Logged silently + inline error card; app does not crash |

---

## 8. Push Notifications & Webhook Relay

### Flow

```
New Central Alert fires
        ↓
POST to Relay Backend (Lambda or Cloudflare Worker)
   → Validate HMAC signature from Central
   → Check severity against device token preferences
   → Format APNs payload
        ↓
APNs → iPhone/iPad
        ↓
Tap notification → deep-link to Alert Detail
```

### Relay Backend

Stateless function (Lambda or Cloudflare Worker). No database. Device token + severity preferences registered by the app on launch or preference change. Verifies HMAC, filters severity, POSTs to APNs.

**Open item #3:** Infrastructure choice (Lambda vs. Cloudflare Worker) and APNs certificate management TBD.

### iOS Side

1. Request APNs authorization on first launch after credentials are set
2. Register for remote notifications → receive device token
3. POST device token + severity preferences to relay backend
4. `PushNotificationHandler` receives notifications → posts `NotificationCenter` event → Alerts ViewModel refreshes list and badge count
5. Deep-link via `alert_id` in APNs payload → `AlertDetailView`

**Fallback:** `BGAppRefreshTask` polls `/getalertlistv1` (~15 min minimum interval) when relay is unavailable.

### Webhook Configuration (Central Side)

- Configured under API Gateway → Webhooks in New Central UI
- Max 10 webhooks per Central instance
- Authentication: API Key (Bearer token) or OIDC
- HMAC secret provided at creation for relay-side payload verification
- Notification Rules created to select alert categories, device functions, and minimum severity

---

## 9. iPhone & iPad Adaptive Layout

All layouts use SwiftUI's adaptive system — no separate iPhone/iPad code paths. `NavigationSplitView` collapses automatically on iPhone. `horizontalSizeClass` drives column visibility where needed.

### iPhone
- `TabView` bottom tab bar
- Full-screen push navigation within each tab
- AP/Switch detail tabs use `.segmented` Picker style
- Actions use `.confirmationDialog`
- Port diagram scrolls horizontally for 24/48-port switches

### iPad
- `NavigationSplitView` sidebar + content column
- Alert detail, Settings shown in content column (not as sheets)
- Settings: fixed 320pt column width
- Port diagram renders in larger fixed canvas — no horizontal scroll on iPad Pro
- Actions use `.alert` (correct anchoring in split view)
- Three-column layout on iPad Pro 12.9" for Devices tab only

### Accessibility
- All text uses Dynamic Type — no hardcoded font sizes
- Health badges meet WCAG AA contrast ratios in light and dark mode
- VoiceOver labels on badges read "Site name, health: Good/Warning/Critical"
- Minimum tap target: 44×44pt on all interactive elements
- Appearance override (System/Light/Dark) applied via `.preferredColorScheme` at app root

---

## 10. Testing Strategy

### Unit Tests (XCTest)
- ViewModels tested in isolation via mock `CentralAPIClientProtocol`
- State transitions, pagination logic, token refresh, search debounce, error mapping

### Integration Tests (XCTest)
- `AuthTokenManager` against `URLProtocol`-stubbed HTTPS server
- `CentralAPIClient` with stubbed `URLSession` responses verifying JSON decoding per endpoint

### UI Tests (XCUITest)
Smoke tests (against stubbed API server):
- Launch → credentials → test connection → Dashboard loads
- Dashboard → tap site → Site Detail loads
- Devices tab → search → results appear
- Alerts → tap alert → acknowledge → badge decrements

### Manual Testing Checklist
- Pull-to-refresh on each tab
- Offline banner appears; last-known data shows with timestamp
- Push notification deep-links to correct Alert Detail
- iPad split view: selecting device updates detail column without push navigation
- iPad Pro 12.9": three-column layout activates on Devices tab
- All five actions show confirmation and handle success/failure gracefully
- Appearance override persists across restarts
- Keychain credentials survive app restart

---

## 11. Open Items

| # | Item | Notes |
|---|------|-------|
| 1 | Bounce switch port endpoint | Confirm New Central MRT endpoint name before implementing Switch Detail ports action |
| 2 | Disconnect individual client endpoint | Confirm per-client endpoint; fallback is `/disconnectallusersapv1` |
| 3 | Webhook relay infrastructure | Choose Lambda vs. Cloudflare Worker; set up APNs certificate management |
