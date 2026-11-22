# Deployed Backend – Endpoints for Mobile

Taken from the deployed backend's OpenAPI spec (`/openapi/v1.json`, the one Scalar shows) on 2026-11-22. The backend URL is in `env/prod.json` (git-ignored). It is left out of this file because the repo is public.

The spec lists **137 endpoints**. About **30** are useful to the mobile app. The rest are for the web admin, the kiosk or the room stations.

## ⚠️ Fix first: the app can't sign in yet

The app was written for the local backend. The deployed one differs in three ways, which is why login returns 401:

| | App calls now | Deployed backend expects |
|---|---|---|
| Path prefix | `/api/v1/...` | none, paths start at the root (`/auth/login`, `/loans`, ...) |
| Login endpoint | `POST /auth/login-mobile` | `POST /auth/login` (there is no `login-mobile`) |
| Login body | `{identifier, password}` | `{email, password}` |

- [x] Set `API_BASE_URL` in `env/prod.json` to the bare host, without `/api/v1`
- [x] Change `ApiConstants.loginPath` to `/auth/login`
- [x] Send `email` instead of `identifier` in the login body
- [ ] Confirm the login response puts `accessToken` and `refreshToken` in the body. The spec doesn't describe it. The app now accepts them at the top level or inside `data`, but not as cookies only.

Every endpoint except `/health` and `/auth/login` needs `Authorization: Bearer <token>`. Unknown paths also return 401, not 404, so a wrong path looks like a wrong password.

## 1. Already used by the app

| Endpoint | Used for | Matches? |
|---|---|---|
| `POST /auth/login` `{email, password}` | Sign in | ❌ see the fix above |
| `GET /approvals/pending` | Pending Approvals list and freeze status | ✅ |
| `POST /approvals/{sessionId}/approve` `{destinationRoomId, classLengthMinutes}` | Approve with room and class length | ✅ same body |
| `POST /approvals/{sessionId}/decline` | Decline | ✅ |
| `GET /approvals/{sessionId}/photo` | Student photo on the approval card | ✅ |
| `GET /loans?approvedBy=me&status=open&sort=dueAt&pageSize=100` | My Loans | ✅ all params exist; check the values `me` and `open` |
| `GET /loans/{id}` | Loan detail | ✅ |
| `GET /loans/{id}/photo` | Checkout photo in loan detail | ✅ |
| `GET /notifications?page=&pageSize=` | Alerts list | ✅ (`unread=true` also available) |
| `POST /notifications/{id}/read` | Mark alert as read | ✅ |

## 2. Available now for mobile features not built yet

These match unchecked items in [mobile-phase-plan.md](mobile-phase-plan.md).

### Auth and session (Phase 1)

| Endpoint | Body | Unblocks |
|---|---|---|
| `POST /auth/refresh` | `{refreshToken}` | Renew the 15-min token instead of signing out (NFR-9) |
| `POST /auth/logout` | `{refreshToken}` (optional) | Cancel the refresh token on sign-out |
| `POST /auth/change-password` | `{currentPassword, newPassword}` | Change password screen (not in the PRD, nice to have) |

### Push notifications (Phase 2 blocker – now unblocked)

| Endpoint | Body | Unblocks |
|---|---|---|
| `POST /device-tokens` | `{token, platform}` | **Send the phone's push token to the backend (FR-2.1, O3).** The endpoint now exists. |
| `POST /device-tokens/unregister` | `{token}` | Stop pushes to this phone on sign-out |

### Loans and freezes (Phase 3)

| Endpoint | Unblocks |
|---|---|
| `GET /loans?approvedBy=me&status=...&page=` | Past loan history with a status filter (FR-2.5). Also supports `q`, `roomId`, `studentId`, `assetId`, `sort`. |
| `GET /approvals/pending` → `freezes` array | Freeze banner naming the item and student (US-06). The data is already in the response; the app just doesn't read it. |

### Offline QR audit (Phase 4)

| Endpoint | Body / params | Step |
|---|---|---|
| `GET /rooms?page=&pageSize=&q=` | | Audit room list |
| `GET /rooms/{id}/roster` | | Download the room roster for offline use (FR-7.3) |
| `GET /audits?roomId=&status=` | | Resume an unfinished audit |
| `POST /audits` | `{roomId}` | Start an audit |
| `GET /audits/{id}` | | Audit results after sync |
| `POST /audits/{id}/scans:batch` | `{scans: [{clientScanId, scannedValue, scannedAt}]}` | Sync offline scans. `clientScanId` prevents duplicates (FR-7.4, NFR-8). `scannedValue` is the raw QR text. |
| `POST /audits/{id}/complete` | | Finish; unscanned roster items become missing (FR-7.5) |
| `POST /audits/{id}/sign-off` | | Custodian sign-off |
| `GET /audits/{id}/report?format=pdf` | `format=pdf` or `csv` | Open or share the report (US-14) |
| `GET /assets/{id}` | | Show what a scanned QR is (name, home room) |

### Staff on mobile (optional)

| Endpoint | Use |
|---|---|
| `GET /anomalies?status=open&roomId=&loanId=` | Open anomalies list |
| `POST /anomalies/{id}/acknowledge` / `resolve` | Acknowledge or resolve with a note (FR-4.5) |
| `GET /stations/health` | Station Online / Offline view (FR-8.2) |
| `GET /dashboard/summary` | Summary numbers on a staff home screen |
| `GET /students/{id}/standing` | A student's warnings, marks and holds (read only) |

## 3. Not for mobile

| Group | Endpoints | Used by |
|---|---|---|
| Kiosk checkout | `/kiosk/{stationCode}/session(s)`, `/kiosk/sessions/{id}/fingerprint`, `/asset`, `/photo`, `/confirm`, `/cancel` | Counter kiosk |
| Kiosk enrollment | `/kiosk/enrollment/sessions/{id}/...` | Counter kiosk |
| Room stations | `POST /stations/{code}/scans`, `POST /stations/{code}/heartbeat` | ESP32 room stations |
| People admin | `/users/...`, `/students/...`, `/students:import`, `/sections/...`, `/enrollment/...`, `/students/{id}/fingerprints/...` | Web admin |
| Inventory admin | `POST/PUT/DELETE /assets...`, `/assets/{id}/image`, `/assets/{id}/restore`, `/assets/{id}/damage-liability`, `/asset-categories/...`, `/assets/qr-sheet`, `GET /assets/{id}/qr` | Web admin |
| Rooms and stations admin | `POST/PUT/DELETE /rooms...`, `POST /rooms/{id}/roster`, `/stations/...` (CRUD, `rotate-key`) | Web admin |
| Cards | `/auth-cards/...` | Web admin |
| Loan actions | `POST /loans/{id}/mark-missing`, `/return`, `/void`, `PUT /loans/{id}/room`, `PUT /loans/{id}/borrower` | Web admin (staff) |
| Violations | `/violations`, `/warnings/...`, `/marks/...`, `/holds/...`, `/freezes/{id}/lift`, `/liabilities/{id}/settle` | Web admin (staff) |
| Events | `/events/...` | Web admin |
| Audit admin | `GET /rooms/{id}/checklist:export`, `POST /audits/import` | Web admin |
| System | `/settings/...`, `/data-retention/...`, `/audit-log`, `/borrowers/check`, `/rooms/{id}/occupancy`, `/assets/{id}/history`, `/health` | Web admin, monitoring |

## 4. Not in the spec – ask the backend team

- [ ] **Response shapes.** Every 200 response is undocumented in the spec. Get a sample of the login, `/loans` and `/audits/{id}` responses, or ask the backend team to add response types.
- [ ] **Roles.** The spec doesn't say which role can call what. Confirm instructors can use approvals, loans and notifications, and custodians can use audits.
- [ ] **SignalR hub.** WebSocket hubs don't show up in OpenAPI. Confirm whether a hub exists and its path, or settle on pushes plus polling.
- [ ] **`platform` values** for `POST /device-tokens` (for example `android` / `ios`).
- [ ] **QR content.** Does a QR label hold just the asset UUID, so the app can match it against the roster offline?
