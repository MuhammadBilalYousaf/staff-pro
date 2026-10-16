# StaffPro Firestore schema

Project: `turknroll-management-app` (Spark / free tier only)

Auth: Firebase Authentication (email/password). `users/{uid}` document IDs match Auth UIDs.

## Collections

| Collection | Doc ID | Purpose |
| --- | --- | --- |
| `platform/settings` | fixed | Secret code, geofence defaults, manager category flag |
| `platform/public` | fixed | Public secret for Super Admin signup |
| `platform/bootstrap` | fixed | `{ superAdminCreated: bool }` |
| `users` | Auth UID | Profiles (no password fields) |
| `businesses` | uuid | Businesses |
| `branches` | uuid | Branches + GPS geofence |
| `shifts` | uuid | Shift templates |
| `expenseCategories` | uuid | Expense categories |
| `sales` | uuid | Sales |
| `expenses` | uuid | Expenses |
| `attendance` | uuid | Check-in / check-out |
| `notifications` | uuid | In-app notifications |
| `auditLogs` | uuid | Audit trail |
| `assignments` | uuid | Branch transfer history |
| `passwordRequests` | uuid | In-app recovery requests |

## Roles

`superAdmin` | `businessAdmin` | `manager` | `employee`

## Notes

- Soft-delete only (`status` fields). Hard deletes are denied by rules.
- Storage / Blaze features are intentionally not used on the free plan.
