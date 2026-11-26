# TAMS Mobile – Phase Plan

Mobile (Flutter) scope from the PRD (§6.6 screens, F2, F6, F7, §6.4 events, NFR-9/14), checked against the `develop` branch as of 2026-11-26.

`[x]` done · `[ ]` not done · ⚠️ = partly done, see note on the line

## Phase 1 – Foundations (Sprint 1)

- [x] Flutter project with feature folders (data / domain / presentation), Riverpod and go_router
- [x] Dio client for the .NET backend with a base URL override via `--dart-define=API_BASE_URL`
- [x] Log interceptor that hides tokens and passwords
- [x] Errors turned into readable messages from RFC 7807 problem details (`Failure`)
- [x] Login screen using `POST /auth/login-mobile`
- [x] Session saved in secure storage and restored when the app starts
- [x] Splash screen and router that sends signed-out users to login
- [x] Sign-out button that clears the saved session
- [x] Bottom tabs: Approvals, My Loans, Alerts, Audit (each tab keeps its own back stack)
- [x] Firebase setup for Android (`google-services.json`)
- [x] Makefile shortcuts and CI pinned to the same Flutter version
- [x] Renew the access token with the refresh token (`/auth/refresh-token-mobile`) instead of signing out after 15 min (NFR-9)
- [ ] Call `POST /auth/logout` on sign-out so the server cancels the refresh token
- [ ] Remove the unused `cloud_firestore` dependency

## Phase 2 – Instructor approvals (Sprint 2: F2, US-04)

- [x] Pending Approvals list from `GET /approvals/pending`
- [x] Card shows student name, number, section, checkout photo and every item
- [x] 120 s countdown per request, corrected for the phone's clock being off
- [x] Approve sheet with destination room picker, pre-filled with the instructor's default room (FR-2.2)
- [x] Class length picker: 1.5, 2, 2.5 or 3 h, default 1.5 h (FR-2.2)
- [x] Approve via `POST /approvals/{id}/approve` with `destinationRoomId` and `classLengthMinutes`
- [x] Decline via `POST /approvals/{id}/decline`
- [x] Expired requests stay on screen as denied until dismissed, with Approve disabled
- [x] Pull to refresh, plus error and empty states
- [x] Push permission request and Firebase registration
- [x] Push received while the app is open shows a banner with a "View" button
- [x] Tapping a push opens the right tab or loan
- [x] `approval.requested` push reloads the Approvals list
- [ ] **Send the phone's push token to the backend (FR-2.1, O3).** No longer blocked: the endpoints are deployed. Until this is done, no pushes reach the phone.
  - [ ] Once signed in and registered with FCM, send `POST /device-tokens` with `{token, platform}`, where `platform` is `ANDROID` or `IOS`
  - [ ] Send it again when FCM gives a new token (`onRegistered` fires again) and after every sign-in. The backend moves a token it already has to whoever sends it, so a shared phone follows the last user
  - [ ] On sign-out, send `POST /device-tokens/unregister` with `{token}` before the session is cleared, since it needs the access token. The backend only removes the caller's own token, and calling it twice is fine
  - [ ] If either call fails, don't block sign-in or sign-out. Try again on the next app start or sign-in. On `409 DEVICE_TOKEN_CONFLICT`, retry once
  - [ ] Keep the token out of debug logs (the redacting log interceptor)
  - [ ] Remove the `TODO` in `PushNotifications._onRegistered`
  - [ ] Tests: sent on sign-in, sent again when the token changes and for a new user, removed on sign-out, a failed call changes nothing on screen
  - [ ] On a real phone: a kiosk checkout's approval push arrives within 3 s (FR-2.1, US-04), and a late arrival or overdue notice arrives as a push (US-05)
- [ ] Reload pending approvals from the server every few seconds while the screen is open, in case a push is missed (Risk: "Instructors miss approval pushes")
- [ ] Sound on approval push notifications (Risk mitigation, PRD 10.2)

## Phase 3 – Loans, alerts and freezes (Sprint 3: F2, F6, US-05 to US-07)

- [x] My Loans: open loans the instructor approved, from `GET /loans?approvedBy=me&status=open`
- [x] Live status per loan: At Counter, In Transit, Verified in Room, Anomaly, Overdue, Missing
- [x] Countdown to the due time, urgent loans listed first
- [x] My Loans reloads every minute, on loan-related pushes and when the app comes back to the foreground
- [x] Loan detail: checkout photo, room, class length, due time including grace period, approval ledger
- [x] Alerts list from `GET /notifications`, with paging
- [x] Alert types: late arrival warning, anomaly (wrong room / transit timeout), overdue, missing
- [x] Alert shows student name and section, warning number (1 to 4+) and whether a penalty was triggered (US-05, US-07)
- [x] Unread badge on the Alerts tab and mark as read on tap (`POST /notifications/{id}/read`)
- [x] Tapping an alert about a loan opens that loan
- [x] Freeze banner on Approvals, with Approve disabled while frozen (FR-2.3)
- [x] `INSTRUCTOR_FROZEN` error from the server shown as a clear message
- [x] Freeze banner names the reason, item and student behind each freeze, from the `freezes` array of `GET /approvals/pending` (US-06)
- [x] Freeze banner also shown on My Loans (PRD 6.6)
- [x] Loan History from My Loans: every loan the instructor approved, newest first, filtered by All / Open / Returned / Missing / Cancelled, with paging (FR-2.5)
- [x] Decided: SignalR live updates (PRD 6.1). The app connects to `/hubs/live` while signed in and reloads Approvals, Alerts and My Loans when an event arrives, and everything after a reconnect. The PRD already says SignalR, so it needs no change.
- [ ] ⚠️ My Loans still reloads every minute: the hub sends `asset.statusChanged` (In Transit → Verified in Room) to staff only. Ask the backend team to also send it to the approving instructor, then drop the poll.

## Phase 4 – Offline QR audit (Sprint 4: F7, US-13, US-14)

- [x] Audit tab replaces the placeholder screen
- [x] Audit room list: rooms from the API with a "Download roster" button (`GET /rooms/{id}/roster`)
- [x] Local database for rosters, audits and scans (works with no network)
- [x] Start an audit (`POST /audits`), or start it offline and create it on the server on reconnect
- [x] Camera QR scanner (camera permission on Android and iOS)
- [x] Each scan marked matched, misplaced (belongs to another room) or unknown, with on-screen feedback (FR-7.3)
- [x] Each scan saved locally with a `client_scan_id` and the phone's scan time
- [x] Offline queue counter on the scanner screen
- [x] Sync queued scans on reconnect via `POST /audits/{id}/scans:batch`, with no duplicates (FR-7.4, NFR-8)
- [x] Audit summary: unscanned roster items listed as missing (FR-7.5)
- [x] Submit the audit (`POST /audits/{id}/complete`)
- [x] Open or share the PDF report (`GET /audits/{id}/report?format=pdf`) (US-14)
- [ ] Tests: 3 offline runs with 0 lost and 0 duplicated scans (SC-8)

## Phase 5 – Roles, platforms and UAT (Sprint 4)

- [x] Read the user's role from the login response or JWT
- [ ] Show tabs by role: Instructor gets Approvals / My Loans / Alerts, Lab Custodian gets Audit, Technical Personnel gets Audit + Alerts
- [ ] iOS Firebase setup (`GoogleService-Info.plist`, APNs key) and a real bundle ID instead of `com.example.tamsMobile` (NFR-14)
- [ ] Check it runs on Android 10+ and iOS 15+ (NFR-14)
- [x] Release build pointing at the deployed backend URL (HTTPS)
- [ ] End-to-end with the kiosk: approval push arrives within 3 s and decline / 120 s timeout denies the borrow (US-04)
- [ ] End-to-end: transit timeout and overdue reach the instructor's phone as pushes and alerts (US-05, O3)
- [ ] End-to-end: 4th late warning and overdue freeze the instructor, and unfreezing works (US-06, US-07)
- [ ] Integration test: kiosk, web and mobile show the same loan state (Gate 9.2)
- [ ] Fallback tests on mobile: Wi-Fi drop during an audit, expired session, missed push
- [ ] UAT survey with instructors and custodians (SC-11)

## Optional (only if time allows)

- [ ] Staff acknowledge / resolve anomalies from the phone (`/anomalies/{id}/acknowledge`, `/resolve`)
- [ ] Station Offline alerts for technical staff (FR-8.3)
