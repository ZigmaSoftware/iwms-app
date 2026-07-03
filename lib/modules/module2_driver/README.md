# Captain — the merged vehicle app (driver + operator)

**Captain** is the single mobile surface for a waste-collection vehicle.
Policy: one phone per vehicle, held by the driver — the captain of the
vehicle. The former operator app (`module3_operator`) is deprecated; its
collection features live here now.

## Shell (`driver_home_page.dart`)

Tabs: **Home / Map / [Scan FAB] / Attendance / Profile**

- **Home** (`captain_home_tab.dart`) — today-first liquid-glass dashboard:
  hero trip card with progress ring, quick actions (Navigate / Scan /
  History), stop-by-stop collection timeline (tap a pending stop → weight
  entry), and the crew card showing the operator(s) assigned to the vehicle.
- **Map** — the original turn-by-turn navigation view (flutter_map + ORS).
- **Scan FAB** — centre-docked, pulsing. Opens a chooser: *Bin collection*
  (scan bin QR → validate → weight entry) or *Household collection*
  (customer QR → wet/dry/mixed weighment). Both flows reuse the proven
  operator screens.
- **Attendance** — driver attendance only (photo + GPS).
- **Profile** — driver profile.

## Design system

- `theme/captain_theme.dart` — sunlight-first palette (warm paper, forest
  ink, emerald CTAs, amber signals) + `CaptainBackground` ambient canvas.
- `widgets/captain_glass.dart` — liquid-glass primitives (`CaptainGlassCard`,
  `CaptainGlassChip`, `CaptainProgressRing`), generalised from the supervisor
  module's glass cards: low backdrop blur (clear glass, not milk), −75° white
  gradient fill, sweep-gradient border, screen-blend sheen.
- `widgets/captain_nav_bar.dart` — notched nav bar + `CaptainScanFab`, with
  the attendance blink badge.
- `theme/driver_theme.dart` — legacy alias, forwards every token to
  `CaptainTheme` so older screens re-skin automatically.

## Backend contract

- `GET /operator-mobile/my-trip-today/` — now includes a `crew` block
  (driver, operator, extra operators, substitution status).
- `POST /operator-mobile/validate-bin-qr/` and `/scan-bin/` — accept the
  driver role (`IsOperatorOrDriverRole`); trip resolution is role-aware.
