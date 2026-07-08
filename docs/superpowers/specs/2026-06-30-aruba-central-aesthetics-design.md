# Aruba Central iOS — Aesthetics Design Spec
**Date:** 2026-06-30
**Status:** Approved
**Depends on:** `2026-06-28-aruba-central-app-design.md`

---

## 1. Design Direction

**Navy Flagship.** Deep navy (`#0D274D`) drives all structural chrome — navigation bars, tab bars, section headers. Cards surface on a warm off-white canvas in light mode and a dark navy canvas in dark mode (not system black), so the app has genuine brand depth in both appearances. Brand orange (`#FF8300`) is used sparingly for accents only: active tab indicator, primary action buttons, health score numerals, and top accent bars on stat blocks. Light and dark mode are treated as equally first-class — dark mode uses purpose-built navy surfaces, not automatic inversion of light-mode values.

Reference: Aruba Central web app visual language — navy sidebar structure, white card surfaces, orange accent, clean SF Pro type.

---

## 2. Color System

All colors are defined as `static let` extensions on `Color` in `Shared/Extensions/Color+Brand.swift`. Views never reference hex values directly. This file replaces the existing `Color+Health.swift`.

### Surface tokens

| Token | Light | Dark | Notes |
|-------|-------|------|-------|
| `appBackground` | `#F2F1EF` | `#0A1E38` | Warm off-white / dark navy canvas |
| `cardBackground` | `#FFFFFF` | `#112540` | Card surfaces |
| `navBackground` | `#0D274D` | `#071526` | Nav bar, tab bar |
| `cardBorder` | navy @ 10% | white @ 8% | Card stroke + dividers |

`appBackground` in light mode is warm off-white rather than pure white so white cards have visible lift without heavy shadows. In dark mode, `#0A1E38` gives the app brand depth rather than defaulting to system black.

### Brand accent tokens

| Token | Value | Usage |
|-------|-------|-------|
| `brandOrange` | `#FF8300` | Active tab icon, primary buttons, stat card accent bars, score numerals |
| `brandNavy` | `#0D274D` | Section header text (light mode), nav/tab bar background |
| `brandOrangeMuted` | `#FF8300` @ 12% opacity | Badge fill backgrounds on orange-accented elements |

### Health / status tokens

These replace the current raw `.green`, `.orange`, `.red` values in `Color+Health.swift`. Token names remain identical so all existing call sites continue to compile without changes.

| Token | Light | Dark | Replaces |
|-------|-------|------|---------|
| `healthGood` | `#22C55E` | `#4ADE80` | `.green` |
| `healthWarning` | `#F59E0B` | `#FCD34D` | `.orange` |
| `healthCritical` | `#EF4444` | `#F87171` | `.red` |

`healthWarning` amber is deliberately distinct from `brandOrange` — they must not clash when both appear on the same card (e.g., a warning site card with an orange alert count).

### Alert severity colors

| Severity | Color token | Notes |
|----------|-------------|-------|
| Critical | `healthCritical` | |
| Major | `healthWarning` | |
| Minor | `#3B82F6` (blue) | Hard-coded; no semantic token needed |
| Info | `.secondary` (adaptive) | System adaptive |

---

## 3. Typography

SF Pro system font throughout. No custom typeface bundled. All font sizes use named text styles so Dynamic Type scaling is inherited automatically.

### Type scale

| Role | Spec | Usage |
|------|------|-------|
| Screen title | `.title2.bold()` | Navigation large titles |
| Card headline | `.headline` (semibold) | Site name, device name on cards |
| Primary stat value | `.title2.bold().monospacedDigit()` | Health %, throughput, client counts |
| Stat label | `.caption2.weight(.medium)` + `.tracking(0.5)` uppercase | "APS", "CLIENTS", "ALERTS" beneath stat values |
| Section header | `.caption.weight(.semibold)` + `.tracking(1.0)` uppercase | "ACCESS POINTS", "SWITCHES" |
| Alert name | `.subheadline.weight(.semibold)` | Primary line in alert list rows |
| Body / description | `.body` regular | Alert detail, action descriptions |
| Metadata | `.caption` `.secondary` | Timestamps, site names in rows |
| Tech strings | `.font(.system(.caption, design: .monospaced))` | MAC addresses, IPs, serial numbers, firmware versions |

### Rules

**`.monospacedDigit()` on all numeric values.** Health scores, client counts, port numbers, uptime — every numeric display gets this modifier to prevent layout jitter when values change on pull-to-refresh.

**`.tracking()` on ALL-CAPS labels only.** Never apply letter-spacing to mixed-case text. Uppercase stat labels and section headers use `0.5`–`1.0` tracking to read like instrument-panel callouts, matching the Aruba Central web app panel aesthetic.

**Monospaced design for tech strings.** MAC addresses, IP addresses, serial numbers, and firmware version strings use `.font(.system(.caption, design: .monospaced))` — they are codes, not prose, and column alignment matters when scanning a device list.

---

## 4. Custom Components

Only these five components get custom styling. All other chrome — `List` rows, `NavigationStack`, `TabView`, `Form`, sheets, alerts — remains stock system default, inheriting brand color only via global `UIAppearance` configuration.

### 4.1 `HealthBadgePillView` (replaces `HealthBadgeView`)

**File:** `Shared/Components/HealthBadgePillView.swift`

Two sizes controlled by an enum parameter:

- **`.compact`** — 28×28pt circle, health color fill at 12%, SF Symbol icon at full health color. Used in list rows and table cells where space is tight.
- **`.standard`** — capsule, icon + text label ("Good" / "Warning" / "Critical"), health color fill at 12%, label and icon at full health color, `.caption.weight(.semibold)` font, `4×10pt` padding.

`HealthBadgeView.swift` is deleted. All call sites updated to `HealthBadgePillView`.

### 4.2 `SiteCardView` (redesign)

**File:** `Features/Dashboard/DashboardView.swift` (inline struct)

Changes from current implementation:

- Background: `cardBackground` (replaces `secondarySystemGroupedBackground`)
- **3pt leading accent bar** in health color positioned absolutely on the card's leading edge (replaces the full colored stroke border)
- Card border: `cardBorder` token at 0.5pt stroke (replaces colored 2pt stroke)
- Corner radius: 14pt (up from 12pt)
- Shadow (light mode only): `color: .black.opacity(0.06), radius: 8, x: 0, y: 2`. Dark mode: no shadow.
- Header: site name `.headline`, health percentage `.title2.bold().monospacedDigit()` in health color, `HealthBadgePillView(.compact)` next to site name
- Stat row dividers: `cardBorder` token (replaces hard `Divider()`)
- Stat labels: `.caption2.weight(.medium)` uppercase + `.tracking(0.5)` (replaces `.caption2` plain)

### 4.3 `StatCardView` (redesign)

**File:** `Shared/Components/StatCardView.swift`

Changes from current implementation:

- Background: `cardBackground` solid (replaces `.regularMaterial`)
- **3pt top accent bar**: `brandOrange` by default; health-colored when the stat has a health context (UP DEVICES → `healthGood`, DOWN DEVICES → `healthCritical`)
- Icon: tinted `brandOrange` (replaces `.secondary`)
- Value font: `.title2.bold().monospacedDigit()` (replaces `.title3.bold()`)
- Label font: `.caption2.weight(.medium)` uppercase + `.tracking(0.5)` (replaces `.caption` plain)
- Corner radius: 12pt (unchanged)
- Border: `cardBorder` 0.5pt stroke
- Shadow: same as `SiteCardView`

### 4.4 `AlertSeverityBadgeView` (new)

**File:** `Shared/Components/AlertSeverityBadgeView.swift`

Pill badge for alert severity. Used inline in `AlertRowView` and prominently in `AlertDetailView`.

- Shape: capsule, 20pt height
- Background: severity color at 12% opacity
- Label: severity name, `.caption.weight(.semibold)`, severity color at full opacity
- Four variants: Critical (red), Major (amber), Minor (blue), Info (gray `.secondary`)

### 4.5 `DeviceStatusBadge` (new)

**File:** `Shared/Components/DeviceStatusBadge.swift`

Compact pill badge for device up/down state. Used in device list rows within Site Detail and the Devices tab.

- Shape: capsule, 18pt height
- **Up:** `healthGood` fill at 12%, "Up" label in `healthGood`
- **Down:** `healthCritical` fill at 12%, "Down" label in `healthCritical`
- **Warning:** `healthWarning` fill at 12%, "Warning" label in `healthWarning`
- Font: `.caption2.weight(.semibold)`
- Padding: 3×8pt

### 4.6 `BrandedTabPicker` (new)

**File:** `Shared/Components/BrandedTabPicker.swift`

Replaces `.segmented` `Picker` style in `APDetailView` and `SwitchDetailView`.

- Layout: full-width `HStack` of pill-shaped buttons, 4pt gap, 3pt padding around the group
- Container background: `brandNavy` at 7% opacity, capsule shape
- **Selected pill:** `brandOrange` fill, white label, `.caption.weight(.semibold)`
- **Unselected pill:** transparent background, `.secondary` label, `.caption.weight(.semibold)`
- Height: 36pt. Corner radius: capsule. Horizontal padding: 16pt.
- Generic over `[String]` labels + `Binding<Int>` selection index.

---

## 5. Global Appearance Configuration

Configured once in `ArubaCentralApp.swift` via `init()` using `UINavigationBarAppearance` and `UITabBarAppearance`. All screens inherit automatically — no per-view appearance overrides needed.

### Navigation bar

```swift
let navAppearance = UINavigationBarAppearance()
navAppearance.configureWithOpaqueBackground()
navAppearance.backgroundColor = UIColor(Color.navBackground)
navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
UINavigationBar.appearance().standardAppearance = navAppearance
UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
UINavigationBar.appearance().tintColor = UIColor(Color.brandOrange)
```

### Tab bar

```swift
let tabAppearance = UITabBarAppearance()
tabAppearance.configureWithOpaqueBackground()
tabAppearance.backgroundColor = UIColor(Color.navBackground)
// Selected: orange. Unselected: white @ 55%.
UITabBar.appearance().standardAppearance = tabAppearance
UITabBar.appearance().scrollEdgeAppearance = tabAppearance
UITabBar.appearance().tintColor = UIColor(Color.brandOrange)
UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.55)
```

---

## 6. Screen-by-Screen Treatments

### Dashboard / Site List

- Canvas: `appBackground` (replaces `systemGroupedBackground`)
- `LazyVStack` spacing 12pt, horizontal padding 16pt — unchanged
- `AlertSummaryCardView`: 4pt leading orange bar replaces current plain background; orange bell icon; no stroke border
- `SiteCardView`: redesigned per §4.2

**Empty state:** SF Symbol `building.2` tinted `brandOrange` at 60% opacity; headline `.headline`; subhead `.subheadline .secondary`.

### Site Detail

New `SiteHealthHeaderView` pinned above the device list:
- Full-width `cardBackground` card
- 64pt health color ring with health percentage (`.title.bold().monospacedDigit()`) centered
- Row of three `StatCardView` blocks below: "UP DEVICES" (green bar), "DOWN DEVICES" (red bar), "CLIENTS" (orange bar)
- Same shadow as all cards

Section headers ("ACCESS POINTS", "SWITCHES"): `.caption.weight(.semibold).tracking(1.0)` uppercase, `brandNavy` / white color, 16pt leading inset.

Device rows: `DeviceStatusBadge` compact Up/Down pill right-aligned; device name `.headline`; model in `.font(.system(.caption, design: .monospaced))`.

### AP Detail

- Tab selector: `BrandedTabPicker` with tabs ["Overview", "Radios", "Clients"]
- Overview: 2×2 `StatCardView` grid (iPhone) / 3-column (iPad) — Uptime, Clients, Throughput Down, Throughput Up; all orange top bars; `.monospacedDigit()` values
- Throughput chart: `brandOrange` line, `cardBackground` surface
- Firmware / serial / IP fields: `.font(.system(.caption, design: .monospaced))` values in a `cardBackground` card with `cardBorder` stroke
- Radios tab: each radio is a card, not a plain list row — band rendered as a small pill (2.4 GHz: blue, 5 GHz: orange, 6 GHz: green)

### Switch Detail

- Tab selector: `BrandedTabPicker` with tabs ["Overview", "Ports", "VLANs"]
- Port diagram cells: Up → `healthGood`, Down → `#6B7280`, Error → `healthCritical`
- Legend strip above the diagram: three color-labeled pills matching cell colors
- Tapped port detail sheet: speed/VLAN/connected device in `.font(.system(.caption, design: .monospaced))`

### Alerts Tab

`List(.insetGrouped)` stays stock. All styling is inside `AlertRowView`.

`AlertRowView` changes:
- Left accent bar: 4pt capsule in severity color — keep existing implementation, no change
- Add `AlertSeverityBadgeView` inline after alert name
- Unacknowledged rows: `.listRowBackground(alert.severity.color.opacity(0.04))`
- Alert name font: `.subheadline.weight(.semibold)` (changed from `.headline`)
- Acknowledged rows: severity badge fades to gray adaptive color, left bar clears (existing logic via `alert.isCleared`)

Alert Detail:
- `AlertSeverityBadgeView(.standard)` prominently at top
- Affected device name: `.subheadline.weight(.semibold)` + `brandOrange` foreground (signals tappability)
- Acknowledge button: `brandOrange` filled capsule, full-width

### Navigation bar & Tab bar

Configured globally (§5). No per-screen overrides. All screens inherit navy/orange chrome automatically.

### Screens that receive no styling changes

Settings (`Form` + `.insetGrouped`), Clients tab list rows, global search overlay (`SearchResultsOverlay`), offline banner (`OfflineBannerView`), confirmation dialogs, error alerts. These screens inherit brand chrome from the global nav/tab bar appearance but otherwise remain stock.

---

## 7. Implementation Notes

### File changes summary

| Action | File |
|--------|------|
| Replace | `Shared/Extensions/Color+Health.swift` → `Color+Brand.swift` |
| Replace | `Shared/Components/HealthBadgeView.swift` → `HealthBadgePillView.swift` |
| Modify | `Shared/Components/StatCardView.swift` |
| Modify | `Features/Dashboard/DashboardView.swift` (SiteCardView inline struct) |
| Modify | `Features/Alerts/AlertsView.swift` (AlertRowView) |
| Modify | `Features/Alerts/AlertDetailView.swift` |
| Add | `Shared/Components/AlertSeverityBadgeView.swift` |
| Add | `Shared/Components/DeviceStatusBadge.swift` |
| Add | `Shared/Components/BrandedTabPicker.swift` |
| Add | `Features/Dashboard/SiteDetail/SiteHealthHeaderView.swift` |
| Modify | `ArubaCentral/ArubaCentralApp.swift` (global appearance init) |
| Modify | `Features/Devices/APDetail/APDetailView.swift` |
| Modify | `Features/Devices/SwitchDetail/SwitchDetailView.swift` |

### Dark mode verification checklist

Each custom component must be tested in both modes before the phase is considered complete:

- [ ] `SiteCardView`: left accent bar, score color, stat values visible on dark navy
- [ ] `StatCardView`: solid `cardBackground` (not material blur) visible on `appBackground`
- [ ] `HealthBadgePillView`: fill at 12% opacity readable on both `cardBackground` values
- [ ] `AlertSeverityBadgeView`: fill at 12% opacity readable on dark list row background
- [ ] `BrandedTabPicker`: container background visible on both light and dark nav bars
- [ ] Nav/tab bar: opaque navy on both modes (no translucency bleed-through)
- [ ] `SiteHealthHeaderView`: ring and stat blocks render correctly on dark canvas

### Accessibility

- All health and severity colors from §2 must maintain WCAG AA (4.5:1) contrast ratio against their respective background tokens. Verify with Xcode's Accessibility Inspector or Color Contrast Analyser before shipping.
- `HealthBadgePillView` retains the existing `.accessibilityLabel("Health: \(level.accessibilityLabel)")` pattern.
- `BrandedTabPicker` exposes selection state via `.accessibilityAddTraits(.isSelected)` on the active pill.
- `AlertSeverityBadgeView` is `.accessibilityHidden(true)` — severity is already read by the parent `AlertRowView`'s combined accessibility label.
