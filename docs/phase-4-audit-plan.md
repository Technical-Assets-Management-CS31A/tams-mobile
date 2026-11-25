# Phase 4 – Offline QR Audit: Implementation Plan

Builds the Audit tab from [mobile-phase-plan.md](mobile-phase-plan.md) Phase 4 (PRD F7, US-13, US-14, FR-7.3 to 7.5, NFR-8, SC-8). The contract below comes from `tams-backend` `dev` (`Inventory/InventoryAuditEndpoints.cs`) as of 2026-11-25. Each numbered section is one PR, in this order.

## Decisions

- Only CUSTODIAN, TECH_STAFF and ADMIN see the Audit tab. Full role-based tabs stay in Phase 5.
- Offline, a valid asset QR that isn't on the roster shows as **pending** and gets its result (misplaced or unknown) from the server on sync.
- Local storage uses `sqflite` with hand-written SQL.
- The Sign off button is shown to TECH_STAFF and ADMIN only. Custodians submit and share the PDF.
- Packages: `sqflite`, `path`, `mobile_scanner`, `connectivity_plus`, `uuid`, `path_provider`, `open_filex`, `share_plus`; `sqflite_common_ffi` for tests.
- Scanning the same QR twice in one audit shows "Already scanned" and saves nothing.
- Local data is stored per user ID, so one user's queue never syncs under another user's login.
- An audit started offline gets the server's `startedAt` (the time it reconnected). The app shows the phone's start time, and scans keep the phone's time. No backend change needed.

## Backend contract

- `GET /rooms?q=&page=&pageSize=` (max 100) returns `{items: [{id, code, name, building, floor, isStorage, status}], total, page, pageSize}`. Open to any role.
- `GET /rooms/{id}/roster` returns `{room: {id, code, name}, items: [{id, assetCode, name, category, type, status, serialNo, qrPayload}], downloadedAt}`.
- A roster is every asset whose home room is that room and that isn't retired, borrowable ones too. A laptop out on loan therefore counts as missing in an audit of its storage room.
- `POST /audits {roomId}` returns 201 `{audit, room, roster}`. The server sets `startedAt` to its own clock.
- `GET /audits?roomId=&status=IN_PROGRESS` returns `{items: [audit], page, pageSize, total}`. Each audit has `startedByUserId`.
- `POST /audits/{id}/scans:batch {scans: [{clientScanId, scannedValue, scannedAt}]}` accepts 1 to 1000 scans and returns `{accepted, duplicates, results: [{clientScanId, result, assetId, duplicate, assetCode?, name?}]}`. Re-sending a scan is safe.
- Batch errors: 409 `SYNC_IN_PROGRESS` means retry. 409 `AUDIT_NOT_IN_PROGRESS` means the audit is already completed.
- `POST /audits/{id}/complete` returns `{audit, items}`. The server adds the missing rows. Scans sent after this are rejected.
- `GET /audits/{id}/report?format=pdf` returns 409 while the audit is in progress. `POST /audits/{id}/sign-off` is for staff only.
- QR text is `tams:asset:<uuid>`. A bare UUID is also accepted.
- Enum values are UPPER_SNAKE: `MATCHED`, `MISPLACED`, `UNKNOWN`, `MISSING`, and `IN_PROGRESS`, `COMPLETED`, `SIGNED_OFF`.
- The login body has `user: {id, email, firstName, lastName, role}`. The JWT also carries `role`.

## 0. Prerequisite – token refresh

An offline audit easily runs past the 15-minute access token. Today the first sync after reconnecting gets a 401 and signs the user out.

- [x] Renew the token with `POST /auth/refresh {refreshToken}` on a 401, then retry the request (Phase 1 item, NFR-9)
- [x] Sign out only if the refresh fails

## 1. Groundwork

- [x] Add the packages listed above
- [x] Add `id` and `role` to `User`, parsed from the login body and saved with the session
- [x] Sessions saved before this change read `role` and `sub` from the JWT
- [x] Hide the Audit tab from instructors; `/audit` redirects them home
- [x] Custodians land on Audit after signing in
- [x] Change the Audit tab's subtitle to "Room inventory checks" and its icon to a QR icon
- [x] Add the camera permission text: iOS `NSCameraUsageDescription`, Android manifest

## 2. Local database

- [x] `AuditDatabase` (sqflite), schema version 1, with an `onUpgrade` hook
- [x] `rooms` table: cached room list
- [x] `roster_items` table: `room_id`, `asset_id`, code, name, category, `downloaded_at`
- [x] `audits` table: `local_id`, `server_id` (null until created), `room_id`, `user_id`, status, timestamps
- [x] `scans` table: `client_scan_id` (PK), `local_audit_id`, `scanned_value`, `scanned_at`, `local_result`, `server_result`, asset code and name, `synced_at`
- [x] Every query is filtered by the signed-in user's ID
- [x] DAO tests on an in-memory database (`sqflite_common_ffi`)

## 3. Rooms and rosters

- [x] Room list from `GET /rooms` with search and paging, cached for offline use
- [x] "Download roster" per room (`GET /rooms/{id}/roster`) shows the item count and when it was downloaded
- [x] "Download again" refreshes a roster
- [x] Offline: show cached rooms, disable downloads and show why
- [x] A room with an open audit shows "Resume" instead of "Start"

## 4. Start and resume

- [x] Start online: `POST /audits`, then save the server ID and the returned roster
- [x] Start offline: create a local audit with no server ID (needs a downloaded roster)
- [x] On reconnect: reuse an `IN_PROGRESS` audit I started for that room if one exists, otherwise `POST /audits`
- [x] Save `server_id` as soon as it's known, so a retry never creates a second audit
- [x] One open audit per room per phone

## 5. Scanner

- [x] `mobile_scanner` camera screen with a torch toggle
- [x] Parse `tams:asset:<uuid>` or a bare UUID; any other text is unknown
- [x] Local result: on the roster = matched, valid UUID not on the roster = pending, anything else = unknown
- [x] Save the scan with a new `client_scan_id` (UUID v4) and the phone's scan time before showing feedback
- [x] Coloured banner and a haptic tap per result, with the asset code and name
- [x] Ignore the same value seen again within 2 s (the camera reports a code many times)
- [x] Same asset scanned again in this audit shows "Already scanned"
- [x] Progress: "X of Y found", plus counts of pending and unknown scans
- [x] Offline queue counter ("N waiting to sync") and an online/offline indicator
- [x] Camera permission denied: show a message with an "Open settings" button

## 6. Sync

- [x] `AuditSyncService` runs one sync at a time
- [x] Create the server audit first if needed, then send unsynced scans in batches of 500
- [x] Mark a scan synced only when its `clientScanId` comes back in `results`
- [x] Store the server's result, asset code and name; pending scans become misplaced or unknown
- [x] Sync after each scan when online, when the connection returns, when the app resumes, and from a "Sync now" button
- [x] Network error: keep the queue and retry on the next trigger
- [x] 409 `SYNC_IN_PROGRESS`: retry after a short delay
- [x] 409 `AUDIT_NOT_IN_PROGRESS`: stop syncing and say the audit was completed elsewhere

## 7. Summary and submit

- [x] Summary lists matched, misplaced, unknown and missing items (roster items not scanned) (FR-7.5)
- [x] Missing items that the roster shows as on loan get an "On loan" tag, so they aren't mistaken for lost ones
- [x] Submit works only when online with 0 unsynced scans; otherwise explain why
- [x] Confirmation sheet before submitting shows the missing count
- [x] `POST /audits/{id}/complete`; the server's counts and missing list replace the local ones
- [x] A completed audit is read-only; its local scans are cleared once the server confirms

## 8. Report and sign-off

- [x] Download the PDF with Dio (auth header) to the temp folder
- [x] Open it (`open_filex`) or share it (`share_plus`) (US-14)
- [x] Each room shows its recent completed audits (`GET /audits?roomId=`) so a report can be opened again
- [x] Sign off button on `COMPLETED` audits for TECH_STAFF and ADMIN (`POST /audits/{id}/sign-off`)

## 9. Sign-out safety

- [x] The sign-out sheet warns when scans haven't synced yet
- [x] Unsynced scans stay on the phone for that user and sync at their next sign-in

## 10. Tests

- [x] Unit: QR parsing and local results
- [x] Unit: sync with a fake API covering a lost response, a resend, a partial batch and both 409s
- [x] Unit: offline start, then create on reconnect, reusing an existing audit
- [x] Widget: scanner feedback, queue counter, Submit disabled while scans are unsynced
- [x] Widget: the Audit tab is hidden from instructors
- [ ] Manual: scans survive force-closing the app mid-audit
- [ ] Manual SC-8: 3 airplane-mode runs; the phone's scan count equals `GET /audits/{id}` items, with 0 lost and 0 duplicated

## Test setup (deployed backend, checked 2026-11-25)

- The app talks to the Railway deployment in `env/prod.json`. `/health` is up and reports the database as up.
- Its live OpenAPI spec has every endpoint this plan uses, including `/auth/refresh` and `/assets/qr-sheet`.
- The audit, room and auth code is the same on `main` and `dev`, so the plan holds whichever branch Railway builds.
- Railway runs in Production mode, so the demo seed, the demo accounts and `/sim` (including its reset button) don't exist there.
- [ ] An admin creates a CUSTODIAN and a TECH_STAFF account (`POST /users`)
- [ ] A staff user adds about 20 assets to one lab (`POST /rooms/{id}/roster`) for the SC-8 runs
- [ ] Print the QR labels from `POST /assets/qr-sheet` (custodians can call it too), or show them on a second screen