# Operator Module — DEPRECATED (July 2026)

> **Status: deprecated, kept for reference and shared components. Do not add
> new features here.**

## Why

Field policy changed: **each vehicle is issued ONE phone, held by the
driver.** Operators no longer carry devices, so the standalone operator app
surface is retired. Its functionality was merged into the driver module,
rebranded **Captain** (`lib/modules/module2_driver`).

## What moved where

| Operator feature | New home |
|---|---|
| QR FAB + bin scan + weight entry | Captain shell (centre Scan FAB → `OperatorTripScanScreen` / `BinDetailSheet`, both still living here and imported by Captain) |
| Household collection (customer QR, wet/dry/mixed weighment) | Captain Scan FAB → "Household collection" (`OperatorQRScanner` / `OperatorDataScreen`) |
| Today's trip + collection points | Captain Home dashboard (`captain_home_tab.dart`) |
| Trip history | Captain Home → History (`OperatorTripHistoryScreen`, reused) |
| Assigned crew visibility | Captain Home crew card (backend `crew` block on `my-trip-today`) |
| Attendance | **Driver attendance only** (`attendance_driver.dart`); operator attendance screens are not surfaced |
| Operator profile | Not surfaced (driver profile only) |

## What still lives here (imported by Captain — do not delete)

- `operator_qr_scanner.dart`, `operator_data_screen.dart` (household flow)
- `operator_trip_home_screen.dart` (`OperatorTripScanScreen`), `bin_detail_sheet.dart`
- `operator_trip_history_screen.dart`
- `offline/` (sqflite offline login/queue — `AuthRepository` depends on it)
- `services/` (Bluetooth scale, location, image compression)
- `utils/attendance_blink_store.dart`
- widgets reused by legacy driver views (`operator_cp_card.dart`, …)

## Routing

`/operator/*` routes remain registered for backward compatibility; the
operator role still resolves there if such a login occurs. New deployments
issue driver logins only.
