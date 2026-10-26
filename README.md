# StaffPro — Employee Management App

Flutter mobile app for multi-business employee, branch, sales, expense and attendance management.

Four roles: **Super Admin → Business Admin → Manager → Employee**.

## Run

```bash
cd staffpro
flutter pub get
flutter run
```

The customer ordering website is a separate project at `ordering-web`. It shares this Firebase project. Run it from that folder, not from the Flutter app.

Use a phone or emulator. Location permission is required for check-in / check-out.

## First-time setup

1. Open the app → **Super Admin Signup**.
2. Secret registration code (change later in Settings): `STAFFPRO-2026`
3. Sign in as Super Admin.
4. **Add Business** (creates the business + initial Business Admin).
5. Sign in as that Business Admin.
6. Create branches, then managers and employees.
7. Employees and managers can record sales/expenses and mark attendance.

Passwords are hashed (never stored as plaintext). Historical records are kept when you deactivate people, branches or businesses.

## What is included

- Role-based dashboards and bottom navigation matching the StaffPro UI
- Super Admin: businesses, admins, platform reports, activity logs, secret code
- Business Admin: branches, employees, managers, sales, expenses, attendance, categories, shifts, reports, customer menu (`publicMenus`), public ordering page (`publicBusinesses`, first slug `turknroll`)
- Manager: assigned-branch only (cannot switch branches)
- Employee: own sales/expenses, cash in hand, attendance, password recovery request
- Persistent branch selector for admins
- Branch transfer with history
- GPS attendance, late / early / on-time / missing checkout
- In-app notifications (employee check-in → manager + admin, manager check-in → admin)
- Audit logs
- CSV export via share sheet
- Shared POS backend (`pos-platform/backend`): employee provisioning and POS dashboard / sales figures

## Shared backend

StaffPro still stores people, attendance, and its own sales/expenses in Firebase (`turknroll-management-app`). The POS API is an extra bridge, not a replacement for Firestore.

| Item | Detail |
| --- | --- |
| API | `pos-platform/backend`, default `http://127.0.0.1:3080/api/v1` |
| Override | `--dart-define=BRIDGE_API_BASE=...` |
| Auth | StaffPro Firebase ID token (`Authorization: Bearer`) |
| Client | `lib/services/bridge_api_client.dart` |

Calls today:

- `POST /employees` when a user is created or their status changes (best-effort; a failed bridge call does not roll back the StaffPro account)
- `GET /dashboard` for POS figures on the admin dashboard
- `GET /auth/session` and `GET /reports/sales` are available on the client

Start the POS API before using those screens. Business Admin, Manager, and Employee accounts are given POS access; deactivating someone sets them to `disabled` on the bridge.

## Assumptions (called out in the spec)

| Topic | Implemented rule |
| --- | --- |
| Cash in hand | Opening (prior cash sales − cash expenses) is implicit in the date range. Daily = cash sales − cash expenses for the day. Monthly starts on the 1st. Only **Cash** payments affect cash. |
| Geofence | Default **200m**. Outside radius is **flagged**, not blocked, unless Super Admin enables “Block attendance outside geofence”. |
| Manager categories | Off by default; Super Admin can enable it. |
| Attendance correction | Business Admin with full access can correct (reason required, audited). |
| Deletion | Deactivate / archive only. |
| Reports | In-app + CSV share. PDF can be added later. |
| Notifications | In-app first. Push (FCM) when Firebase is connected. |

## Firebase

Connected to project **`turknroll-management-app`**.

| Service | Status |
| --- | --- |
| Authentication | Email/Password (Spark / free) |
| Cloud Firestore | StaffPro-only schema + role rules (legacy data wiped) |
| Storage | Not used (avoids Blaze billing) |
| Flutter config | `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` |

### Deploy rules / indexes

```bash
firebase use turknroll-management-app
firebase deploy --only firestore,storage
```

Schema reference: `firebase/SCHEMA.md`.

Do not skip security rules — UI hiding is not authorization.

## Architecture

```
UI → StaffProController → Firebase Auth + FirestoreDatabase → Cloud Firestore
                         → BridgeApiClient → POS API (pos-platform/backend)
```

Role, business and branch checks run in the controller and in `firestore.rules`. The POS API checks the same Firebase token and maps StaffPro users into its own employee records.