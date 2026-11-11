# StaffPro — Complete Product & UI/UX Brief

**Use this document to redesign UI/UX with proper navigation.**  
App name is **StaffPro** (not “Stump Pro”). Tagline: **Manage People. Grow Business.**

This is a Flutter mobile-first employee / multi-business ops app (Android, iOS, Web). It manages staff, branches, sales, expenses, GPS attendance, customer menu, QR customer orders, and loyalty. Currency: **Rs** (Pakistan).

Related projects (separate UIs, same Firebase):
- `ordering-web` — public customer ordering website
- `pos-platform` — POS backend bridge for dashboard KPIs

---

## 1. Brand & visual identity

### Logo asset
- **File:** `assets/staffpro_logo.png`
- **Also used as:** app launcher icon (Android/iOS/Web), favicon, in-app brand mark
- **Composition:** Square rounded icon on white
  - Three human silhouettes (center figure navy with collar/tie; side figures gray)
  - Orange swoosh/orbital arc under the figures
  - Orange rounded square with white checkmark at top-right of swoosh
  - Wordmark below: **Staff** (navy) + **Pro** (orange), bold sans-serif
- **In UI:**
  - `BrandLogo` — large logo + tagline on splash/login/signup
  - `BrandMark` — 36px square mark in every authenticated screen header
  - Avatar fallback: initials in a circle (no photo gallery required; `photoPath` exists on user model but Storage is unused on free plan)

### Current theme (reference — redesign may improve)
| Token | Hex | Use |
| --- | --- | --- |
| Primary | `#0066FF` | Buttons, selected nav, links |
| Primary dark | `#0052CC` | Pressed |
| Navy | `#1A2B48` | Headings, body |
| Muted | `#8A94A6` | Subtitles |
| Border | `#E2E8F0` | Inputs, cards |
| Background | `#F7F9FC` | Soft fills |
| Wash | `#EBF8FF` | Soft blue panels |
| Success | `#16A34A` | Positive KPIs, checked-in |
| Danger | `#E11D48` | Errors, logout, delete |
| Warning | `#F59E0B` | Late, flags |
| Info / Teal / Purple / Orange | accents for KPI icons |

- **Font:** Inter (Google Fonts), Material 3, light mode only
- **Cards:** white, soft shadow, ~16–20 radius
- **Inputs:** filled white, 12px radius, primary focus ring
- **Decorative auth background:** two soft blue circles (top-left, bottom-right)
- **Logo brand orange is underused in current UI** — primary is blue; redesign may align accents with logo orange `#FF6600`-ish while keeping navy

### Images used in product
1. **StaffPro logo** — splash, auth, headers, launcher
2. **Menu product images** — URL or base64 data URI; 48×48 thumb; placeholder = food icon on beige `#E8E4DE`
3. **Payment QR** — uploaded image (gallery → base64) shown ~180px tall on Business Profile; used by customer site
4. **User photo** — field exists (`photoPath`); UI mainly shows **initials avatar**
5. **Map pin** — flutter_map location picker for branch geofence (no custom map marker art)
6. **Charts** — fl_chart on sales (simple bar by hour); no illustration assets

**No other image assets exist** in `assets/` besides `staffpro_logo.png`.

---

## 2. Roles & permission model

Hierarchy: **Super Admin → Business Admin → Manager → Employee**

| Role | Scope | Key powers |
| --- | --- | --- |
| Super Admin | Entire platform | Create businesses + initial admin; manage all admins/managers; platform reports; secret code; geofence defaults; activity logs |
| Business Admin | One business | Branches, staff, sales/expenses, attendance corrections (full access), menu, public ordering page, customers/orders, categories, shifts, reports, cash |
| Manager | Assigned branch only (cannot switch) | Branch staff, sales/expenses, own + team attendance, password requests, customer orders/customers, reports |
| Employee | Self + assigned branch | Own sales/expenses, cash, check-in/out, customer orders, password recovery request |

**Admin permissions flags** (Business Admin): `fullAccess`, `employeeManagement`, `branchManagement`, `manageCategories`. Attendance correction requires full access. Soft-delete only (Active / Inactive / Suspended / Archived).

**Platform settings (Super Admin):**
- Secret registration code (default `STAFFPRO-2026`)
- Default geofence radius (200m)
- Block attendance outside geofence (off = flag only)
- Allow managers to manage expense categories

---

## 3. Global chrome & navigation patterns

### Auth routes (no bottom nav)
| Route | Screen |
| --- | --- |
| `/splash` | Logo on decorative background → login or role home |
| `/login` | Email/password login |
| `/signup` | Super Admin signup (secret code) |
| `/forgot-password` | Firebase reset + optional message |

After login, redirect by role prefix: `/sa`, `/ba`, `/mg`, `/emp`. Roles cannot open another role’s routes.

### Authenticated shell (all roles)
- **Top header:** BrandMark + tab title + subtitle (`Role · Business`) + notification bell (badge) + initials avatar → Profile
- **Bottom nav:** 5 tabs (custom row, not Material BottomNavigationBar), selected = primary blue, unread badge on Alerts/Inbox if applicable
- **Android back:** pops tab history within shell
- **Branch selector:** Super/Business Admin see dropdown (“All branches” + list). Manager/Employee see read-only chip with branch name

### Bottom nav by role

**Super Admin (`/sa`)**
1. Home → Dashboard  
2. Business → Businesses list  
3. Reports → Platform reports hub  
4. Alerts → Notifications  
5. More → Menu of secondary screens  

**Business Admin (`/ba`)**
1. Home → Dashboard  
2. Branches  
3. Staff → Employees list  
4. Reports  
5. More  

**Manager (`/mg`)**
1. Home → Dashboard  
2. Staff → Employees  
3. Sales  
4. Attend → Check-in/out action  
5. More  

**Employee (`/emp`)**
1. Home → Dashboard  
2. Sales  
3. Expenses  
4. Attend  
5. More  

Push routes (detail/forms) sit **above** the shell with AppBar + back.

---

## 4. Screen-by-screen inventory

### 4.1 Auth

#### Splash
- Full-screen decorative wash + centered BrandLogo (96)
- Auto-route after ~900ms

#### Login
- BrandLogo (78) + “Login” / “Access your account”
- Fields: Email, Password (show/hide), Remember me, Forgot password?
- Primary CTA: Login
- Divider “OR”
- Soft card: “Are you a Super Admin?” → outlined CTA **Super Admin Signup**

#### Create Super Admin (`/signup`)
- Back, BrandLogo, title “Create Super Admin”
- Fields: Full Name, Email, Password, Confirm Password, Secret Registration Code (+ info dialog)
- CTA: Create Account → toast → Login
- Footer: Already have an account? Login

#### Forgot password
- Key icon, title “Password recovery”
- Explains Firebase email reset + manager/admin Password Requests
- Email + optional Message → Send Request

---

### 4.2 Super Admin

#### Home / Dashboard
- Greeting: `{Good morning/afternoon/evening}, {FirstName}!`
- KPI grid (2 cols): Total Businesses, Active Businesses, Total Admins, Total Branches, Total Employees, Inactive
- CTA: Add Business
- Chips: Businesses, Admins, Reports, Managers (count)
- Recent Activity list (audit logs) or empty

#### Businesses (`/sa/businesses`)
- Search + filter chips All / Active / Inactive
- Cards: name, status badge, city/code, counts (branches · admins · employees) → details
- FAB: Add Business

#### Add Business wizard (`/sa/business/add`)
3 steps with stepper:
1. **Business Info:** Name, Code, Phone, Email, Address, City, Status Active/Inactive  
2. **Admin Details:** Full Name, Email, Phone, Password, Confirm  
3. **Review** cards → Create Business  

#### Business details (`/sa/business/:id`)
- Business info, status, related branches/people shortcuts, add branch, deactivate patterns

#### Business Admins list + Add Admin
- List of business admins
- Add: select business, name, email, phone, password, permission toggles (full / employees / branches / categories)

#### Managers list + Person form
- Same people form pattern as BA (see People)

#### Reports hub (platform)
- Date range card
- Daily P&L entry (for BA path mainly)
- Report type tiles → detail lists + CSV share (“StaffPro Sales Export”)

#### Notifications
- Mark all read
- Cards of alerts; empty: “No notifications”

#### Activity Logs
- Cards: action · module, performer, timestamp, newData

#### More
- Profile header card (initials + Super Admin)
- Menu tiles: Dashboard, Businesses, Business Admins, Managers, Reports, Notifications, Activity Logs, Profile, Change Password, Settings, Help, About, Logout (danger)

#### Settings
- Secret Registration Code
- Default geofence radius (m)
- Switches: Block attendance outside geofence; Allow managers expense categories
- Save Settings; link to Activity Logs

#### Profile / Change Password / Help / About
- Shared across roles (see Shared screens)

---

### 4.3 Business Admin

#### Home / Dashboard
- Greeting + BranchSelectorBar
- KPI grid: Today’s Sales (trend vs yesterday), Today’s Expenses, Should have (MTD) → Cash, Present Today `present/total`
- Card **Accounts this month:** Cash / Card / Online / Total — “Tap for staff breakdown · resets on the 1st”
- Optional **POS Bridge** card (today’s POS KPIs if API up)
- **Branch Performance:** per-branch bar vs max sales today
- Action chips: Add Sale, Add Expense, Sales, Expenses, Attendance
- Recent Activity

#### Branches
- List cards: name, managers/employees counts → Branch details
- Empty: Create first branch
- Add/Edit Branch form:
  - Name, Code, Phone, Address, City
  - Shop location (required): Use current GPS / Pin on map (MapLocationPicker with geofence circle)
  - Radius meters; Switch “Block check-in outside this range”
  - Status Active/Inactive
- Branch details: status, GPS, tabs/sections for people & month sales

#### Staff (Employees tab)
- People list for employees (search/filter, cards with position · branch, status)
- FAB/add → Person form
- Managers / Admins via More

#### Person form (Employee or Manager)
- Full name, email, phone, branch dropdown
- Role/Position (employee positions: Sales Executive, Cashier, Store Associate, Technician, Support, Other)
- Status Active/Inactive
- Edit: Reset password confirm, Transfer branch (history), deactivate
- Create: temporary password

#### Sales / Expenses / Cash / Attendance / Reports
- See Shared operational screens (BA routes under `/ba/...`)

#### More menu (complete)
Managers · Manage Admins · Sales · Customers · Customer orders · Expenses · Accounts & Cash · Daily P&L Report · Attendance · Password Requests · Notifications · Business Profile · Menu (if canEditMenu) · Expense Categories · Shift Management · Activity Logs · Profile · Change Password · Help · About · Logout

#### Business Profile
- Name, email, phone, address, status
- **Customer ordering page** card:
  - Public link `/b/{slug}`
  - Slug, Display name, Account name, EasyPaisa/JazzCash number, Payment instructions
  - Payment QR upload/replace/remove preview
  - Publish page

#### Menu
- Explainer: variant price replaces base; add-ons add on top
- Categories as cards; products with thumb, name, price/variants, unavailable flag
- FAB add category; Add product dialog:
  - Name, Description, Image URL **or** gallery upload (≤200KB → base64)
  - Base price; Available switch
  - Variants multiline `Name=price`; Add-ons multiline `Name=price`
- Save in AppBar

#### Customer orders
- Search by order/name/phone/reference
- Horizontal chips: All, To be verified, Rejected, Accepted, Preparing, Ready, Completed (with counts)
- Order cards → detail: line items, payment proof/reference, status actions through workflow

#### Customers
- Stats: Customers, Accounts, Points held
- Search; filters All / Accounts / Guests
- Row: name, contact, orders, spent, points → detail with order history + loyalty

#### Expense Categories
- List + FAB dialog Name + Active

#### Shift Management
- List: name, start–end, grace minutes + FAB dialog

#### Password Requests
- Pending employee recovery requests → approve/reset password

---

### 4.4 Manager

#### Home
- Greeting
- Check-in status card + Check In/Out button
- KPIs: Today’s Sales, Today’s Expenses, Present, Late
- Chips: Add Sale, Add Expense, Employees
- Branch chip (fixed)

#### Tabs
Staff (employees of branch) · Sales · Attend (action screen) · More

#### More
Customer orders · Customers · Expenses · Team Attendance · Password Requests · Reports · Notifications · Profile · Change Password · Help · About · Logout

#### Extra routes
`/mg/sales/add`, expenses, attendance history, team attendance, reports, daily P&L, password requests, customers/:id

---

### 4.5 Employee

#### Home
- Greeting
- Soft card: Not checked in / Checked In + Check In/Out CTA
- KPIs: Today’s Sales, Today’s Expenses, Should have (MTD), This Month Sales
- Quick Actions row: Add Sale, Add Expense, View Cash, Attendance

#### Tabs
Sales · Expenses · Attend · More

#### More
Customer orders · Profile · Change Password · My Branch (dialog with address/GPS) · Accounts & Cash · Notifications · Password Recovery · Help · About · Logout  
Footer: `StaffPro · v1.0.0`

---

### 4.6 Shared operational screens

#### Sales list
- Period filter (Today / Yesterday / Week / Month / Custom) with Change
- Total Sales summary card + record count
- List cards: amount, category, payment, date, branch/user; edit/delete (role rules)
- Optional hourly chart
- Empty: No sales in this period
- Add/Edit Sale: Branch (locked for MG/EMP), Date, Amount, Sale Type (Retail/Services/Products/Other), Payment (Cash/Card/Bank Transfer/Other), Description

#### Expenses list
- Same period pattern
- Add/Edit Expense: Branch, Date, Amount, Category (from expense categories), Payment Method, Description

#### Attendance action
- Large circular status (Checked Out / Checked In)
- Card: Shift name, Hours, Shop, Shop GPS ±radius, Status, Distance at check-in (In range / OUT OF RANGE)
- Primary Check In / Check Out (GPS permission required)
- Outlined Attendance History

#### Attendance history
- Period filters; team mode for BA/MG
- Cards per record; BA full-access can **Correct attendance** (set checkout now + reason dialog, audited)

#### Cash / Accounts
- Month-to-date notice (resets on 1st)
- KPIs: Total sales, Total expenses, Cash in hand, Card, Online, Total should-have
- Admin: Branch selector + **By staff** breakdown cards

#### Daily P&L Report
- Day-wise sale, expenses, remaining & profit table/list

#### Reports hub
- Date range picker card
- Daily P&L tile
- Type tiles (sales, expenses, attendance, by-branch…) → list + CSV share

#### Notifications
- List with unread styling; Mark all read

#### Profile
- Large initials avatar, name, role · business
- Info card (email, phone, branch…)
- Edit profile dialog (name, phone)
- Change password link, Logout

#### Change Password
- Current / New / Confirm

#### Password Recovery (employee)
- Explains send request to Manager/Admin; status of request

#### Help & Support / About App
- Help content; About: “Employee Management App”, Version 1.0.0, branding

#### Map location picker
- Full-screen map, pin, geofence radius preview, confirm location

---

## 5. Key user flows (for navigation diagrams)

1. **Bootstrap:** Splash → Super Admin Signup (secret) → Login → Add Business wizard → BA login → Add Branch (pin GPS) → Add Manager/Employee → operations
2. **Daily ops (Employee):** Login → Home Check In → Add Sale / Expense → Attend tab Check Out → Cash view
3. **Manager day:** Check In → Staff → Sales → Team Attendance → Approve password requests → Orders status updates
4. **BA oversight:** Dashboard KPIs → Branch filter → Reports / Daily P&L → Correct attendance → Publish menu & ordering page → Verify customer payments
5. **Customer order ops:** Ordering site creates `PENDING_PAYMENT_VERIFICATION` → Staff opens Customer orders → verify/reject → Accepted → Preparing → Ready → Completed
6. **Password recovery:** Forgot password email **or** in-app request → BA/MG Password Requests → reset

---

## 6. Data entities visible in UI (summary)

Users, Businesses, Branches (+ lat/lng/geofence), Shifts, ExpenseCategories, Sales, Expenses, Attendance, Notifications, AuditLogs, Assignments (transfer history), PasswordRequests, PublicMenus (categories/products/variants/addons/images), PublicBusinesses (slug, payment QR), Customers (ordering), CustomerOrders, LoyaltyAccounts.

**Attendance statuses:** Present, Absent, Late, On Time, Early Leave, Missing Checkout  
**Notification types:** check-in/out (employee/manager), password reset, branch transfer, user/business created, sale/expense added, system

---

## 7. UX rules & edge cases to preserve in redesign

- Soft delete only — never hard-delete primary records in UI; use Inactive/Archived
- Manager cannot switch branches; always show fixed branch
- “All branches” selection must block adding sale/expense until a specific branch is chosen
- Outside geofence: flag by default; optionally block via settings/branch switch
- Cash figures: only **Cash** payments affect cash-in-hand; monthly resets on the 1st
- Unread notification badges on header + Alerts tab
- Empty states for every list (copy exists above)
- Loading: buttons show spinner; streams show CircularProgressIndicator
- Confirm dialogs for Logout, Delete sale/expense, Reset password, Correct attendance
- Mobile-first; location permission critical for attendance
- Currency formatting with `Rs`
- Greetings by time of day

---

## 8. What to redesign (prompt goals for ChatGPT / designer)

Produce a **complete mobile UI/UX system** for StaffPro including:

1. Information architecture + navigation maps for all 4 roles (bottom nav + More menus + push stacks)
2. High-fidelity wireframes or screen specs for every screen listed above
3. Component library: headers, KPI cards, list cards, filters/chips, forms, FABs, status badges, empty states, attendance ring, order status chips
4. Visual system aligned with logo (navy + orange + professional neutrals) — improve on current blue-primary if needed, but keep brand recognizable
5. Image specs: logo placements, product image sizes/ratios, QR upload UI, avatar rules, map pin
6. Microcopy for empty/error/success states
7. Accessibility: tap targets, contrast, badge readability
8. Optional tablet/web adaptation notes

**Do not invent features outside this brief** unless marked as “future” (e.g. PDF export, FCM push polish, photo profiles via Storage).

---

## 9. Suggested ChatGPT prompt

Paste this brief and say:

> Redesign StaffPro as a polished mobile app UI/UX. Keep all roles, screens, fields, and navigations from this brief. Deliver: (1) navigation maps per role, (2) screen-by-screen layout descriptions with components and states, (3) a cohesive visual design system matching the StaffPro logo (navy/orange/people + checkmark), (4) interaction notes for attendance geofence, orders workflow, and branch selector. Prioritize clarity for non-technical restaurant/retail staff.

---

## 10. File map (source of truth in codebase)

| Area | Path |
| --- | --- |
| Routes | `lib/core/routing/app_router.dart` |
| Shell / header / branch bar | `lib/features/shells/app_shell.dart` |
| Auth | `lib/features/auth/auth_screens.dart` |
| Super Admin | `lib/features/super_admin/super_admin_screens.dart` |
| BA / MG / EMP dashboards & More | `lib/features/operations/role_screens.dart` |
| Sales, expenses, attendance, people, reports… | `lib/features/shared/shared_screens.dart` |
| Cash & daily P&L | `lib/features/shared/cash_and_reports.dart` |
| Menu | `lib/features/operations/menu_screen.dart` |
| Orders | `lib/features/operations/customer_orders_screen.dart` |
| Customers | `lib/features/operations/customers_screen.dart` |
| Map picker | `lib/features/shared/map_location_picker.dart` |
| Theme / colors | `lib/core/theme/` |
| UI kit | `lib/core/widgets/ui_kit.dart` |
| Logo | `assets/staffpro_logo.png`, `lib/core/widgets/brand_logo.dart` |
| Constants | `lib/core/constants/app_constants.dart` |
| Schema | `firebase/SCHEMA.md` |
| Overview | `README.md` |

---

*Generated from the StaffPro Flutter codebase for external UI/UX redesign.*
