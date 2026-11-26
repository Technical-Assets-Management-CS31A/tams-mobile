# Deployed Backend – Endpoints for Mobile

Taken from the deployed backend's OpenAPI spec (`/openapi/v1.json`, the one Scalar shows) on 2026-11-22, and checked again on 2026-11-26 against the spec and the `tams-backend` repo. The backend URL is in `env/prod.json` (git-ignored). It is left out of this file because the repo is public.

The spec lists 142 endpoints (137 on 2026-11-22). The new ones are `GET /auth/me` and the kiosk card enrollment endpoints (`/auth-cards/enrollment`). About 30 are useful to the mobile app. The rest are for the web admin, the kiosk or the room stations.

Good to know:

- Paths start at the root (`/auth/login`, `/loans`). There is no `/api/v1` prefix on the deployed backend. The local backend still uses `/api/v1`, so the local default in `ApiConstants.baseUrl` keeps it.
- Every endpoint except `/health` and `/auth/login` needs `Authorization: Bearer <token>`.
- Unknown paths return 401, not 404. A wrong path looks like a wrong password.

## 1. Login fix

Login returned 401 because the app was written for the local backend.

- [x] Set `API_BASE_URL` in `env/prod.json` to the bare host, without `/api/v1`.
- [x] Call `POST /auth/login`. There is no `/auth/login-mobile` on the deployed backend.
- [x] Send `{email, password}` instead of `{identifier, password}`.
- [ ] Confirm that the login response puts `accessToken` and `refreshToken` in the body. The spec doesn't describe the response. The app reads the tokens from the top level or from inside `data`, but it can't read them from cookies.

## 2. Already used by the app

A checked item means the app's path and body match the deployed spec.

- [x] `POST /auth/login` – sign in.
- [x] `GET /approvals/pending` – Pending Approvals list and freeze status.
- [x] `POST /approvals/{sessionId}/approve` with `{destinationRoomId, classLengthMinutes}` – approve with a room and class length.
- [x] `POST /approvals/{sessionId}/decline` – decline.
- [x] `GET /loans?approvedBy=me&status=open&sort=dueAt&pageSize=100` – My Loans.
- [x] `GET /loans/{id}` – loan detail.
- [x] `GET /notifications?page=&pageSize=` – Alerts list. `unread=true` is also available.
- [x] `POST /notifications/{id}/read` – mark an alert as read.

Still to check against the live backend:

- [ ] **Loan filter values.** The parameters `approvedBy` and `status` exist, but the spec doesn't say whether it accepts the values `me` and `open`.
- [ ] **Photo URLs.** The app doesn't build `/approvals/{sessionId}/photo` or `/loans/{id}/photo` itself. It loads the `photoUrl` that `/approvals/pending` and `/loans/{id}` return. The local backend sends `/api/...` paths. If the deployed one does too, photos get a 401 and the app shows initials instead. If you see `/api/` in a real response, ask the backend team to drop the prefix.

## 3. Ready for features not built yet

These match unchecked items in [mobile-phase-plan.md](mobile-phase-plan.md). Check one off when the app uses it.

### Auth and session (Phase 1)

- [x] `POST /auth/refresh` with `{refreshToken}` – renew the 15-minute token instead of signing out (NFR-9).
- [ ] `POST /auth/logout` with an optional `{refreshToken}` – cancel the refresh token on sign-out.
- [ ] `POST /auth/change-password` with `{currentPassword, newPassword}` – change password screen. Not in the PRD; nice to have.
- [x] `GET /auth/me` – the signed-in user (`UserDto`: id, email, name, role, default room). New on 2026-11-25. The app calls it to renew an expiring token before it connects to the live hub. It could also refresh the user's name and role on start.

### Push notifications (Phase 2)

This was the Phase 2 blocker. The endpoints now exist.

- [ ] `POST /device-tokens` with `{token, platform}` – send the phone's push token to the backend (FR-2.1, O3). `platform` is `ANDROID`, `IOS` or `WEB`. The backend pushes approval requests and every stored notice (late arrival, overdue, missing, anomaly) to the tokens it has. A user with no token gets no pushes.
- [ ] `POST /device-tokens/unregister` with `{token}` – stop pushes to this phone on sign-out.

### Loans and freezes (Phase 3)

- [x] `GET /loans?approvedBy=me&status=...&sort=-checkedOutAt&page=` – Loan History with a status filter (FR-2.5). `status` takes `open`, `ACTIVE`, `OVERDUE`, `RETURNED`, `MISSING` or `CANCELLED`; `sort` takes `checkedOutAt` or `dueAt`, with `-` for newest first. It also takes `q`, `roomId`, `studentId`, `assetId` and `type`.
- [x] Read the `freezes` array from `GET /approvals/pending` – a freeze banner that names the item and the student (US-06). Each freeze has `id`, `reason` (`LATE_ARRIVAL_LIMIT`, `OVERDUE` or `MISSING`), `frozenAt`, `loanId`, `loanNo`, `assetCode`, `assetName` and `studentName`.

### Offline QR audit (Phase 4)

In the order the audit flow uses them:

- [x] `GET /rooms?page=&pageSize=&q=` – list the rooms to audit.
- [x] `GET /rooms/{id}/roster` – download the room's roster for offline use (FR-7.3).
- [x] `GET /audits?roomId=&status=` – resume an unfinished audit.
- [x] `POST /audits` with `{roomId}` – start an audit.
- [x] `POST /audits/{id}/scans:batch` with `{scans: [{clientScanId, scannedValue, scannedAt}]}` – sync offline scans. `clientScanId` prevents duplicates (FR-7.4, NFR-8). `scannedValue` is the raw QR text.
- [ ] `GET /assets/{id}` – show what a scanned QR is (name, home room).
- [x] `POST /audits/{id}/complete` – finish the audit. Roster items that weren't scanned become missing (FR-7.5).
- [x] `POST /audits/{id}/sign-off` – custodian sign-off.
- [x] `GET /audits/{id}` – audit results after the sync.
- [x] `GET /audits/{id}/report?format=pdf` – open or share the report as `pdf` or `csv` (US-14).

### Staff on mobile (optional)

- [ ] `GET /anomalies?status=open&roomId=&loanId=` – list open anomalies.
- [ ] `POST /anomalies/{id}/acknowledge` and `POST /anomalies/{id}/resolve` – acknowledge an anomaly, or resolve it with a note (FR-4.5).
- [ ] `GET /stations/health` – show whether each station is online or offline (FR-8.2).
- [ ] `GET /dashboard/summary` – summary numbers for a staff home screen.
- [ ] `GET /students/{id}/standing` – a student's warnings, marks and holds (read only).

## 4. Ask the backend team

The spec doesn't cover these.

- [ ] **Response shapes.** The spec documents no 200 responses. Get a sample of the login, `/loans` and `/audits/{id}` responses, or ask the team to add response types.
- [ ] **Roles.** The spec doesn't say which role can call which endpoint. Confirm that instructors can use approvals, loans and notifications, and that custodians can use audits.
- [x] **SignalR hub.** It's at `/hubs/live`, and the JWT goes in `?access_token=`. The hub only sends; it has no methods to call. Each user joins `user:{id}`. Staff (ADMIN, TECH_STAFF, CUSTODIAN) also join `staff`. An instructor receives `approval.requested`, `instructor.frozen`, `instructor.unfrozen`, `warning.issued`, `anomaly.raised`, `anomaly.resolved` and `loan.overdue`, all about their own loans. The app uses it.
- [ ] **Loan status events for instructors.** `asset.statusChanged` and `loan.created` go to `staff` only, so the app can't see a check-in at the room (In Transit → Verified in Room) until My Loans reloads. Ask for `asset.statusChanged` to also go to the approving instructor's `user:{id}` group (in `LoanRules` and `DeviceEndpoints`). PRD 6.4 lists it for staff dashboards only, so the PRD would need that row too.
- [x] **`platform` values** for `POST /device-tokens`: `ANDROID`, `IOS` or `WEB` (case doesn't matter).
- [x] **QR content.** Does a QR label hold only the asset UUID? If so, the app can match it against the roster offline.

## 5. Not for mobile

The mobile app doesn't call these. They're listed so nobody wires them up by mistake.

- **Counter kiosk:** checkout (`/kiosk/{stationCode}/session(s)`, `/kiosk/sessions/{id}/...`) and enrollment (`/kiosk/enrollment/sessions/{id}/...`).
- **ESP32 room stations:** `POST /stations/{code}/scans` and `POST /stations/{code}/heartbeat`.
- **Web admin, people:** `/users`, `/students`, `/students:import`, `/sections`, `/enrollment`, `/students/{id}/fingerprints`.
- **Web admin, inventory:** asset create, edit and delete, `/assets/{id}/image`, `/restore`, `/damage-liability`, `/asset-categories`, `/assets/qr-sheet`, `GET /assets/{id}/qr`.
- **Web admin, rooms and stations:** room create, edit and delete, `POST /rooms/{id}/roster`, station CRUD and `rotate-key`.
- **Web admin, cards:** `/auth-cards`, and card enrollment at the kiosk (`/auth-cards/enrollment`, `/auth-cards/enrollment/{id}`, `/auth-cards/enrollment/{id}/cancel`).
- **Web admin, staff loan actions:** `POST /loans/{id}/mark-missing`, `/return`, `/void`, `PUT /loans/{id}/room`, `PUT /loans/{id}/borrower`.
- **Web admin, violations:** `/violations`, `/warnings`, `/marks`, `/holds`, `/freezes/{id}/lift`, `/liabilities/{id}/settle`.
- **Web admin, other:** `/events`, `GET /rooms/{id}/checklist:export`, `POST /audits/import`.
- **System and monitoring:** `/settings`, `/data-retention`, `/audit-log`, `/borrowers/check`, `/rooms/{id}/occupancy`, `/assets/{id}/history`, `/health`.
