# StaffPro — Employee Management App

Flutter mobile app for multi-business employee, branch, sales, expense and attendance management.

Four roles: **Super Admin → Business Admin → Manager → Employee**.

## Run

```bash
cd staffpro
flutter pub get
flutter run
```

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
- Business Admin: branches, employees, managers, sales, expenses, attendance, categories, shifts, reports
- Manager: assigned-branch only (cannot switch branches)
- Employee: own sales/expenses, cash in hand, attendance, password recovery request
- Persistent branch selector for admins
- Branch transfer with history
- GPS attendance, late / early / on-time / missing checkout
- In-app notifications (employee check-in → manager + admin, manager check-in → admin)
- Audit logs
- CSV export via share sheet

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

The app ships with a **local encrypted-session + JSON store** that uses the same models, authorization checks and collection shape as Firestore, so you can run it immediately.

To move to Firebase:

1. Create a Firebase project.
2. Enable Authentication (email/password), Firestore, Storage, Cloud Messaging.
3. Run `flutterfire configure`.
4. Deploy `firebase/firestore.rules`.
5. Replace `LocalDatabase` with Firestore repositories behind the same `StaffProController` methods.

Do not skip security rules — UI hiding is not authorization.

## Architecture

```
UI → StaffProController → LocalDatabase / Firebase → persistence
```

Role, business and branch checks run in the controller (and in `firestore.rules` for production).
