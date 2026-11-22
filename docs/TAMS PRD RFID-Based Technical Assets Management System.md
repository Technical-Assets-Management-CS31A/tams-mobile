# **TAMS PRD: RFID-Based Technical Assets Management System**

## **1\. Overview**

TAMS replaces the paper logbook in ACLC College of Mandaue laboratories with RFID kiosks, room check-in stations, a web admin portal and an instructor mobile app, so every borrowed asset is authorized, photographed and tracked to the room it was taken to.

| Item | Detail |
| :---- | :---- |
| Product name | Technical Assets Management System (TAMS) |
| Official title | RFID-Based Technical Assets Management System with IoT-Integrated Web and Mobile Applications |
| Institution | ACLC College of Mandaue, BS Computer Science, Capstone 2026 |
| Document type | Product Requirements Document (PRD), v1.0 draft |
| Source of truth | Approved capstone proposal (project files) |
| Coverage | College Building laboratories and classrooms only (SHS Annex excluded) |

### **1.1 Team and ownership**

| Member | Role | Owns in this PRD |
| :---- | :---- | :---- |
| Christian Dave Alicaba | Team Lead and Frontend Developer | Web admin PWA (React \+ TypeScript), kiosk confirmation UI, live status boards |
| Stanleigh Jeddro Morales | Backend and Database Developer | ASP.NET Core API, PostgreSQL schema, state machine, timers, SignalR, violation engine |
| Marc Ejay Cortes | Embedded IoT and Hardware Specialist | Counter kiosk, room check-in stations, ESP32 firmware, enclosures |
| Rajiemae Villa | Mobile Application Developer | Flutter instructor app: approvals, alerts, offline QR audits |
| John Cez Casupanan | Project Governance and QA Lead | Manuscript, sprint tracking, test plans, end-to-end validation |

### 

### **1.2 Problem statement**

Shared laboratory equipment is lent out using handwritten logbooks. This causes four recurring problems:

* **Long lines** at the equipment counter while borrowers write entries by hand.  
* **Lost or unreadable records**, so nobody can prove who had an item last.  
* **No real-time visibility**: staff cannot see which items are out, where they went, or which are overdue.  
* **Weak accountability**: a name in a logbook can be faked, and there is no proof an instructor actually approved the loan.

### **1.3 Product purpose**

TAMS gives the school one auditable digital record for every technical asset. Each checkout is tied to four proofs (instructor card, student fingerprint, item tag, photo) plus an instructor's in-app approval. Each loan is then followed to its destination room through a 10-minute arrival check, and through automatic overdue, penalty and resolution workflows until the item comes back.

### **1.4 Glossary**

| Term | Meaning |
| :---- | :---- |
| Asset | Any tracked piece of school equipment, either borrowable (e.g. projector, laptop) or fixed (e.g. desktop tower in a lab) |
| Counter kiosk | The ESP32 station at the equipment counter with RFID reader, fingerprint sensor, camera, LCD and buttons |
| Room station | Wall-mounted ESP32 RFID reader at a lab entrance that records an asset's arrival |
| Authorization card | ISO14443A RFID card issued to an instructor (or event coordinator) and lent to a student to authorize a borrow |
| Transit window | The 10 minutes after checkout in which the item must be tapped at its destination room station |
| Location anomaly | Raised when the transit window expires without a room check-in (this also gives the student a Late Arrival Warning), or the item is tapped at the wrong room |
| Non-Compliance Mark | A strike recorded against a student the moment a rule is broken (loan overdue, or a 4th Late Arrival Warning); 2 marks block borrowing |
| Approval freeze | Suspension of an instructor's right to endorse new loans while a loan they approved is overdue or missing |
| Heartbeat | Periodic "I'm alive" signal every 30 to 60 seconds from each hardware station |

## **2\. Goals and objectives**

TAMS succeeds when no asset leaves the counter without verified authorization and no asset is unaccounted for beyond 10 minutes after checkout.

### **2.1 Product goals (from the approved proposal)**

1. **Automate borrowing and custody tracking.** Build an IoT ecosystem of RFID counter kiosks and room check-in stations that automates borrowing transactions and verified room-level custody monitoring. (Reservation tracking from the original proposal is dropped to avoid scope creep.)  
2. **Replace paper logbooks.** Provide a centralized, auditable digital record covering real-time availability, biometric borrower accountability and verified room presence.  
3. **Eliminate unverified lending and prevent loss.** Enforce multi-point physical verification at the counter, and catch loss early through transit anomaly timers and multi-tier violation escalations.

### **2.2 Objectives (measurable)**

| \# | Objective | Target |
| :---- | :---- | :---- |
| O1 | Every counter checkout carries instructor card, fingerprint match, item tag, photo and instructor app approval; any failed factor denies the borrow | 100% of loans |
| O2 | Every loan reaches a terminal room state (verified or anomaly) within the transit window | 100% within 10 min \+ 30 s processing |
| O3 | Overdue loans notify the approving instructor's mobile app automatically | 100%, no manual step |
| O4 | Two Non-Compliance Marks block a student from borrowing automatically | 100% enforced at next attempt |
| O5 | Room walkthrough audits work offline and sync on reconnect | No data loss across 3 offline test runs |
| O6 | Station outages are visible on the dashboard | Offline shown within 2 missed heartbeats |

### **2.3 Non-goals**

TAMS does not try to physically stop theft, track continuous position, handle payments, or take reservations. See section 10 for the full out-of-scope list.

## **3\. Users, personas and needs**

Five user types touch TAMS, but only staff and instructors have software accounts; students interact only through their fingerprint at the kiosk.

### **3.1 User roles**

| Role | Account? | Main surface | Can do |
| :---- | :---- | :---- | :---- |
| System Administrator | Yes | Web PWA | Everything: users, roles, rooms, stations, settings, reports |
| Technical Personnel (lab staff) | Yes | Web PWA \+ mobile | Manage inventory, monitor rooms, receive anomaly alerts, resolve violations, run audits |
| Lab Custodian | Yes | Mobile app | Run QR walkthrough audits of fixed room assets, offline included |
| Instructor | Yes | Mobile app | Holds an authorization card, approves or declines borrows, picks the destination room and class length, receives all warnings and overdue notices for loans they approved |
| Event Coordinator | Yes (instructor or staff flagged as coordinator) | Kiosk \+ web | Run batch borrowing and bulk return for an event |
| Student Borrower | No | Counter kiosk only | Borrow with fingerprint \+ instructor's card, return with fingerprint |
| External Auditor / School Director | No | Exported files | Fills exported CSV/Excel checklists that admins re-import |

Class leaders and students are not notified directly. Every notice about a student's loan goes to the instructor's account in the mobile app, and the instructor follows up with the class.

### **3.2 Personas**

**Ma'am Liza, Computer Science instructor.** Handles 4 sections a day and lends her authorization card to a student whenever her class needs a projector. *Needs:* approve a borrow from her phone in a few seconds, know immediately if something she approved arrives late or goes missing, and not have her card used without her knowledge. *Pain today:* she signs the logbook for students she can't see and finds out about losses weeks later.

**Kuya Ben, Laboratory technician (Technical Personnel).** Runs the equipment counter and three computer labs. *Needs:* a live board showing what is out, where it is, and what is late; a single screen to settle missing items and lift penalties. *Pain today:* long counter lines, illegible logbook entries, and no proof of who took an item.

**Ate Joy, Lab custodian.** Does monthly inventory of desktops, monitors and utilities across labs. *Needs:* scan QR labels quickly with a phone, keep working where Wi-Fi drops, and produce a signed report of matched, missing and misplaced items. *Pain today:* paper checklists re-typed into spreadsheets.

**Paolo, 2nd-year BSCS student (Borrower).** Picks up a laptop for his group's lab activity. *Needs:* borrow in under a minute without remembering a password or carrying an extra card; clear feedback when he taps the item at the lab door. *Pain today:* queueing behind classmates writing in the logbook.

**Sir Mark, Department admin (System Administrator).** Owns system setup and reports to the school director. *Needs:* role management, configurable rules (transit window, grace period, warning limit), station health at a glance, and exportable audit reports.

### **3.3 Key user needs**

| \# | Need | Who | Addressed by |
| :---- | :---- | :---- | :---- |
| N1 | Borrow fast without a student account or card | Student | 1:N fingerprint match at kiosk (F1) |
| N2 | Be sure my card isn't misused | Instructor | Mobile push approval (F2) |
| N3 | See where every borrowed item is now | Tech staff | Room check-in \+ live status board (F3, F4) |
| N4 | Be told when something goes wrong, not discover it later | Tech staff, instructor | Anomaly, warning and overdue alerts (F4, F6) |
| N5 | Enforce on-time arrival and returns without chasing people | Tech staff | Warnings, strikes, holds, approval freeze (F6) |
| N6 | Clear penalties once settled | Tech staff | Resolution module (F6) |
| N7 | Lend many items for an event quickly | Coordinator | Batch borrowing (F5) |
| N8 | Audit fixed assets offline | Custodian | Offline QR audit (F7) |
| N9 | Prove the inventory to outside auditors | Admin | Export/import reconciliation, PDF reports (F7) |
| N10 | Know a station is down before users complain | Admin | Heartbeat health board (F8) |

## **4\. Features, functional requirements and behavior**

TAMS has nine feature areas: F1 to F8 come directly from the approved in-scope list, and F9 is the admin setup every other feature depends on. Reservations were removed to avoid scope creep. Priority uses MoSCoW: **M** \= must have for defense, **S** \= should have, **C** \= could have.

### **4.1 Business rules (system-wide defaults)**

All values below are stored in system\_settings so admins can tune them without code changes.

| Rule | Default | Source |
| :---- | :---- | :---- |
| Checkout factors | Instructor card, fingerprint, item tag, photo, and instructor app approval are all required; any failure denies the borrow, with no override | Team decision |
| Transit window (checkout to room tap) | 10 minutes | Proposal |
| Class length, picked by the instructor at approval | 1.5, 2, 2.5 or 3 hours (default 1.5) | Team decision |
| Return grace period after class ends | 15 minutes (configurable 15 to 30\) | Team decision |
| Loan duration (due\_at) | Checkout \+ class length \+ grace period, so at most 3 h 30 min | Team decision |
| Kiosk session polling interval | 2 seconds | Proposal |
| Instructor approval timeout | 120 seconds, then the session expires and the borrow is denied | Assumption |
| Kiosk session idle timeout | 60 seconds between steps | Assumption |
| Station heartbeat interval | 30 seconds (allowed 30 to 60\) | Proposal |
| Station Warning / Offline | 1 missed window / 2 missed windows | Assumption based on proposal |
| Late Arrival Warnings allowed | 3 per student; the 4th and any later one triggers penalties for the student and the approving instructor | Team decision |
| Warning counter reset | Start of each school term | Assumption |
| Non-Compliance Mark issued | The moment a rule is broken: a loan becomes OVERDUE, or a student gets a 4th or later Late Arrival Warning | Team decision |
| Non-Compliance Marks before block | 2 | Proposal |
| Profile hold | While any loan of the student is OVERDUE or MISSING | Proposal |
| Instructor approval freeze | While any loan they approved is OVERDUE or MISSING, and after a loan they approved causes a 4th or later warning (until staff lift it) | Proposal \+ team decision |

### **4.2 Asset and loan lifecycle**

![Asset and loan lifecycle · 7 states][image1]

Asset and loan lifecycle · 7 states

A wrong-room tap keeps the item in transit and raises an alert. Every move to Location anomaly also records a Late Arrival Warning for the student, even if the item is tapped in late. A return at the kiosk closes the loan from any state, including Overdue and Missing.

### **F1. Counter checkout with four-point authorization (M)**

A student borrows an item at the counter kiosk by presenting an instructor's card, their fingerprint, the item tag and a photo; the instructor then approves on their phone and the student confirms on the LCD. If any one of these fails, the borrow is denied.

**Behavior (happy path):**

1. The kiosk is idle; LCD shows "Tap authorization card".  
2. Instructor's RFID card is tapped. Backend opens a checkout\_session linked to that instructor. Denied if the card is unknown, inactive, or the instructor is under approval freeze.  
3. LCD prompts for fingerprint. The AS608 captures a template; the kiosk uploads it and the backend runs a 1:N match against enrolled student templates. Denied after 3 failed matches, or if the student is blocked or on hold.  
4. LCD prompts for items. Item's anti-metal tag is tapped. Denied if the tag is unknown, the asset is not borrowable, or its status is not IN\_STORAGE.  
5. ESP32-CAM captures a JPEG and uploads it to the session. Denied if the photo cannot be captured or uploaded after one retry.  
6. Backend sends a push approval request to the instructor's mobile app showing student name and photo, item, a destination room picker (pre-filled with the instructor's default room) and a class length picker (1.5, 2, 2.5 or 3 hours).  
7. The instructor picks the room and class length and taps Approve (or Decline). The kiosk learns the result through 2-second polling.  
8. LCD shows borrower name, asset name, destination room and due time. Borrower presses **Confirm** (or **Cancel**).  
9. On Confirm, backend creates the loan, sets asset status to IN\_TRANSIT, starts the 10-minute transit timer and sets due\_at \= checkout \+ class length \+ grace period. Buzzer confirms; LCD shows "Tap item at room door within 10 min".

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-1.1 | Kiosk shall require all four factors (card, fingerprint, tag, photo) in sequence before requesting instructor approval | M |
| FR-1.2 | Failure of any factor, a decline, or an approval timeout shall deny the borrow; there is no manual override | M |
| FR-1.3 | Fingerprint matching shall be 1:N against templates stored in PostgreSQL, not on the sensor | M |
| FR-1.4 | Kiosk shall hold no API keys or credentials; it communicates only via session-scoped endpoints and 2 s polling | M |
| FR-1.5 | Loan shall not be created until instructor approval AND borrower Confirm are both received | M |
| FR-1.6 | Any denial shall show a reason on the LCD (e.g. "Fingerprint not recognized", "Item already borrowed", "Camera error") and log the failed attempt | M |
| FR-1.7 | Session shall expire after approval timeout or idle timeout and return the kiosk to idle | M |
| FR-1.8 | Photo shall be stored and linked to the loan for admin audit | M |
| FR-1.9 | One student may hold more than one active loan only if allowed by setting max\_active\_loans\_per\_student (default 1\) | S |

### 

### 

### **F2. Instructor mobile authorization and audit trail (M)**

Every card tap at the counter produces a real-time approval request on the card owner's phone, and every decision is written to an immutable ledger.

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-2.1 | Backend shall push an approval request to the card owner's mobile app within 3 s of the photo step | M |
| FR-2.2 | Instructor shall Approve or Decline and, when approving, choose the destination room and class length | M |
| FR-2.3 | A frozen instructor shall see a banner explaining the freeze and cannot approve | M |
| FR-2.4 | Each transaction shall write an append-only ledger entry linking instructor, student, asset, photo, approval timestamp and kiosk | M |
| FR-2.5 | Instructor shall see a history of loans they approved with live status | S |
| FR-2.6 | Instructor's app shall be the single channel for all warnings and overdue notices about loans they approved (no direct student or class leader notices) | M |

### **F3. Room check-in stations and room-level custody (M)**

The borrower taps the item at the destination room's wall station within 10 minutes; the station confirms with light and sound and the backend marks the item as verified in the room.

**Behavior:** Station reads tag UID, sends POST /api/stations/{code}/scans. Backend finds the active loan for that asset.

| Case | Backend result | Station feedback |
| :---- | :---- | :---- |
| Correct room, within window | Status IN\_TRANSIT to IN\_ROOM\_VERIFIED, timer stopped | Green LED \+ success chime |
| Correct room, after window (late) | Status LOCATION\_ANOMALY to IN\_ROOM\_VERIFIED; anomaly marked "late arrival, resolved"; the Late Arrival Warning already issued stays | Green LED \+ success chime |
| Wrong room | Status unchanged, WRONG\_ROOM anomaly raised, alert pushed | Red strobe \+ error tone |
| No active loan (unborrowed item) | UNBORROWED\_TAP anomaly logged | Red strobe \+ error tone |
| Unknown tag | Scan logged, no state change | Red strobe \+ error tone |

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-3.1 | Station shall send each scan to the backend over Wi-Fi via HTTP(S) POST | M |
| FR-3.2 | Backend shall respond with a result code the station maps to LED and buzzer patterns within 2 s | M |
| FR-3.3 | Every scan, valid or not, shall be stored in room\_scans | M |
| FR-3.4 | A verified item may be re-tapped at another room only if the loan's room is changed by staff | S |

### **F4. Real-time room monitoring and anomaly alerting (M)**

Staff see each lab's verified items, incoming items with live countdowns, and anomalies, updated through SignalR without refresh.

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-4.1 | Dashboard shall show one card per room: verified items, incoming items with countdown, anomalies | M |
| FR-4.2 | Status board shall group active assets into At Counter, In Transit, Verified in Room, Anomaly, Overdue | M |
| FR-4.3 | When a transit window expires without a valid tap, backend shall raise TRANSIT\_TIMEOUT, set status LOCATION\_ANOMALY, issue a Late Arrival Warning (F6) and push to staff and the approving instructor | M |
| FR-4.4 | Search and filter assets by name, tag, category, room, status and borrower history | M |
| FR-4.5 | Staff shall acknowledge and resolve anomalies with a note | M |

### **F5. Event-based batch borrowing (S)**

Staff create an event; the coordinator unlocks batch mode with one card tap and checks out many items in sequence, all due at the event's end.

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-5.1 | Admin/staff shall create events with title, venue, start, end, responsible coordinator | S |
| FR-5.2 | Coordinator card tap during an active event shall unlock batch mode on the kiosk | S |
| FR-5.3 | Batch mode shall accept sequential item taps without fingerprint; each creates a loan attributed to the coordinator and event | S |
| FR-5.4 | Event loans shall use the event end time plus the grace period as due\_at instead of the class length | S |
| FR-5.5 | Room check-in is not required for event loans unless the venue has a station | S |
| FR-5.6 | Bulk return mode shall accept consecutive tag taps and close matched event loans when "Done" is pressed | S |

### **F6. Violations, warnings, escalations and resolution (M)**

Penalties apply the moment a rule is broken. Late room arrivals build up warnings first; overdue and missing items trigger marks, holds and instructor freezes right away. Only technical personnel can clear them.

**Penalty ladder:**

| Trigger | Student | Approving instructor |
| :---- | :---- | :---- |
| Item not tapped at the room within 10 min (IN\_TRANSIT to LOCATION\_ANOMALY), warnings 1 to 3 | Late Arrival Warning recorded | Notified in app |
| Same, 4th or later warning | Warning \+ Non-Compliance Mark | Notified \+ approval freeze |
| Loan passes due\_at without a return at the kiosk (OVERDUE) | Non-Compliance Mark \+ profile hold | Notified \+ approval freeze |
| Staff declares the item MISSING | Financial liability (replacement cost); hold stays | Freeze stays |
| Student reaches 2 Non-Compliance Marks | Borrowing blocked | None |

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-6.1 | On TRANSIT\_TIMEOUT, issue one Late Arrival Warning per loan and notify the approving instructor | M |
| FR-6.2 | When a student's active warning count exceeds 3, the new warning shall also issue a Non-Compliance Mark to the student and freeze the approving instructor | M |
| FR-6.3 | When now \> due\_at and the loan is open, status shall become OVERDUE and the approving instructor shall be notified in the mobile app | M |
| FR-6.4 | On OVERDUE, issue one Non-Compliance Mark immediately; the first mark is a recorded warning, the second sets the student to BLOCKED | M |
| FR-6.5 | While any loan is OVERDUE or MISSING, the student has an active profile hold and cannot borrow | M |
| FR-6.6 | While any loan they approved is OVERDUE or MISSING, the instructor's approval rights are frozen | M |
| FR-6.7 | Staff may declare a loan MISSING, creating a financial liability equal to the asset's replacement cost (editable) | M |
| FR-6.8 | Resolution screen shall let staff record late return, replacement or payment receipt, clear warnings and marks, lift holds and unfreeze instructors, each with a reason | M |
| FR-6.9 | Warning counts reset at the start of each school term (admin action or scheduled job) | S |
| FR-6.10 | All penalty actions shall be written to the audit log | M |

### **F7. Physical inventory audits (M for QR audit, S for import/export)**

Every asset carries an RFID tag and a QR label with its UUID; custodians scan QR labels with the mobile app to reconcile a room's roster, even offline.

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-7.1 | System shall generate a printable QR label (asset UUID) for every asset | M |
| FR-7.2 | Fixed assets shall be grouped into room rosters (e.g. Computer Laboratory 10\) with batch add and QR generation | M |
| FR-7.3 | Mobile app shall download a room roster, scan QR codes, and record each as matched, misplaced (belongs to another room) or unknown | M |
| FR-7.4 | Audits shall work offline: roster and scans cached locally, synced on reconnect without duplicates | M |
| FR-7.5 | Unscanned roster items at audit completion shall be classified missing | M |
| FR-7.6 | Admin shall export a room checklist as CSV/Excel and re-import a completed one for reconciliation | S |
| FR-7.7 | System shall generate PDF/CSV audit reports with matched, missing, misplaced counts, completion time, variance and sign-off lines | M |

### 

### **F8. Device health monitoring (S)**

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-8.1 | Every kiosk and room station shall send a heartbeat every 30 to 60 s with firmware version, IP, RSSI and uptime | S |
| FR-8.2 | Dashboard shall show Online, Warning (1 missed window) or Offline (2+ missed) per station, updated live | S |
| FR-8.3 | Station going Offline shall alert technical personnel | C |

### **F9. Inventory, users and configuration (M)**

| ID | Requirement | Pri |
| :---- | :---- | :---- |
| FR-9.1 | CRUD for assets, categories, rooms, stations, RFID tags and authorization cards | M |
| FR-9.2 | CRUD for staff and instructor accounts with role assignment | M |
| FR-9.3 | Import student roster (CSV) with sections | M |
| FR-9.4 | Fingerprint enrollment for students at the kiosk in an admin-initiated enrollment mode | M |
| FR-9.5 | Edit business-rule settings (section 4.1) | S |

## **5\. User stories and acceptance criteria**

Each story maps to the features in section 4 and doubles as a UAT test case for the QA lead.

### **5.1 Student borrower**

**US-01 Borrow an item.** As a student, I want to borrow equipment using my fingerprint and my instructor's card so that I don't need an account or extra ID. *(F1)*

* Given a valid instructor card, an enrolled fingerprint, an available item and a working camera, when the instructor approves and I press Confirm, then a loan is created and the LCD shows the destination room and due time (class length \+ grace period).  
* Given my fingerprint is not recognized after 3 tries, or the camera fails, then the borrow is denied and the LCD tells me to see lab staff.  
* Given I have 2 Non-Compliance Marks or an active hold, then the kiosk denies me at the fingerprint step with "Borrowing blocked, see lab staff".

**US-02 Check in at the room.** As a student, I want clear feedback when I tap the item at the lab door so I know my arrival was recorded. *(F3)*

* Given my item is IN\_TRANSIT to Room A, when I tap it at Room A's station within 10 minutes, then I see a green light and chime and the item shows Verified in Room on the dashboard within 3 s.  
* Given I tap it at Room B, then I see a red strobe and error tone and staff get a wrong-room alert.

**US-03 Return an item.** As anyone returning an item, I want to scan my fingerprint and the item so the return is logged without needing the instructor. *(F1)*

* Given an open loan, when an enrolled student scans fingerprint and tag, then the loan closes, the asset becomes IN\_STORAGE, and both borrower and returner are recorded.

### **5.2 Instructor**

**US-04 Approve a borrow.** As an instructor, I want an instant prompt on my phone when my card is used so nobody borrows in my name without my consent. *(F2)*

* Given my card is tapped and the student, item and photo are verified, then within 3 s I get a push showing the student's name, photo, item, a room picker and a class length picker.  
* Given I pick the room and 2 hours and approve, then the loan's due time is checkout \+ 2 h \+ the grace period.  
* Given I tap Decline or ignore it for 120 s, then the borrow is denied and the kiosk returns to idle.

**US-05 Get every notice for my students.** As an instructor, I want all warnings and overdue notices for loans I approved to arrive in my app so I can follow up with the class. *(F2, F6)*

* Given a transit timeout or overdue on a loan I approved, then I receive a push and the item shows in my app's alert list with the student's name and section.

**US-06 Understand a freeze.** As a frozen instructor, I want to see why I can't approve and what clears it. *(F6)*

* Given a loan I approved is OVERDUE, or caused a student's 4th warning, then my app shows a freeze banner naming the item and student, and approval buttons are disabled until staff lift it.

**US-07 Late arrival warnings.** As an instructor, I want late room arrivals to count as warnings first, so a single late tap doesn't punish the student. *(F6)*

* Given a student has 0 to 2 warnings, when their item misses the 10-minute window, then a warning is recorded and I am notified, with no mark or freeze.  
* Given the student already has 3 warnings, when another item misses the window, then the student gets a Non-Compliance Mark and my approval rights are frozen.

### **5.3 Technical personnel**

**US-08 Watch the labs live.** As lab staff, I want one board showing what's out, where it is and what's late. *(F4)*

* Given an item is checked out, then it appears under In Transit on its destination room card with a countdown from 10:00, and moves to Verified or Anomaly without page refresh.

**US-09 Handle an anomaly.** As lab staff, I want to acknowledge and resolve location anomalies with a note. *(F4)*

* Given an open anomaly, when I resolve it with a note, then it leaves the active list and the note and my name are stored.

**US-10 Settle a missing item.** As lab staff, I want to declare an item missing, record the settlement and restore privileges. *(F6)*

* Given an overdue loan, when I mark it MISSING, then a liability with the asset's replacement cost is attached to the student.  
* Given payment or replacement is recorded, when I resolve it, then the hold lifts, the instructor's freeze lifts, and I may clear the related mark with a reason.

**US-11 Manage inventory.** As lab staff, I want to register an asset, attach its RFID tag and print its QR label in one flow. *(F9, F7)*

* Given a new asset with a scanned tag UID, when I save, then the asset is IN\_STORAGE and a printable QR label is generated.

### **5.4 Event coordinator**

**US-12 Batch lend for an event.** As an event coordinator, I want to tap my card once and scan many items so setup is fast. *(F5)*

* Given an active event where I am coordinator, when I tap my card, then the kiosk enters batch mode and each item tap creates a loan due at the event end plus the grace period.  
* Given I bulk-return items and press Done, then all scanned event loans close and unscanned ones remain open and listed.

### **5.5 Lab custodian**

**US-13 Audit a room offline.** As a custodian, I want to scan QR labels even without Wi-Fi so audits don't stall. *(F7)*

* Given I downloaded a roster, when I scan in airplane mode and later reconnect, then all scans sync once, with original timestamps.

**US-14 Get a signed report.** As a custodian, I want a PDF report of matched, missing and misplaced items with sign-off lines. *(F7)*

### **5.6 System administrator**

**US-15 Monitor stations.** As an admin, I want to see if any kiosk or room station is offline. *(F8)*

* Given a station misses 2 heartbeat windows, then its tile turns Offline within 5 s of the second miss.

**US-16 Enroll students.** As an admin, I want to import the roster and enroll fingerprints so students can borrow. *(F9)*

* Given an imported student, when I start enrollment mode on the kiosk and the student scans twice, then the template is saved and linked to that student.

**US-17 Reconcile external audits.** As an admin, I want to export a checklist and re-import it after an auditor fills it, so differences are flagged automatically. *(F7)*

## **6\. Design details**

One ASP.NET Core API and one PostgreSQL database sit at the center; every other part (kiosk, room stations, web PWA, mobile app) talks only to that API over REST, with SignalR pushing live updates to the web and mobile clients.

### **6.1 System architecture**

| Component | Technology | Talks to | How |
| :---- | :---- | :---- | :---- |
| Backend API | C\# ASP.NET Core REST API | PostgreSQL, all clients | REST/JSON over HTTP(S) |
| Real-time hub | ASP.NET Core SignalR | Web PWA, mobile app | WebSockets |
| Background jobs | ASP.NET Core hosted services | Database | Transit timer sweep, overdue sweep, heartbeat sweep (every 15 s) |
| Database | PostgreSQL | Backend only | EF Core / Npgsql |
| File storage | Local disk or object storage behind the API | Backend | Kiosk photos, generated reports, QR label PDFs |
| Web admin | React \+ TypeScript PWA | Backend | REST \+ SignalR |
| Mobile app | Flutter / Dart (Android, iOS) | Backend, push service | REST \+ SignalR \+ push notifications |
| Counter kiosk | ESP32 \+ PN532 \+ AS608 \+ ESP32-CAM \+ LCD2004 \+ buttons | Backend | HTTP POST \+ 2 s HTTP polling |
| Room stations | ESP32 \+ PN532 \+ LEDs \+ buzzer | Backend | HTTP POST on scan \+ heartbeat |

![TAMS architecture · 4 clients, 1 backend, 1 database][image2]

TAMS architecture · 4 clients, 1 backend, 1 database

Hardware stations hold no credentials and only call session-scoped endpoints; all business rules and timers run in the backend.

### **6.2 Kiosk-to-backend protocol (stateless polling bridge)**

The kiosk never stores credentials. It identifies itself by its station\_code and works through a short-lived checkout\_session:

1. POST /api/kiosk/{stationCode}/sessions with the card UID, returns sessionId and next step.  
2. POST /api/kiosk/sessions/{id}/fingerprint with the template payload.  
3. POST /api/kiosk/sessions/{id}/asset with the tag UID.  
4. POST /api/kiosk/sessions/{id}/photo (multipart JPEG from ESP32-CAM).  
5. GET /api/kiosk/sessions/{id} every 2 s until status is APPROVED, DECLINED or EXPIRED. Response includes the 4 lines of LCD text to display.  
6. POST /api/kiosk/sessions/{id}/confirm or /cancel from the pushbuttons.

Returns, batch mode and enrollment use the same session pattern with session\_type \= RETURN, EVENT\_BATCH, EVENT\_RETURN or ENROLLMENT.

### **6.3 Core API endpoints**

| Area | Endpoints (prefix /api) | Used by |
| :---- | :---- | :---- |
| Auth | POST /auth/login, POST /auth/refresh, POST /auth/logout | Web, mobile |
| Kiosk sessions | see 6.2 | Kiosk |
| Room stations | POST /stations/{code}/scans, POST /stations/{code}/heartbeat | Room stations, kiosk |
| Approvals | GET /approvals/pending, POST /approvals/{sessionId}/approve (body: destinationRoomId, classLengthMinutes), POST /approvals/{sessionId}/decline | Mobile |
| Assets | GET/POST /assets, GET/PUT/DELETE /assets/{id}, GET /assets/{id}/history, GET /assets/{id}/qr | Web, mobile |
| Loans | GET /loans?status=\&roomId=\&approvedBy=me, GET /loans/{id}, POST /loans/{id}/mark-missing, PUT /loans/{id}/room | Web, mobile |
| Rooms | GET/POST /rooms, GET /rooms/{id}/occupancy | Web |
| Anomalies | GET /anomalies?status=open, POST /anomalies/{id}/acknowledge, POST /anomalies/{id}/resolve | Web, mobile |
| Violations | GET /students/{id}/standing, POST /warnings/{id}/clear, POST /marks/{id}/clear, POST /liabilities/{id}/settle, POST /holds/{id}/lift, POST /freezes/{id}/lift, POST /warnings/reset-term | Web |
| Notifications | GET /notifications?unread=true, POST /notifications/{id}/read | Mobile, web |
| Events | GET/POST /events, PUT /events/{id}, POST /events/{id}/close | Web |
| Audits | GET /rooms/{id}/roster, POST /audits, POST /audits/{id}/scans:batch, POST /audits/{id}/complete, GET /audits/{id}/report?format=pdf\|csv, GET /rooms/{id}/checklist:export, POST /audits/import | Mobile, web |
| People | GET/POST /users, GET/POST /students, POST /students:import, GET/POST /sections | Web |
| Stations | GET/POST /stations, GET /stations/health | Web |
| Settings | GET/PUT /settings | Web |

All list endpoints support page, pageSize, sort and q. Errors use RFC 7807 problem details with a stable code (e.g. ASSET\_NOT\_AVAILABLE, STUDENT\_BLOCKED, INSTRUCTOR\_FROZEN, PHOTO\_FAILED).

### **6.4 Real-time events (SignalR)**

| Event | Payload | Sent to |
| :---- | :---- | :---- |
| approval.requested | session id, student, asset, photo URL, room options, class length options, expires at | Card-owner instructor |
| loan.created | loan summary, transit deadline, due at | Staff dashboards |
| asset.statusChanged | asset id, old status, new status, room id | Staff dashboards |
| room.occupancyChanged | room id, verified count, incoming list | Staff dashboards |
| anomaly.raised / anomaly.resolved | anomaly summary | Staff, approving instructor |
| warning.issued | student, loan, warning number (1 to 4+), penalty triggered yes/no | Staff, approving instructor |
| loan.overdue | loan, student, section | Staff, approving instructor |
| instructor.frozen / instructor.unfrozen | instructor id, reason loan | That instructor |
| station.healthChanged | station id, health status | Admin dashboards |

When the mobile app is in the background, the same events are delivered as push notifications. Students and class leaders receive nothing directly; the instructor relays to the class.

### **6.5 Web admin PWA screens**

| Screen | Purpose |
| :---- | :---- |
| Login | Staff and admin sign-in |
| Live Dashboard | Status board columns (At Counter, In Transit, Verified in Room, Anomaly, Overdue), room occupancy cards with countdown widgets, station health strip |
| Assets | Searchable inventory table, filters, asset detail with history timeline and photos, tag and QR management |
| Rooms and Rosters | Rooms, stations per room, fixed asset rosters, batch add, QR label printing |
| Loans | Active and past loans, loan detail with checkout photo, class length, due time and approval ledger |
| Anomalies | Open anomalies queue with acknowledge and resolve |
| Violations and Resolution | Students with warnings, marks, holds, liabilities; instructors with freezes; resolve actions; term reset of warnings |
| Events | Create and manage events, see event loans and bulk return status |
| Audits and Reports | Audit sessions, results, export/import, PDF/CSV download |
| People | Staff/instructor accounts, student roster import, sections, enrollment status |
| Stations | Device list, heartbeat health, firmware version |
| Settings | Business rules from 4.1 |

### **6.6 Mobile app screens (Flutter)**

| Screen | Purpose |
| :---- | :---- |
| Login | Instructor, custodian or staff sign-in |
| Pending Approvals | Approve / Decline with student photo, room picker and class length picker |
| My Loans | Live status of loans I approved with due-time countdown; freeze banner when frozen |
| Alerts | Late arrival warnings, transit anomalies, overdue notices for my students |
| Audit: Room list | Download rosters for offline use |
| Audit: Scanner | Camera QR scanner with matched / misplaced / unknown feedback and offline queue counter |
| Audit: Summary | Missing list, submit and sync |

### **6.7 Kiosk LCD (20x4) states**

| State | Line 1 to 4 (example) |
| :---- | :---- |
| Idle | "TAMS Counter" / "Tap auth card" / "or scan finger to" / "return an item" |
| Await fingerprint | "Instr: L. Santos" / "Place finger on" / "sensor" |
| Await item | "Hi, Paolo R." / "Tap item tag" |
| Await approval | "Waiting for" / "instructor approval" / countdown |
| Confirm | "Paolo R." / "Laptop LP-014" / "To: CompLab 10" / "Due 3:15PM  OK/X" |
| Success | "Borrowed\! Tap item" / "at room door within" / "10 minutes" |
| Denied | reason text (e.g. "Camera error") / "Borrow denied" / "See lab staff" |

### **6.8 Room station feedback**

| Result | LED | Buzzer |
| :---- | :---- | :---- |
| Verified | Solid green 2 s | Rising dual-tone chime |
| Wrong room / not borrowed / unknown | Red strobe 3 s | Long low tone |
| Network error | Alternating red/green | Three short beeps; scan queued and retried |

### **6.9 Hardware bill of materials (summary)**

The prototype budget is ₱9,500: one counter kiosk, two room stations, 50 anti-metal tags and 10 faculty cards. The full line-item table is in the approved proposal (Table 1).

### **6.10 Hosting: options and recommendation**

**Recommendation: host on one small cloud virtual machine using Docker Compose, and keep the same Compose file runnable on a laptop as an on-campus fallback.** This avoids school IT approvals and server hardware, lets instructors' phones reach the system over mobile data, and keeps the option to move on-premises later with no code changes.

| Criterion | A. Cloud VM (recommended) | B. Self-hosted at school | C. Hybrid: school server \+ tunnel |
| :---- | :---- | :---- | :---- |
| Setup effort for the team | Low: one VM, Docker Compose, a domain or free subdomain | High: needs a machine, static IP, school IT access, firewall rules | Highest: school server plus a tunnel service to reach it from outside |
| Cost | Covered by free student credits (e.g. Azure for Students, GitHub Student Developer Pack offers) | Hardware the school or team must provide; electricity | Hardware \+ tunnel (free tiers exist) |
| Works if campus internet is down | No: kiosks and stations stop (Wi-Fi alone is not enough) | Yes, as long as campus Wi-Fi and power are up | Yes on campus; remote access stops |
| Instructor phones off campus or on mobile data | Yes | No, unless exposed to the internet | Yes, through the tunnel |
| Push notifications (Firebase) | Yes | Needs outbound internet anyway | Yes |
| Kiosk latency | Higher (internet round trip, typically under a second in-country) | Lowest (local network) | Lowest on campus |
| HTTPS for devices | Easy with Caddy or Nginx \+ Let's Encrypt | Self-signed certificates, harder for ESP32 and phones | Tunnel provides HTTPS |
| Biometric data privacy | Data leaves campus; pick a nearby region (e.g. Singapore), encrypt at rest, get school consent | Best: data stays on school premises | Data stays on campus |
| Maintenance during the term | Team-managed, accessible to all members remotely | Depends on physical access to the server | Two things to maintain |

**How to set up option A:**

1. One Linux VM (2 vCPU, 4 GB RAM is plenty for the pilot) in the closest region.  
2. docker-compose.yml with three services: api (ASP.NET Core), db (PostgreSQL with a mounted volume) and proxy (Caddy for automatic HTTPS).  
3. Nightly pg\_dump backup to object storage or a team drive.  
4. ESP32 firmware calls the API over HTTPS (WiFiClientSecure), which also closes the plain-HTTP risk listed in 8.3.  
5. For the defense, bring a laptop running the same Compose file and a pocket router as a fallback if campus internet fails.

Choose option B only if the school requires biometric data to stay on premises; in that case the same Compose file runs on the school machine.

## **7\. Initial data schema and data models**

The schema has 29 PostgreSQL tables in seven groups; the backend owns it, and the web and mobile apps use the same names in camelCase JSON.

### **7.1 Conventions (all teams)**

| Topic | Rule |
| :---- | :---- |
| Primary keys | uuid (generated by backend, gen\_random\_uuid()); high-volume logs use bigint identity |
| Naming | Database snake\_case; API JSON and TypeScript/Dart models camelCase (due\_at becomes dueAt) |
| Time | All timestamps timestamptz stored in UTC; apps display in Asia/Manila (UTC+8); API sends ISO 8601 |
| Money | numeric(12,2) in PHP |
| Enums | PostgreSQL enum types; API sends the same UPPER\_SNAKE strings; TypeScript uses string unions, Dart uses enums |
| Soft delete | Master data (users, students, assets, rooms, stations) uses deleted\_at; transactional rows are never deleted |
| Audit columns | created\_at, updated\_at on every mutable table |
| RFID UIDs | Uppercase hex string without separators, e.g. 04A2B91C6E5F80 |
| QR payload | tams:asset:\<asset uuid\> |

### **7.2 Enumerations**

| Enum | Values |
| :---- | :---- |
| user\_role | ADMIN, TECH\_STAFF, CUSTODIAN, INSTRUCTOR |
| record\_status | ACTIVE, INACTIVE |
| card\_status | ACTIVE, LOST, REVOKED |
| student\_standing | GOOD, WARNED (1 mark), BLOCKED (2+ marks) |
| asset\_type | BORROWABLE, FIXED |
| asset\_status | IN\_STORAGE, AT\_COUNTER, IN\_TRANSIT, IN\_ROOM\_VERIFIED, LOCATION\_ANOMALY, OVERDUE, MISSING, MAINTENANCE, RETIRED |
| asset\_condition | GOOD, FAIR, DAMAGED |
| loan\_type | STANDARD, EVENT |
| loan\_status | ACTIVE, OVERDUE, RETURNED, MISSING |
| custody\_state | AWAITING\_ARRIVAL, VERIFIED, ANOMALY, NOT\_REQUIRED |
| session\_type | CHECKOUT, RETURN, EVENT\_BATCH, EVENT\_RETURN, ENROLLMENT |
| session\_status | AWAITING\_FINGERPRINT, AWAITING\_ASSET, AWAITING\_PHOTO, AWAITING\_APPROVAL, AWAITING\_CONFIRM, COMPLETED, DECLINED, CANCELLED, EXPIRED, FAILED |
| approval\_decision | PENDING, APPROVED, DECLINED, EXPIRED |
| station\_type | COUNTER\_KIOSK, ROOM\_STATION |
| station\_health | ONLINE, WARNING, OFFLINE |
| scan\_result | VERIFIED, VERIFIED\_LATE, WRONG\_ROOM, NOT\_BORROWED, UNKNOWN\_TAG |
| anomaly\_type | TRANSIT\_TIMEOUT, WRONG\_ROOM, UNBORROWED\_TAP |
| anomaly\_status | OPEN, ACKNOWLEDGED, RESOLVED |
| penalty\_status | ACTIVE, CLEARED (used by warnings, marks, holds, freezes) |
| penalty\_reason | LATE\_ARRIVAL\_LIMIT, OVERDUE, MISSING (used by marks and freezes) |
| liability\_status | OUTSTANDING, SETTLED\_PAYMENT, SETTLED\_REPLACEMENT, WAIVED |
| event\_status | SCHEDULED, ACTIVE, CLOSED, CANCELLED |
| audit\_source | MOBILE, EXTERNAL\_IMPORT |
| audit\_status | IN\_PROGRESS, COMPLETED, SIGNED\_OFF |
| audit\_result | MATCHED, MISSING, MISPLACED, UNKNOWN |
| ledger\_event | CHECKOUT, ROOM\_VERIFIED, LATE\_ARRIVAL\_WARNING, RETURN, OVERDUE, MARKED\_MISSING, SETTLED |

**How asset status is derived from the open loan** (backend sets it; clients only read it):

| Open loan state | assets.status |
| :---- | :---- |
| No open loan, kiosk session holding the asset | AT\_COUNTER |
| loan\_status ACTIVE \+ custody\_state AWAITING\_ARRIVAL | IN\_TRANSIT |
| ACTIVE \+ VERIFIED (or NOT\_REQUIRED) | IN\_ROOM\_VERIFIED |
| ACTIVE \+ ANOMALY | LOCATION\_ANOMALY |
| OVERDUE (any custody state) | OVERDUE |
| MISSING | MISSING |
| No open loan | IN\_STORAGE (or MAINTENANCE / RETIRED if set by staff) |

### **7.3 Entities**

#### **People and access**

**users** (staff, instructors, admins)

| Field | Type | Notes |
| :---- | :---- | :---- |
| id | uuid PK |  |
| employee\_no | varchar(30) unique |  |
| first\_name, last\_name | varchar(80) |  |
| email | citext unique | login |
| password\_hash | text | ASP.NET Identity hash |
| role | user\_role |  |
| is\_event\_coordinator | boolean default false | may unlock batch mode |
| default\_room\_id | uuid FK rooms, null | pre-fills approval room picker |
| status | record\_status |  |
| created\_at, updated\_at, deleted\_at | timestamptz |  |

**device\_tokens**: id uuid PK, user\_id FK users, platform (ANDROID/IOS/WEB), token text unique, last\_seen\_at.

**auth\_cards** (instructor authorization cards)

| Field | Type | Notes |
| :---- | :---- | :---- |
| id | uuid PK |  |
| card\_uid | varchar(20) unique | RFID UID |
| user\_id | uuid FK users | card owner (instructor or coordinator) |
| status | card\_status |  |
| issued\_at | timestamptz |  |

**sections**: id uuid PK, code varchar(30) (e.g. BSCS-2A), program varchar(20), year\_level smallint, school\_year varchar(9) (e.g. 2026-2027), adviser\_user\_id FK users null (for reports only). Unique (code, school\_year).

**students** (no login, no direct notifications)

| Field | Type | Notes |
| :---- | :---- | :---- |
| id | uuid PK |  |
| student\_no | varchar(20) unique |  |
| first\_name, last\_name | varchar(80) |  |
| section\_id | uuid FK sections |  |
| standing | student\_standing | GOOD by default; backend updates |
| active\_warning\_count | smallint default 0 | cached; reset each term |
| active\_mark\_count | smallint default 0 | cached |
| has\_active\_hold | boolean default false | cached |
| status | record\_status |  |
| created\_at, updated\_at, deleted\_at | timestamptz |  |

**fingerprint\_templates**: id uuid PK, student\_id FK students, finger\_index smallint (0 to 9), template bytea, sensor\_model varchar (AS608/R307), quality\_score smallint null, enrolled\_by FK users, enrolled\_station\_id FK stations, created\_at. Unique (student\_id, finger\_index).

#### **Places and devices**

**rooms**: id uuid PK, code varchar(20) unique (e.g. CL10), name (e.g. Computer Laboratory 10), building varchar default 'College Building', floor smallint, is\_storage boolean (equipment counter room), status, timestamps.

**stations**

| Field | Type | Notes |
| :---- | :---- | :---- |
| id | uuid PK |  |
| station\_code | varchar(30) unique | burned into firmware, e.g. KIOSK-01, RS-CL10 |
| type | station\_type |  |
| room\_id | uuid FK rooms | room it guards (kiosk: counter room) |
| name | varchar(80) |  |
| firmware\_version, ip\_address | varchar | from heartbeat |
| last\_heartbeat\_at | timestamptz null |  |
| health | station\_health default OFFLINE | updated by sweep job |
| status, timestamps |  |  |

**station\_heartbeats**: id bigint PK, station\_id FK, received\_at, rssi smallint, uptime\_s int, free\_heap int, firmware\_version. Keep 7 days.

#### **Inventory**

**asset\_categories**: id uuid PK, name unique, description, is\_borrowable boolean.

**assets**

| Field | Type | Notes |
| :---- | :---- | :---- |
| id | uuid PK | encoded in QR label |
| asset\_code | varchar(30) unique | human label, e.g. LP-014 |
| name | varchar(120) |  |
| category\_id | uuid FK asset\_categories |  |
| type | asset\_type | BORROWABLE or FIXED |
| brand, model, serial\_no | varchar null |  |
| rfid\_tag\_uid | varchar(20) unique null | required for BORROWABLE |
| home\_room\_id | uuid FK rooms | storage room, or roster room for FIXED |
| current\_room\_id | uuid FK rooms null | last verified location |
| status | asset\_status default IN\_STORAGE |  |
| condition | asset\_condition default GOOD |  |
| replacement\_cost | numeric(12,2) | used for liabilities |
| acquired\_at | date null |  |
| notes | text null |  |
| created\_at, updated\_at, deleted\_at | timestamptz |  |

A room roster is simply all FIXED assets whose home\_room\_id is that room.

#### **Transactions**

**checkout\_sessions** (kiosk polling bridge)

| Field | Type | Notes |
| :---- | :---- | :---- |
| id | uuid PK | returned to kiosk |
| station\_id | uuid FK stations |  |
| type | session\_type |  |
| status | session\_status |  |
| auth\_card\_id | uuid FK auth\_cards null |  |
| instructor\_user\_id | uuid FK users null | card owner or coordinator |
| student\_id | uuid FK students null | after fingerprint match |
| asset\_id | uuid FK assets null | single-item sessions |
| event\_id | uuid FK events null | batch sessions |
| photo\_file\_id | uuid FK media\_files null | required before approval |
| destination\_room\_id | uuid FK rooms null | from approval |
| class\_length\_minutes | smallint null | from approval: 90, 120, 150 or 180 |
| fingerprint\_attempts | smallint default 0 | max 3 |
| lcd\_lines | jsonb | 4 strings the kiosk displays |
| failure\_code | varchar null | e.g. STUDENT\_BLOCKED, PHOTO\_FAILED |
| expires\_at, created\_at, completed\_at | timestamptz |  |

**approvals**: id uuid PK, session\_id FK checkout\_sessions unique, instructor\_user\_id FK users, decision approval\_decision, destination\_room\_id FK rooms null, class\_length\_minutes smallint null (check 90 to 180), requested\_at, decided\_at null, decided\_device varchar null.

**loans**

| Field | Type | Notes |
| :---- | :---- | :---- |
| id | uuid PK |  |
| loan\_no | varchar(20) unique | e.g. L-2026-000123 |
| type | loan\_type |  |
| asset\_id | uuid FK assets |  |
| student\_id | uuid FK students null | null for EVENT loans |
| approved\_by\_user\_id | uuid FK users null | instructor (STANDARD); receives all notices |
| coordinator\_user\_id | uuid FK users null | EVENT loans |
| event\_id | uuid FK events null |  |
| session\_id | uuid FK checkout\_sessions |  |
| approval\_id | uuid FK approvals null |  |
| checkout\_station\_id | uuid FK stations |  |
| destination\_room\_id | uuid FK rooms null |  |
| photo\_file\_id | uuid FK media\_files | not null for STANDARD |
| status | loan\_status |  |
| custody\_state | custody\_state |  |
| checked\_out\_at | timestamptz |  |
| transit\_deadline\_at | timestamptz null | checked\_out\_at \+ 10 min |
| verified\_at, verified\_station\_id | timestamptz, uuid null | room check-in |
| class\_length\_minutes | smallint null | 90 to 180 (STANDARD) |
| class\_ends\_at | timestamptz | checkout \+ class length, or event end |
| grace\_minutes | smallint | 15 to 30, copied from settings at checkout |
| due\_at | timestamptz | class\_ends\_at \+ grace\_minutes |
| overdue\_at, missing\_at | timestamptz null |  |
| returned\_at | timestamptz null |  |
| returned\_by\_student\_id | uuid FK students null | may differ from borrower |
| return\_station\_id | uuid FK stations null |  |
| notes | text null |  |

Rule: partial unique index on asset\_id where status IN ('ACTIVE','OVERDUE'), so an asset can have only one open loan.

**room\_scans**: id bigint PK, station\_id FK, room\_id FK, tag\_uid varchar, asset\_id FK null, loan\_id FK null, result scan\_result, scanned\_at timestamptz.

**anomalies**: id uuid PK, type anomaly\_type, status anomaly\_status, asset\_id FK, loan\_id FK null, room\_id FK null, station\_id FK null, detected\_at, acknowledged\_by FK users null, acknowledged\_at, resolved\_by FK users null, resolved\_at, resolution\_note text.

**transaction\_ledger** (append-only; a trigger rejects UPDATE and DELETE): id bigint PK, event ledger\_event, loan\_id FK, asset\_id FK, student\_id FK null, instructor\_user\_id FK null, approval\_decided\_at null, photo\_file\_id FK null, station\_id FK null, actor\_user\_id FK null, occurred\_at, details jsonb.

#### **Accountability**

**late\_arrival\_warnings**

| Field | Type | Notes |
| :---- | :---- | :---- |
| id | uuid PK |  |
| student\_id | uuid FK students |  |
| loan\_id | uuid FK loans unique | one warning per loan |
| anomaly\_id | uuid FK anomalies | the TRANSIT\_TIMEOUT that caused it |
| warning\_no | smallint | 1, 2, 3, 4... within the term |
| school\_term | varchar(20) | e.g. 2026-2027-1 |
| triggered\_penalty | boolean | true when warning\_no \> 3 |
| mark\_id, freeze\_id | uuid null | penalties created by this warning |
| status | penalty\_status |  |
| issued\_at, cleared\_at | timestamptz |  |
| cleared\_by, clear\_reason | uuid FK users, text, null |  |

**non\_compliance\_marks**: id uuid PK, student\_id FK, loan\_id FK, reason penalty\_reason, status penalty\_status, issued\_at, cleared\_by FK users null, cleared\_at, clear\_reason text. Unique (loan\_id, reason).

**profile\_holds**: id uuid PK, student\_id FK, loan\_id FK, status penalty\_status, placed\_at, lifted\_by FK users null, lifted\_at, reason text.

**approval\_freezes**: id uuid PK, instructor\_user\_id FK users, loan\_id FK, reason penalty\_reason, status penalty\_status, frozen\_at, lifted\_by FK users null, lifted\_at, lift\_note text.

**liabilities**: id uuid PK, student\_id FK, loan\_id FK unique, asset\_id FK, amount numeric(12,2), status liability\_status, receipt\_no varchar null, settled\_by FK users null, settled\_at, notes text.

#### **Events and audits**

**events**: id uuid PK, title varchar(150), venue\_text varchar(150), venue\_room\_id FK rooms null, starts\_at, ends\_at, coordinator\_user\_id FK users, status event\_status, created\_by FK users, timestamps. Check ends\_at \> starts\_at.

**audits**: id uuid PK, room\_id FK, source audit\_source, status audit\_status, started\_by FK users, started\_at, completed\_at, signed\_off\_by FK users null, signed\_off\_at, expected\_count, matched\_count, missing\_count, misplaced\_count, unknown\_count (int), import\_file\_id FK media\_files null, report\_file\_id FK media\_files null.

**audit\_items**: id uuid PK, audit\_id FK, asset\_id FK null, scanned\_value varchar (raw QR text), result audit\_result, client\_scan\_id uuid unique (dedupes offline re-syncs), scanned\_by FK users, scanned\_at (device time), synced\_at.

#### **System**

**notifications**: id uuid PK, recipient\_user\_id FK users (always a staff or instructor account), type varchar (e.g. LATE\_ARRIVAL\_WARNING, LOAN\_OVERDUE), title, body, payload jsonb, loan\_id FK null, student\_id FK null (who it is about), created\_at, delivered\_at, read\_at.

**media\_files**: id uuid PK, kind (CHECKOUT\_PHOTO, AUDIT\_REPORT, AUDIT\_IMPORT, QR\_SHEET), storage\_path, mime\_type, size\_bytes, sha256, created\_at.

**audit\_log** (admin actions): id bigint PK, actor\_user\_id FK null, actor\_station\_id FK null, action varchar, entity\_type varchar, entity\_id uuid, before jsonb, after jsonb, ip\_address, created\_at.

**system\_settings**: key varchar PK (e.g. transit\_window\_minutes, grace\_minutes, late\_arrival\_warning\_limit), value jsonb, updated\_by FK users, updated\_at.

### **7.4 Relationships**

| From | Relation | To |
| :---- | :---- | :---- |
| users | 1 to many | auth\_cards, device\_tokens, approvals, approval\_freezes, notifications |
| users (instructor) | 1 to many | loans (as approver) |
| sections | 1 to many | students |
| students | 1 to many | fingerprint\_templates, loans, late\_arrival\_warnings, marks, holds, liabilities |
| rooms | 1 to many | stations, assets (home), loans (destination), audits |
| asset\_categories | 1 to many | assets |
| assets | 1 to many | loans (at most 1 open), room\_scans, anomalies |
| checkout\_sessions | 1 to 0..1 | approvals; 1 to 0..many loans (many in batch mode) |
| loans | 1 to many | room\_scans, anomalies, ledger rows, marks; 1 to 0..1 warning, liability |
| anomalies | 1 to 0..1 | late\_arrival\_warnings |
| events | 1 to many | loans |
| audits | 1 to many | audit\_items |

### **7.5 Starter DDL (PostgreSQL)**

The backend lead can paste this into the first EF Core migration or a raw SQL migration and extend it. Remaining tables follow the same pattern from 7.3.

CREATE EXTENSION IF NOT EXISTS pgcrypto;  
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TYPE user\_role AS ENUM ('ADMIN','TECH\_STAFF','CUSTODIAN','INSTRUCTOR');  
CREATE TYPE record\_status AS ENUM ('ACTIVE','INACTIVE');  
CREATE TYPE asset\_type AS ENUM ('BORROWABLE','FIXED');  
CREATE TYPE asset\_status AS ENUM ('IN\_STORAGE','AT\_COUNTER','IN\_TRANSIT','IN\_ROOM\_VERIFIED','LOCATION\_ANOMALY','OVERDUE','MISSING','MAINTENANCE','RETIRED');  
CREATE TYPE loan\_type AS ENUM ('STANDARD','EVENT');  
CREATE TYPE loan\_status AS ENUM ('ACTIVE','OVERDUE','RETURNED','MISSING');  
CREATE TYPE custody\_state AS ENUM ('AWAITING\_ARRIVAL','VERIFIED','ANOMALY','NOT\_REQUIRED');  
CREATE TYPE station\_type AS ENUM ('COUNTER\_KIOSK','ROOM\_STATION');  
CREATE TYPE station\_health AS ENUM ('ONLINE','WARNING','OFFLINE');  
CREATE TYPE penalty\_status AS ENUM ('ACTIVE','CLEARED');  
CREATE TYPE penalty\_reason AS ENUM ('LATE\_ARRIVAL\_LIMIT','OVERDUE','MISSING');

CREATE TABLE rooms (  
  id uuid PRIMARY KEY DEFAULT gen\_random\_uuid(),  
  code varchar(20) NOT NULL UNIQUE,  
  name varchar(100) NOT NULL,  
  building varchar(60) NOT NULL DEFAULT 'College Building',  
  floor smallint,  
  is\_storage boolean NOT NULL DEFAULT false,  
  status record\_status NOT NULL DEFAULT 'ACTIVE',  
  created\_at timestamptz NOT NULL DEFAULT now(),  
  updated\_at timestamptz NOT NULL DEFAULT now(),  
  deleted\_at timestamptz  
);

CREATE TABLE users (  
  id uuid PRIMARY KEY DEFAULT gen\_random\_uuid(),  
  employee\_no varchar(30) UNIQUE,  
  first\_name varchar(80) NOT NULL,  
  last\_name varchar(80) NOT NULL,  
  email citext NOT NULL UNIQUE,  
  password\_hash text NOT NULL,  
  role user\_role NOT NULL,  
  is\_event\_coordinator boolean NOT NULL DEFAULT false,  
  default\_room\_id uuid REFERENCES rooms(id),  
  status record\_status NOT NULL DEFAULT 'ACTIVE',  
  created\_at timestamptz NOT NULL DEFAULT now(),  
  updated\_at timestamptz NOT NULL DEFAULT now(),  
  deleted\_at timestamptz  
);

CREATE TABLE stations (  
  id uuid PRIMARY KEY DEFAULT gen\_random\_uuid(),  
  station\_code varchar(30) NOT NULL UNIQUE,  
  type station\_type NOT NULL,  
  room\_id uuid NOT NULL REFERENCES rooms(id),  
  name varchar(80) NOT NULL,  
  firmware\_version varchar(20),  
  ip\_address varchar(45),  
  last\_heartbeat\_at timestamptz,  
  health station\_health NOT NULL DEFAULT 'OFFLINE',  
  status record\_status NOT NULL DEFAULT 'ACTIVE',  
  created\_at timestamptz NOT NULL DEFAULT now(),  
  updated\_at timestamptz NOT NULL DEFAULT now()  
);

CREATE TABLE asset\_categories (  
  id uuid PRIMARY KEY DEFAULT gen\_random\_uuid(),  
  name varchar(80) NOT NULL UNIQUE,  
  description text,  
  is\_borrowable boolean NOT NULL DEFAULT true  
);

CREATE TABLE assets (  
  id uuid PRIMARY KEY DEFAULT gen\_random\_uuid(),  
  asset\_code varchar(30) NOT NULL UNIQUE,  
  name varchar(120) NOT NULL,  
  category\_id uuid NOT NULL REFERENCES asset\_categories(id),  
  type asset\_type NOT NULL,  
  brand varchar(60), model varchar(60), serial\_no varchar(80),  
  rfid\_tag\_uid varchar(20) UNIQUE,  
  home\_room\_id uuid NOT NULL REFERENCES rooms(id),  
  current\_room\_id uuid REFERENCES rooms(id),  
  status asset\_status NOT NULL DEFAULT 'IN\_STORAGE',  
  condition varchar(10) NOT NULL DEFAULT 'GOOD',  
  replacement\_cost numeric(12,2) NOT NULL DEFAULT 0,  
  acquired\_at date,  
  notes text,  
  created\_at timestamptz NOT NULL DEFAULT now(),  
  updated\_at timestamptz NOT NULL DEFAULT now(),  
  deleted\_at timestamptz,  
  CHECK (type \= 'FIXED' OR rfid\_tag\_uid IS NOT NULL)  
);

CREATE TABLE loans (  
  id uuid PRIMARY KEY DEFAULT gen\_random\_uuid(),  
  loan\_no varchar(20) NOT NULL UNIQUE,  
  type loan\_type NOT NULL,  
  asset\_id uuid NOT NULL REFERENCES assets(id),  
  student\_id uuid,            \-- FK students  
  approved\_by\_user\_id uuid REFERENCES users(id),  
  coordinator\_user\_id uuid REFERENCES users(id),  
  event\_id uuid,              \-- FK events  
  session\_id uuid NOT NULL,   \-- FK checkout\_sessions  
  checkout\_station\_id uuid NOT NULL REFERENCES stations(id),  
  destination\_room\_id uuid REFERENCES rooms(id),  
  photo\_file\_id uuid,         \-- FK media\_files  
  status loan\_status NOT NULL DEFAULT 'ACTIVE',  
  custody\_state custody\_state NOT NULL,  
  checked\_out\_at timestamptz NOT NULL DEFAULT now(),  
  transit\_deadline\_at timestamptz,  
  verified\_at timestamptz,  
  verified\_station\_id uuid REFERENCES stations(id),  
  class\_length\_minutes smallint CHECK (class\_length\_minutes BETWEEN 90 AND 180),  
  class\_ends\_at timestamptz NOT NULL,  
  grace\_minutes smallint NOT NULL CHECK (grace\_minutes BETWEEN 15 AND 30),  
  due\_at timestamptz NOT NULL,  
  overdue\_at timestamptz,  
  missing\_at timestamptz,  
  returned\_at timestamptz,  
  returned\_by\_student\_id uuid, \-- FK students  
  return\_station\_id uuid REFERENCES stations(id),  
  notes text,  
  CHECK (due\_at \= class\_ends\_at \+ make\_interval(mins \=\> grace\_minutes)),  
  CHECK (type \= 'EVENT' OR (student\_id IS NOT NULL AND approved\_by\_user\_id IS NOT NULL  
         AND photo\_file\_id IS NOT NULL AND class\_length\_minutes IS NOT NULL))  
);

CREATE UNIQUE INDEX ux\_loans\_one\_open\_per\_asset  
  ON loans(asset\_id) WHERE status IN ('ACTIVE','OVERDUE');  
CREATE INDEX ix\_loans\_transit\_sweep  
  ON loans(transit\_deadline\_at) WHERE custody\_state \= 'AWAITING\_ARRIVAL';  
CREATE INDEX ix\_loans\_overdue\_sweep  
  ON loans(due\_at) WHERE status \= 'ACTIVE';

CREATE TABLE late\_arrival\_warnings (  
  id uuid PRIMARY KEY DEFAULT gen\_random\_uuid(),  
  student\_id uuid NOT NULL,   \-- FK students  
  loan\_id uuid NOT NULL UNIQUE REFERENCES loans(id),  
  anomaly\_id uuid NOT NULL,   \-- FK anomalies  
  warning\_no smallint NOT NULL,  
  school\_term varchar(20) NOT NULL,  
  triggered\_penalty boolean NOT NULL DEFAULT false,  
  mark\_id uuid,               \-- FK non\_compliance\_marks  
  freeze\_id uuid,             \-- FK approval\_freezes  
  status penalty\_status NOT NULL DEFAULT 'ACTIVE',  
  issued\_at timestamptz NOT NULL DEFAULT now(),  
  cleared\_by uuid REFERENCES users(id),  
  cleared\_at timestamptz,  
  clear\_reason text  
);

### **7.6 Shared client model example**

The web (TypeScript) and mobile (Dart) apps should mirror the API DTOs exactly. Example for the most-used object:

export type AssetStatus \=  
  \| 'IN\_STORAGE' \| 'AT\_COUNTER' \| 'IN\_TRANSIT' \| 'IN\_ROOM\_VERIFIED'  
  \| 'LOCATION\_ANOMALY' \| 'OVERDUE' \| 'MISSING' \| 'MAINTENANCE' \| 'RETIRED';

export interface LoanDto {  
  id: string;  
  loanNo: string;  
  type: 'STANDARD' \| 'EVENT';  
  status: 'ACTIVE' \| 'OVERDUE' \| 'RETURNED' \| 'MISSING';  
  custodyState: 'AWAITING\_ARRIVAL' \| 'VERIFIED' \| 'ANOMALY' \| 'NOT\_REQUIRED';  
  asset: { id: string; assetCode: string; name: string; status: AssetStatus };  
  student: { id: string; studentNo: string; fullName: string; sectionCode: string } \| null;  
  approvedBy: { id: string; fullName: string } \| null;   // instructor  
  destinationRoom: { id: string; code: string; name: string } \| null;  
  checkedOutAt: string;          // ISO 8601 UTC  
  transitDeadlineAt: string \| null;  
  verifiedAt: string \| null;  
  classLengthMinutes: 90 \| 120 \| 150 \| 180 \| null;  
  classEndsAt: string;  
  graceMinutes: number;          // 15 to 30  
  dueAt: string;                 // classEndsAt \+ graceMinutes  
  returnedAt: string \| null;  
  photoUrl: string \| null;  
  lateArrivalWarningNo: number \| null;  
}

## **8\. Non-functional requirements, assumptions and constraints**

The prototype must run reliably on the campus 2.4 GHz Wi-Fi for a full school day, respond at the kiosk within a few seconds per step, and protect student biometric data wherever it is hosted.

### **8.1 Non-functional requirements**

| ID | Category | Requirement |
| :---- | :---- | :---- |
| NFR-1 | Performance | Each kiosk step (card, fingerprint, tag) gets a backend response in 2 s or less (p95) |
| NFR-2 | Performance | Full checkout, excluding instructor reaction time, completes in 60 s or less |
| NFR-3 | Performance | Room station scan to dashboard update in 3 s or less |
| NFR-4 | Performance | 1:N fingerprint match over 2,000 templates in 1.5 s or less |
| NFR-5 | Timing accuracy | Transit and overdue sweeps run every 15 s, so alerts and warnings fire at most 15 s late |
| NFR-6 | Availability | Backend available 7:00 to 21:00 on school days during UAT; stations auto-reconnect to Wi-Fi |
| NFR-7 | Reliability | Room stations queue up to 20 scans in memory and retry if the network drops briefly |
| NFR-8 | Reliability | Offline mobile audits never lose or duplicate scans (enforced by client\_scan\_id) |
| NFR-9 | Security | Staff and instructor logins use hashed passwords and JWT access tokens (15 min) with refresh tokens |
| NFR-10 | Security | Role-based access control enforced on every API endpoint |
| NFR-11 | Privacy | Fingerprint templates never leave the backend; checkout photos are visible only to staff and the approving instructor; data encrypted at rest if cloud-hosted, in line with the Philippine Data Privacy Act of 2012 (RA 10173\) |
| NFR-12 | Auditability | Ledger and audit log are append-only; every warning and penalty change records who, when and why |
| NFR-13 | Usability | Kiosk flow usable without training: one instruction per LCD screen, buzzer feedback on every step |
| NFR-14 | Compatibility | Web PWA supports current Chrome and Edge, installable; mobile app supports Android 10+ and iOS 15+ |
| NFR-15 | Maintainability | Business rules configurable in system\_settings; API documented with OpenAPI (Swagger); whole backend deployable with one Docker Compose file |

### **8.2 Assumptions**

1. Deployment covers the equipment counter plus 2 laboratory rooms in the College Building (matches the 2 room stations in the budget).  
2. The student roster (names, student numbers, sections) is provided by the school as a CSV and seeded into the database.  
3. Students enroll their fingerprints once at the kiosk with staff assistance before they can borrow.  
4. Each instructor has exactly one authorization card; 10 cards are enough for the pilot.  
5. Instructors relay warnings and overdue notices to their students; the system never contacts students or class leaders directly.  
6. Late Arrival Warning counts reset at the start of each school term.  
7. Campus Wi-Fi reaches the counter and both lab doors with usable signal, and has internet access if cloud hosting is chosen.  
8. Push notifications on mobile use Firebase Cloud Messaging.  
9. Hosting follows the recommendation in 6.10 (cloud VM with Docker Compose) unless the school requires on-premises data.

### **8.3 Constraints (from the approved proposal)**

* **Geography:** College Building laboratories only; SHS Building Annex and off-campus excluded.  
* **Manual check-in compliance:** room verification depends on the borrower tapping the item within 10 minutes.  
* **No physical prevention:** readers cannot stop theft; accountability comes from fingerprint, photo, instructor approval, timers and penalties.  
* **Discrete checkpoints:** tracking is state-based at checkpoints, not continuous location.  
* **Metal interference:** metal items require ferrite-backed anti-metal 13.56 MHz tags.  
* **Network dependency:** kiosks and stations need live Wi-Fi (plus internet if cloud-hosted); checkouts cannot finalize offline.  
* **External data sync:** student roster is pre-seeded; no live integration with the school MIS or registrar.  
* **Timeline:** single term; testing is manual functional, integration and UAT rather than automated CI.  
* **Device endpoints:** the proposal allows plain HTTP without per-device signatures; if cloud-hosted, devices should use HTTPS (see 6.10).  
* **Wi-Fi quality:** 2.4 GHz 802.11 b/g/n only; latency or captive portals delay checkouts and dashboard updates.  
* **Sensor limits:** AS608 may reject wet or scarred fingers, and because every factor is mandatory, such students cannot borrow until re-enrolled; ESP32-CAM needs adequate counter lighting.  
* **Power:** 5V DC from wall outlets, no UPS or battery; stations go offline in outages.  
* **Budget:** ₱9,500 prototype hardware budget.

## **9\. Success criteria and metrics**

The system is ready for defense when every Must requirement passes UAT and the pilot metrics below are met over at least 5 school days of live use.

### **9.1 Pilot metrics**

| \# | Metric | Target | How measured |
| :---- | :---- | :---- | :---- |
| SC-1 | Checkouts with all 4 factors \+ instructor approval (0 loans created with a missing factor) | 100% | loans joined to approvals and media\_files |
| SC-2 | Median checkout time (card tap to Confirm) | 60 s or less (vs. logbook baseline to be timed in week 1\) | session created\_at to completed\_at |
| SC-3 | Loans resolved to VERIFIED or ANOMALY within 10 min 15 s | 100% | loans.verified\_at / anomaly detected\_at |
| SC-4 | Correct room taps confirmed on dashboard within 3 s | 95% or more | test log timestamps |
| SC-5 | Overdue notices sent automatically | 100% of overdue loans | notifications rows |
| SC-6 | Two-strike block and 4th-warning penalty enforced | 100% in test cases | UAT scripts |
| SC-7 | Fingerprint false rejection rate | 5% or less on enrolled students with clean dry fingers | kiosk attempt logs |
| SC-8 | Offline audit sync | 0 lost, 0 duplicated scans over 3 runs | audit\_items vs. device count |
| SC-9 | Station offline detection | Shown within 2 heartbeat windows, 100% | unplug test |
| SC-10 | Audit report accuracy | Matches a manual count of the same room exactly | side-by-side audit |
| SC-11 | User satisfaction | Average 4.0 / 5 or higher (ISO 25010 or SUS-based survey) from staff, instructors and students | UAT survey |

### **9.2 Acceptance gates**

* ☐ All Must (M) functional requirements pass test cases written by QA  
* ☐ End-to-end checkout, room check-in, return, overdue and resolution flows pass on real hardware  
* ☐ Integration test: kiosk, room stations, web and mobile all reflect the same loan state  
* ☐ Fallback tests: Wi-Fi drop, power cycle, approval timeout, wrong room, unknown tag  
* ☐ UAT sign-off from the laboratory in-charge and capstone adviser

## **10\. Out of scope, risks and decisions**

### **10.1 Explicitly out of scope**

| Excluded | What TAMS does instead |
| :---- | :---- |
| Reservations | Removed to avoid scope creep; assets are borrowed on the spot only |
| Direct notices to students or class leaders | All notices go to the approving instructor's mobile app |
| Manual override of a failed checkout factor | Any failed factor denies the borrow |
| SHS Building Annex and off-campus coverage | College Building labs only; transfers to SHS are unauthorized and unmonitored |
| Continuous location tracking (RTLS, GPS, sub-meter) | Room-level checkpoints only |
| Perimeter gate portals (EAS/UHF gates, turnstiles) | Deliberate contact scans at counter and room stations |
| Student software accounts or student RFID cards | Fingerprint at the kiosk only |
| Automated damage or condition diagnostics | Condition recorded manually by staff |
| Online payment gateways (card, e-wallet) | Liabilities and receipts recorded administratively |
| Simultaneous multi-tag (anti-collision) reading | Sequential one-by-one taps, including batch mode |
| Multi-campus / multi-tenant support | Single-school database |
| Facial recognition, AI detection, video analytics | Static JPEG photo for human review |
| Smart door locks / access control | Room station only logs arrivals |
| Anti-tamper tags or peel sensors | Physical inspection on return |

### **10.2 Risks**

| Risk | Impact | Mitigation |
| :---- | :---- | :---- |
| AS608 templates are in a vendor format; server-side 1:N matching may need a custom matcher | High: blocks F1 | Spike in sprint 1: test matching on the server; fallback is syncing templates to the sensor's onboard library (about 160 to 300 slots) per kiosk |
| Campus internet or Wi-Fi outage (cloud hosting) or weak signal at lab doors | High | Site survey early; request a dedicated SSID or MAC whitelist; station retry queue; laptop fallback running the same Compose file |
| Camera failure now blocks all borrowing, since every factor is mandatory | Medium | Keep a spare ESP32-CAM (budget reserve); check lighting; one automatic retry |
| Device endpoints could be spoofed | Medium | HTTPS, station\_code \+ IP allowlist; per-device keys as future work |
| Instructors miss approval pushes | Medium | 120 s timeout with LCD message; in-app pending list; sound on notification |
| Students forget to tap at the room | Medium | LCD reminder at checkout, poster at doors; 3 warnings before penalties |
| Anti-metal tags detach or are removed | Medium | Strong adhesive plus QR label as backup identity |

### **10.3 Decisions log**

| \# | Question | Decision (2026-10-27) |
| :---- | :---- | :---- |
| D1 | Who approves and picks the room? | Instructors (not "teachers") approve and pick the destination room in the mobile app |
| D2 | How are class leaders notified? | They are not notified directly; every notice goes to the instructor's mobile app |
| D3 | When is a penalty issued? | The moment a rule is broken: transit timeout (as a Late Arrival Warning) or overdue (Non-Compliance Mark); staff can then mark the item Missing |
| D4 | How long is a loan? | Class length of 1.5 to 3 hours, picked at approval, plus a 15 to 30 minute return grace period |
| D5 | Are reservations in scope? | No, removed to avoid scope creep |
| D6 | How are late room arrivals handled? | Each is a Late Arrival Warning; up to 3 are warnings only, the 4th and later trigger a mark for the student and a freeze for the instructor |
| D7 | Where is it hosted? | Still being explored; recommendation in 6.10 is a cloud VM with Docker Compose |
| D8 | What if a factor fails? | The borrow is denied; no override |

### **10.4 Open questions**

1. **Hosting:** confirm cloud VM vs. school server (6.10), and whether the school allows biometric data off campus.  
2. **Warning reset:** do Late Arrival Warnings reset every term (current assumption) or never?  
3. **Wrong-room taps:** should a wrong-room tap also count as a Late Arrival Warning, or only the 10-minute timeout (current design)?  
4. **Class length steps:** are 30-minute steps (1.5, 2, 2.5, 3 h) right, or should instructors enter any end time within the range?

## **11\. Timeline and sprint plan**

TAMS is built in four one-week Scrum sprints from Nov 2 to Nov 28, 2026, after a planning week from Oct 27 to Oct 31\. Progress is reported at a weekly meeting using the Jira KAN board.

![][image3]

TAMS schedule · planning week \+ 4 weekly sprints, Oct 27 to Nov 28, 2026

Each sprint ends with a working demo of its features on real hardware, so integration problems show up weekly instead of in the last week.

### 

### **11.1 Sprint goals and features**

| Phase | Dates (2026) | Sprint goal | Features and stories | Demo at the weekly meeting |
| :---- | :---- | :---- | :---- | :---- |
| Planning | Oct 27 to Oct 31 | Everyone can start coding on Nov 2 | PRD sign-off, Jira board set up, hosting decision (6.10), repos and Docker Compose skeleton, hardware purchased, fingerprint matching spike (risk 1), wireframes | Board populated; fingerprint spike result |
| Sprint 1 | Nov 2 to Nov 7 | Foundations: data, login and each device reading its inputs | F9 (FR-9.1 to 9.4), schema v1, auth; kiosk reads card, tag, fingerprint and photo | Admin adds an asset and a student; kiosk prints every scan to the API |
| Sprint 2 | Nov 9 to Nov 14 | A complete borrow and return at the counter | F1, F2; US-01, 03, 04, 11, 16 | Student borrows a laptop end to end with instructor approval on a phone, then returns it |
| Sprint 3 | Nov 16 to Nov 21 | Items are followed to the room and rules are enforced | F3, F4, F6; US-02, 05 to 10 | Room tap turns a card green live; a missed tap issues a warning; an overdue loan freezes the instructor |
| Sprint 4 | Nov 23 to Nov 28 | Audits, events, health, then test and harden | F7, F8, F5; US-12 to 15, 17; integration, fallback and UAT tests (9.2) | Offline QR audit with PDF report; full UAT run on the deployed system |

Sprint 4 is the heaviest. If it runs short, drop in this order: event batch borrowing (F5, Should), CSV/Excel import of external audits (FR-7.6), offline-station alerts (FR-8.3). Must-have features are all done by the end of Sprint 3\.

### 

### 

### 

### 

### 

### **11.2 Work per team member**

| Sprint | Backend: Stanleigh | Web: Christian | Mobile: Rajiemae | Hardware: Marc | QA and docs: John Cez |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Planning | Schema review, Compose skeleton, hosting setup | Wireframes, design tokens | Wireframes, Flutter project, Firebase setup | Buy parts, fingerprint spike, kiosk wiring plan | Jira board, test plan outline, PRD sign-off |
| Sprint 1 | Migrations, auth, CRUD APIs, roster import | Login, inventory, rooms, people screens | Login, approvals screen with mock data | Kiosk firmware: card, tag, fingerprint, camera | Test cases for F9 and kiosk inputs |
| Sprint 2 | Kiosk session API, approvals, loans, ledger, push | Loans list and detail, kiosk confirmation view | Live approvals with room and class length pickers | LCD and buttons, full checkout firmware; start room station build | End-to-end checkout and return tests |
| Sprint 3 | Transit and overdue sweeps, warnings, penalties, SignalR | Live dashboard, room cards, anomalies, resolution screen | Alerts, My Loans, freeze banner | Room stations: firmware, enclosures, mounting | Penalty ladder and timer tests |
| Sprint 4 | Events, audits, reports, heartbeats, deployment | Events, audits and reports screens, station health | Offline QR audit and sync | Heartbeats, final enclosures, spare unit | Integration, fallback and UAT runs; manuscript updates |

### **11.3 Scrum on the Jira KAN board**

* **Epics:** one per feature area, F1 to F9.  
* **Stories:** one per user story (US-01 to US-17), linked to its epic; acceptance criteria copied from section 5\.  
* **Tasks / sub-tasks:** one per functional requirement (FR-x.y) or per member's piece of a story.  
* **Columns:** To Do, In Progress, In Review, Done.  
* **Sprints:** Sprint 1 to 4, each Monday to Saturday; unfinished items move to the next sprint at the weekly meeting.  
* **Weekly meeting (end of each sprint):** each member reports done / next / blocked from the board, the sprint demo runs on real hardware, and the next sprint's items are pulled in.  
* **Definition of Done:** code merged, the story's acceptance criteria pass on the deployed system, and QA has logged the test result.

[image1]: <data:image/png;base64,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>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAkAAAAFlCAIAAACMccB5AABqfElEQVR4Xux9d3QcRbb+7//hAMfwCLuPvOwj7MICb5cFdln28dj3eOwSJEfJOWIb55xzxhkHnBM2ThjnnGRJlmwr2bJl2ZIlyxrnIGcc+/dNX81VqXo0bkkzUs/ofueeObdu36rurltVX1X3TM3/MwQCgUAgCEH8P90gEAgEAkEoQAhMIBAIBCEJITCBQCAQhCSEwAQCgUAQkhACEwgEAkFIQghMIBAIBCEJITCBQCAQhCSEwAQCgUAQkhACEwgEAkFIQghMIBAIBCEJITCBQCAQhCSEwAQCgUAQkhACEwgEAkFIQghMIBAIBCEJITCBQCAQhCSEwAQCgUAQkgglAnO5XHFxcbq1ZLhM6NZA4PXXX3/77bcN8xRPP/20frjcQPm6KUBIS0vDNSclJekHSkaZ67AM5yoJKOeRRx7RrYax04RuteCMCd36IDz77LPWex8zZozVyPBzqCIRHR1dnispT16BoCJRdgIjemD86U9/0j0CDVdFEdhf//rXLl266FYFKPaJJ54gJRgEZuey7d9d9+7d33vvPdLLQCo2z2JFGc5VElwlEBhVgkpOZFHBxqJs9hBaBKY22uARGNqSn6MCQQWjvASmWrTpMPQLFy5AOXToUIMGDXr06KEewufKlSuzsrKsua5fv85JoGXLlt26dTOKE9j69etr1aqF7JRErvz8fNJv3bpFBeJz165dbKxevfrUqVMpSUCxDRs25EIIyIXVVd26daH88ssvZBwyZMjo0aPZx+WLwOB/6tQp0nHNffv2ZX/G2bNncRnz589nC13qgAEDWrduzUaq2N27d6enp6ueqEnST58+TfWvVl3//v1RJ1u3bmULkJiYiMp/88034YmBnkkF965GxCghu+G9mClTptSoUUO1L1y4MDIykqvIMCu5ffv2XMkqgR08eFC9VJxo4MCBnKRDCxYsgJ2NhskWGIuNEghs3rx5r776Kg79/ve/ZyOSGMpJRwjo4qmu2IeB88bHx7POV0gKEdiBAwdwVUuWLKFDJ0+eVBsV7hexpqThrau5c+cOGzaMjQxEv3nz5hx9/2dHU8fR/fv34+xLly6lQ8DatWsRiJ9//pkthqXRMoEh9Aic6umzzRMaN248ePBgoziBoeU3adKEkyiQWh1PGsjBZ4ECQbARSALr3bu3aiH9zp075Am88cYbfOiVV17BJ/rnRx99xLlu376tlfnaa69xdpeXwF5++WW20Kjq8jIKgP7p8g5bjz/+OJTNmzezPx3SCrl//z4ZKRcDpHjv3j3Vwj4agWF4VY9q/gSwFNsfe+wxqzNoho34XLduHSnApEmToDO1Y6znXGT57LPP2MJcDqDO2b5o0SIilV/96ldstGbXnrbB8tvf/lbzf+ihh9iCMd3wVclMYBi4oVSrVg3G3NxczY1O8eSTT2pG+FPy4YcfdvkiMBhzcnL+8Ic/cBYy2icwtoOfWAcBkEIExrh8+TKMM2fOpEbF2Qlssd4IwRp99inp7C+88AJnobNjesGWvXv3cuFsdJnRJwJjcGMrqc0bltomIztbLWhLSP7973/XHASCikR5CUxrvlAuXrwIpWbNmuAzsty8eZOPduzYkZSJEycWFmQmSUHn4TkpMHbsWD5kmG5EYGw8d+4c9GXLls2YMYNPDYVPjbGGGAisRlloelu/fn2tENIJJT1ChButq1zFCcxlgnxw/dCPHTumZgQwkYcdwx8l2V89tdUIJSEhgZQvv/ySPcnCblj0sI5lgVqm4esR4ooVKyhJnmp2NqrJw4cPs84TBbaQv6t4JeOymcDwycsU6P/6179YR+xIOX/+PBs3btxICu4FCkVQIzCscvg6XcpwTNfDeP/999nIeRlYzcBO5bdo0YJ8/vGPf5CiPkLE6uTjjz82FAJ78cUXtfs1zBOhOUHJyMhweW+E4Coe/ddff70MZwfNMD1rKOkRInUNw2+br169OifpevgQweVt+SU9Qnzrrbd8PnIQCIKK8hKYZmzSpAkNT3yI3Bj09QQt43PPPTdv3jyrPTIyUrW4FAJT0bx5czLi1LNnz+YsLpPAMFF1FX/UBqjTZIJ6VCOwRx99lN3I7lIITJ2xEjDhZX82jhs3zlV8nAWlkcI+rKsKVj+kYGRhT7KwG5ahPsshWAmM30uRJ2VXwXnZh3VK/vGPf9T8XZZKpnOhNl566SU2qrlcSuxUh/Xr11uNGoEVL8ZFTxrJ/vbbb+NKYmNjNWdOqoB92rRp+CwoKCAffNatW9coTiEdOnTAasNQCMxluV8ykkLPeOlG+JDGsqSU6uyYSVBeAOtaOkooicCWLl1Kup82jztSk6xbW75GYD179tQcBIKKRIAJDF3UZT6D4kNWH6sxNTUVw9PXX3+t2Tt16qRaXJYVmAp6HfLQQw/RoyrDdEPPpKEB/KE6f/jhhz4LIahjAfVhXttZCYwex2lf5UA9DBkyxKWsPtesWYNkcnIyJaHfuXOHFM7FOitRUVHQc3NzcRnsRnCZIL1Hjx4+yyE8kMC07BpcCnfySfEZExOjWbRK3r9/v8t80oVPLJjI6PKSlgr17C4bBHbt2jU6rwr2tK5RVAcNsGP1QEc///xzohN6BuuTQlQC0+6XjKT4JDA1+uRZ2rMT8vLy3nnnHT5KeCCB+Wnz7777rnqI9Bs3brgsLV8lMNUBvU8ITFDxKC+BqVDt/EXwZcuWIVm9evVu3bpByczMJB8uh0C51A6v2imvq/gKrFGjRqSgI6nO6jyXxpr3338fOmaLWOq5lOt88cUXhw0bBgUdmIwEOt1nn33WtWtXEJXL7L1UOPOW9g6MjkLJysqCgmI19jW881xiCz6k+pRk1MohfPDBB7C//PLLxA0uc4jHSOcy71T1XLlyJYwff/zxP//5T58ERgpm6IMHD37qqaf4HQ8fAmrWrEmv0zA0k/Fvf/vbp59+Sk9QJ0+eTJWMgZUqOT4+ns+1ZcsWKLAjY8eOHV1m7LBYd3ljx5dBOhOYy/tsDadWCYwOcZIsderUIcUPgX3yySdaxv79+7vM6zG80y928EkhTGD0sgr3269fP5d5v4ZyI1YCo+gjBHQKmr6U9uxvvvnm888/j9b1u9/9jpbmDLXR+iQww7y8kto8LAh969at+RquXr3qMls+zugyGzzmgtSWXOaNqA6YxpGDWqZAEGwEnsBoxMeigT3R68hBfZXCR9liNRLo0PLly11eArt79y6tezDm0hcdCXRqNSOPxfXq1aNyMJiSBYWQBYVwFgZ9tQQDNJZQ9OzlwIEDGI+ofJeFwKgz09qCFlsA1pTFSy2kUiwT+fkPFajpqlGbHato2rQpDg0aNIiSdFKfX+vncbMkAiPdZV4bW9hOdwfwl83o7f3DDz+MQ8hCs2+tktVz0WzjypUr0GnEBzp37synIIV0GvdRMrEjat5KYPScTbVQIa5SEhjxkBoOrIRI90kh6pc4rI2K/a0EZviKfmnPTj4ESqrgRlsSgflp8xxiellLRmr56L/U8un13rfffssdrVevXuRgmBdGDgJBhaHsBBZYuJT3/AIVNKzoVkGZ4PMbCgKBIEThCAK7ePGiDCs+QV8E177xLCgzrF+7EAgEoQtHEFhKSor6i10BQ/19q0AgEAhUOILABAKBQCAoLYTABAKBQBCSEAITCAQCQUhCCEwgEAgEIQkhMIFAIBCEJITABAKBQBCSEAITCAQCQUhCCEwgEAgEIQkhMIFAIBCEJITABAKBQBCSEAITCAQCQUhCCEwgEAgEIQkhMIFAIBCEJITABAKBQBCSEAITCAQCQUhCCEwgEAgEIQkhMIFAIBCEJITABAKBQBCSEAITCAQCQUgiiAS2Py1hV8x6kYDLhQtn9bq2gdu3b1uLEim/xMdt1uvaHuLjNllLEym3bLh7945e1zZw7twpS1EiAZC8vGy9rgOHYBHY/rTE3fGb7969qx8QlA8Xzp9Bm0hM3K4f8IvsrEPIdezYYf2AoNw4mL4vLnajbn0QEI5DB5N1q6DcyDp6EHWbk5OpH/CLhN1bkevixXP6AUG5sW9vzNEj6bo1QAgKgaUkx5V5WiqwA7SJmzdv6NaSgc6pmwSBQ/qBvaWqYZO9knSrIGC4X6pwXL9+LTkpVrcKAoe42E1pqbt1ayAQeALbk7jj8OFU3SoINNBFf/nlpm71hVJ1ZkHZcOPGNZv1bAauFJMPQdlgMxz2AycoDw6mJwVjlhB4ApPWUDE4efI45gq61YIzp/MTdm/VrYIgwGbLt+kmKCfi4zadP3dat1qA3nHmjFu3CoKAYLT8wBNY7K4NukkQHNhpEOifly6d162CIOBYdoZu8oXjx4/qJkEQcP786b17HjzDs9OJBAFBMKo68AQWpGedAivsNAg7PoKAwOZE4fLli7pJEATcu3fPTuO34yMICJKT43RTuSEEFsKw0/fs+AgCAiEwR0EIzGkQAhMUg52+Z8dHEBAIgTkKQmBOgxCYoBjs9D07PoKAQAjMURACcxqEwATFYKfv2fERBARCYI6CEJjTIARWLsTHx+/cuVO1ILl3717VUhK0jA6Bnb5nx8c5uHz5ss2IOBAVT2Boljk5ObrVL2JjY2NiYnRrcTiztZcWFU9g165dS03VfwJLlXn69Onjx49rh6oawoTAXAoefvhh/XBpgBJ0U8l44YUXNH8k//SnP6mWklCqE1UY7PQ9/z7btm1Tw/Hcc8/pHgECCk9K8r33RFxcHFdvYmKizYg4EOUnsP79+3NVqM31zp07b731VpGfF3AYNGiQbvWLp59++pFHHtGtxeG/tWttJi8vb8uWLZylYcOGrH/55ZeskzPpFYOAENinn36Ky27RogVb/NxIeno6/DUjOc+aNQvB1Q5VNYQDgf3lL39Rww990qRJhrnV7Ndff92zZ0+y5+bmLl26lPRhw4bhExPzW7dubdy4sU6dOmxHdnxu376dS+AZEOzw3717Nz7JwiPCihUrcPTq1av4nDt3Lh0dNWoUlwwcOnSoWbNmo0ePpiRfM7Js2OCUH7r573sE/z4YjP7617+Sjhrg25w9e3ZkZGSRn6V+4ICpZe3ataEfOXIkKioK40WRt1mBGMv27NljeCPVrl27Y8eOIXn37t1atWr9/PPP0DH8tW7dmuJoeDZUPadF5NSpU5Qkh7Zt23777bdkAdQYVTrKT2AFBQWoijNnzhhmk6tWrRotsMaPH0/dAY0cceFG7jIJrEuXLr179y4qxcTChQurV6/Oyfv376Ouxo0bxwSG+gQvduvWLT8/H8nBgwejs5AzVTUuA5HFoFyzZk0ux/ASGOnTpk376KOPDKWDuEzMnz+f9A4dOkDZtGmTy5wecTQrAIEisCeeeILvDlGgG6SkNmoRgWGxpdY8VaZKYH379m3atOmNG8V2Y7l06RJikZCQQEnkQuWjKPQasixfvhydDgo6BZZ63nyhhHAgMMSeRygGehfsiEpWVhY1DgyO0dHRdJQs33//PRSwzo4dO7gBsfL+++9TCXXr1iWjy+z/P/zwAzkYXgJDm6NP8vnkk09IofEUCo0OVMhPP/1EozaXWc4lY2Dhv+8R/PtgMMKI9k8TLhOGeZtDhw4lZcqUKaRY6wcrKooXDl25coXyEoiTKKxcgbQCw6BJnv/3f/9HiroCO3z4MEXkySefpDMianxG9HAor7zyyowZM8himDFST12JKD+BGeZNff7556AlKOCzxx57jIyGt5FDURs5KQMHDlQrAXq9evVIcbs920xAiY2NpYgQgUGpUaMGKW+//TYp1DepKAzHUEBvR48eVQsnAhtmAsrkyZMpC/oUHcKUiPw5F5QxY8aolgpAQAgMrRQViMsePny4YV4/tW3D16hFNYapGzVyavB0iAkMyZSUFCiPPvoojUIApg4uM9zPPvssV93jjz+OopYtW0ZFNWjQAFQ6YcIERAQWTAEpbwghTAjsxx9/1IzoCTw9gQOmaT4JrF+/fqpFU1577TUeiC9evIhPTHPoKOHFF190mcDUhnMxgbHlj3/8Iyu8CkTy3XffZTeHwH/fI/j3UR8H/eY3v6FVFN8mr1l91g9bNMUwp/NIIqa0mKCj6iNEdD+uT58ExpYDBw5oZ8QCmub1dDEco0pHQAjs1Vdf9QTD23rprvlTbeRkAZlRRq4fwqpVq+gJ3qJFizCe8sTLpRAY7KTQexqXdx1MRWE4pliwhaA9QiRjixYtsBp7xQQHlI+qSoUtwgJCYFhRgTBoEZacnKzel3XUQo2hy7Dlww8/ZGciMCI2iuBbb71FEzLCL7/80qtXL9Qen0IrCgTG1ciTv9BCmBDYO++8w0n0HIxQWIPTTJ8cMIr5JDB+3M/BU5XIyEiaFQI0SdFeD9BwDFy+fJlzWQns5ZdfhjJ16lTMgFxKK8SMid0cAv99j+Dfhx8hYl3Lr0b4NpljrPWjWjSFgAo0K7uoAonAEFzoiDh3SP8EBgrUzsgEhj5PMdJOXVkICIFhcUl3RI+YXOYCl27QVbyRk6VTp06UUa0El8lStCwDgWFq/6tf/Uo9RMoDCYzf6KiFq48QGRkZGZhMwL51q2fjTZe5MqPQY2R3KcAYreUNEgJIYNu3b3eZj0DpxunTOmqhxtBl2EIDHTkTgWHkcXkXrwBCQ86LFy+G/Ysvvvj73//Op9CKUgmsSZMmrIcQwoHAaN0NLkH4Pc3ZGwaKa/PmzVXLpk2b4EZPUUoiMBiRkaK7Zs2a2rVrcwvwSWB0iOY+LoXA/va3v82bNw/KyZMnyZKVlTVgwIDXX3+dkvj817/+xad2Avz3PYJ/H/UdGG7t97//PSlYB4AnoGze7PlbHJ/1w7k0Bfjss8+QzMnJwSdX4AcffDB9+nRMM13mYxaXCcOkKJcZfRiZwHAlJZ1RXYFRjNRTVyICQmCGeV8PPfQQ6SAbJP/rv/4LOjVyevVIt+wy12RYbIHj1UqA3rVrV3rY/tVXX5EFCtjxjTfeCAaBGaYP23HBLvOBP9nZh56VVcwiLIAEZnjvjl4+8R1RjfGohRpDOBo3bjxx4kSX+fSVnfkRIip/5MiRqPBf//rXCBCVQ7yFCRmdZfny5aSgKPQaKoqij/C1a9fO5R3BQgvhQGCGl8MIbOzSpYtmocixxSeBoZeyDzEi2O7mzZvkUxKBIfZQ0O1dXgLDuImMSPJ3uNV3QoZyxmeeeYbeWjsB/vsewb+PSmBDhgzBbZ49exbjzvPPP+8yJ+90yFo/1pphhUAV+P7771Nyw4YNL7744nvvvWd4v8iDZQElgaFDh8ICZmICA+iM/F0SLp8JjAgSSEtLo0OViwAS2Pjx40kfO3asy5zJUdLayBEsqoQDBw5wCePGjXOZ72uxHqJ6o4e6Tz755KhRo4JHYPxiZs+ePeRz7tw5zdlVUYuwwBLY3Llz+UZY0UYt1Nj69evr16/vMklIdVa/xIG4wPjnP/+ZkgQwn8t8bYxhirgKp1aLIuO0adPwGRUVpeYNFYQJgQkCBf99j2DHRxAQBIrABAFBQAisskAEplrUR4ghCiEwQTHY6Xt2fAQBgRCYoyAE5jQIgQmKwU7fs+MjCAiEwByFkCawsIQQmKAY7PQ9Oz6CgEAIzFEQAnMahMAExWCn79nxEQQEQmCOghCY0yAEJigGO33Pjo8gIBACcxSEwJwGITBBMdjpe3Z8BAGBEJijIATmNAiBCYrBTt+z4yMICITAHAXnE1jvXj10U1gjHAhs4Q8LWNLSPJu0xsTsHDig3927d1WHn3/+iZL3798fNLD/sexsSh4/njt0yKDz589RkpGRcYgyJu3bSxbofDQ7Oysz87Dh2SDuZ3Kj5L59e9XCU1NTpn0/hX4iasXEieMzMzM5ef78+cGDBhw+nKG4GOnphT8mPZiePnjwwBU/Ff6YERgyeGDC7nhOBgR2+p5/n4sXL2jhoArfssWzAYfhDcfSJYu5Whb/uGjWLM9euoRxY0cvWaxvbmlwoBcuKCgoMDx7hu2gOicg6MXcvMFC4fu8EaRYr161kpLOR0AIjCuE9h8JOGJ3xfApuNrtg3prYmLhpuklIeKrz3VThSMgBIZ2q9YVBgGty5cHai3RKWJjdynHww3hQGCIGQZKktOnT/Xv32fqlEm3bt3iWGLAwiEEskF9z16IZO/apdPlgoKDB9NbtWxBxuvXi/2hwMqfV0wYPw4Z58+fS1nwOXfObDq6ZfOm1atXkVHJZMyaOd0wCzfMoXPY0MFXr14pqe/BXrNGBOm44OqRX968eaN1qxbr1q0hY93oon8bafl182vXrqH1u92en/FTRozm7BwQ+O97BP8+oHY1HIZ5m7ivRYt+aNqkISVxaM+exFo1I7OyjtJdg+Ti42IN7y1j0mCtNMqYkpLcrGkjw+Rv1Wf4sCFFrl5Q4ZhDUOEUa0RWi7VjERACi4z4whOO1FQ0LTRm/bBfcPv0A0wLUD6aIgVdP/wgUG/F5Ew/UBwlUSOmO7opaAgIgaHdcgcxSiYwbtsY0Kgf2cEQpRqpvyyYPw+9YPLk7xQvH2jerLFuCgWECYGpyag6NdOK/4cp1i6kqJ5t2rRS/wIH3WPH9m2cNMxhDgxEOmUEhSxftrRdu28MhcDQOHr17J6Xl6dk9RSuJuGA1ZVqIWBsHTVy+N69nj+4OnToII3LDNxI7149LpurDfWfftq3a4PPhg08W4Zj1IiPD2QI/fc9gn8fEJhm0QLESQym6F2kY2jAZKLIyZJLtaQke/bwpXVzndqe/+8wvASGAlFpqBZvJg/Gjx+rFa7F2rEICIGhiZKClWjXLh1pRjVt2lSuz759emGUJDcsp2BHG6MkdLRenrcROnVsryYJyEgKFzugf19KojsgWGTXzg7q0norH01NTRk9ehQmH00aF8576BMRnz7te0ri2ho2rIdPtYTgIVAEpiaJwJilJk2amJFxaOPGDVTzhjmlQ9TgYJi3j8bMNYx2Xq9unbVri6aw/FeFRvEehLHLMCfWI0YMg52eTs2YMQ2TyEnfTcCJMFOpsGoMIMKEwFjI0qJ5U+i0GFIdeBSDTg2CoQabAALjjOvXrTU8jaAZPqk7EYFdv3599qyZSKJTEYddvHhBKxzUhUbGSca3o0YY5uM1PjXWKNCbNfVMhY4dy8YIgrltjepfoWQrga1Zs4quDdfAh8oP/32P4N8HBMb1RhbcC3TcDj2n5aM8u8fKQF1rAksW/4jepVoMS6AxEJw7dw5VPWK455/GiMB+XLTQMB//8tlReI/uXYtKMYyBA/qpSScjIASm1RtaFNlRw7t3x/OQR0e53mh9YF2BcVFgEdXOBLZ2zWpSuECavW3bugWEpJ3d8PZWTNcMz3/M7qHx/c6dO5mZh+GPTqGVhi4DZcL4cRs3eNphKK7A1HD4JDBDCQQf6tK5Ixo8lITd8TOmeypfe+OlLX+5BMMcWwyvw5Ytmxcv9kzNefJnyApMQSUQmG4ygY5Bz395BaYCqx/MPkjHGFf8oAfqCoxABGaYHMYrMMLly5fV+QsK53+Wsw4BBG7E2vXHxOyMjPiiRfMm9IoI5bRq2cJKYNz4Srr9ssF/3yP497GuwAj8KLWkC2b7sKGD+/crNr0gaBmJwAxzRD569Ij2CLFtm9ZqkvMi1kuXLFYPORkBITBaS2GKcPbsWaN4w/t+6hTVQrqa12fr9b8CA9zufFARdR+1wPr1oqxnJxzLzkZvnTp1ckJCUWcHgXFz0i4vMzOTIh6KBKYm7ROYWnXUvDFGFRVkKVmt+WHDBhue/X9nUHZ6kqz6C4ExKpnAkMzJ8fzNfLOmjejNh0pgecePf9O6JZQ9iYkYy7Am0LKfPVv4f4l+CAydDblAYKNGDqfvDvTp3TMlOQmFE9OgcMOc76j9f/S3I7lwNMqMQ55mapiLsNzc3LVr1/Tu7ZlPUS5MV8eO+dYw++fGjRsMc8aKT6y3Duzfb3jv+tKlS1AKCgow6FNp5YT/vkfw76MRGKbSdKmsaBXO0wjQNj779e3N3G+Yz4hY1zIygRnmZIWGM/K5e/cuFAw3VPipUyepcK0E5z8zCSCBGebtY72FRrt82VLDbJCYhxGLoK6ocho2rEffG6Jk48YNrEt8TBc0i1GcwCKUaRkUrJYMc0oBctLOjpZPvRWrNPRWNBK62n379vbt28sngW3d6vk2ECKLxg+lW9fO5FABCB6BLV++dJT5SAb3RTv6cwWiopLNZ+br1q2hhwebNm0k2tYITGvelET4MOHu1Mkz5yBLg/rR8+bNMYpfCXfD0EKYEBgLuh/4AKsT6PzwQVuB0fNlelKn5qV5Jb/N8kNgwMgRw2gFhrUC8hLHGOZExmfhs2ZOR3YuPKJ4U6tdqzo+wViwN25Un4xYKCDJr3NmzpjOJQOgsQjzKRw6FcZx3DjZywn/fY/g30d9hEhXRd/IgNCfOWn3jqk0HaUVJ+clN9VZy6gSmOF9hAjyg1t0VC16MkaFoz1ohVOstQIdiMASGOZP9ARvzOhRuPfx48aQHXqH9m3QouiFa/duXZBl584dhjm7AvfbqSiVwBo2qMsvZpAXCwh80lMvw3J26q08gKakJCPZvZuHlnwSWFLSPnzyg0oMzRHelzrBRvAIDErPHt1wIyAnsoOuIrxLJYwPdPv0hbJBA/uTj0ZgNEtjRJhNHfMGmiIAmD1QXVEzUK9EfbUWQggHAgsV0IoqGEC/Qq/WrWWC/75HsOMTKHTt0lE3BQ7z5nrmoU5GQAis4qGOpIEdFgNbWmkREAILEtLSUrW3klUBQmCCYrDT9+z4CAKCECUw9S1jYCknsKWVFk4msKoJITBBMdjpe3Z8BAFBiBJYuEIIzGkQAhMUg52+Z8dHEBAIgTkKQmBOgxCYoBjs9D07PoKAQAjMURACcxrCgcDUfdjol3oB2QsROHny5LejRmz2fi+IsGZN0c+/aN8/5aDnXNZ9X/j7kIxZM6cPGzqYf0NKV8hfQCKsXbNa/XL8ihXLcZ28bcHly5cH9O+rbXS2YME89RdjZYCdvuffB3WiJnlLSRLDe7Pbt2/FcKB6+kR0VC3dVJVQkQRGX+czzJ+aQKFfI9kHfWvRPyZNmqibFFTu+y07CAiBqT8fDktQlH9avqwCvlQSDgQWEZy9EHv26Na6VQu3O3/58qVq14LOG4/SV8bjzF+b8VHt9/CG8j1mAnwSEnZfu3YNCu0j1bFDO+Ra8dNyWE6c8HzVvm50HfXnOLiMHTu24wrpN9f0qx3PDnKDBkyc4PmRDZdMX1UvM/z3PYJ/H+13YLylJInhraLFixfVrxfVob3nR9l+IASmm3zBPoGVREuYzw30fjm7bERSfgLT5oIOREAIzOdG1Rq0fYLswOdPzoOBB/5ynKJ86NBB3kQ7eAgTAlOTgdoL0Wc7+37qlP3707gcdPuJE8dzcu6c2aNGDvdPYNqGh4S+fXqxrt0OJdW9D0BRWMDxFojsH2FuOudAAtN+TqfeILV1cHbjRvX79O5p3T4KBIYZK4526NDWKH6zhvlLZEjzZo0ho78dSUk6NGLEsPHjx7Zt03ra91MM7x4Q/OPxUEH5CezOnTu1akbOmT0TTQjjL6oRVRRjkk27tq2/HTUiwvzFN+wNG9aDnSpQ/Ym3toHepO8mDB0yCDMn+uVGSnJSt66dUTj/zIuzdO7UgbKgc4EdESP0DsP8dRcaKnLhjC2/bobLW79+neEdgps0boizjzZ/K4bk1q2bcZ2II20OULkICIHRz0lxg8OHDZky+Tv1NidP/g63uXHjBsxfKQSYuaILUONn5iB6w1iEWkV1NWxQFzpHjba86d27Bw072n6Ss2bNsC4BkR2Vj4uhHVa1XoZJM6JJPzntpWw+iXJ6dO+Ky6atwrQob9u2denSxRcuXEDnRfn0sz/cTo3qX82eNZN+iEaNE/Xgc28XOwgTAmMhS5n3QsRIigDTX3tcuuhjUCA3jIwIj2EO1lgA8bwSRx9IYHyRKvwQGI3pDyQwtCrYnUlgWnTUG6RdRdBz6HasVafl8lmIqv+0fBntlVdSxtBC+QksJmYnPcmhurWuwFo0b0J2Hh+1uqKMvIEeN0Xa0oyd6afHBI4jZWEf+sE+hlT6HxyyY1ikfYyYwMiZTvRN65b0UNoJk4/AEhg9yKG+rN0mj04Y8XknFI3AuFaptnkFFhnxBe3lgWFqx47tvJ/kpUuXqEr99DJ+RqLa6RPjIdjIUC6D/0BA62IUZSKwvLw8dWMR+icNw7s7udY4y4AwITDdZKJseyFeM2GYO2aykYBFcURxsiQCM8xNSNEnMQF5IIFZpz9GCQRG+yGR7p/AFsyf16VzR8yAGtSPnjNnFm2xUzb473sE/z5WAvOzAuO/5sIsLEJ5Nsvg6ho4oF9uTo7WtQyz3/JbN3R1sl8uKNAipZ40hFB+AgOmTp2M26cnCiqBqfXjh8BK2kCP/nKBnbdt3eLNoWdhH9pTivfXYLtPAuverQspvXv1iPA+Wq9cBJbAqBJQRbSJiXqbKoFxxpIIjMAExnZwIYYjdTcT9EQchYWSDK0oTpKCBRZWZhgtaWrIl8G7VpKbFmUisCtXPMtBEkO5Hf6Cgto4y4AwJLCI8u2FyIAd8xfDE79CH9UTjWD16lVMYBwhJjCV/7R3YPxnK56NZZd6fvLJBIZCiJn69e0N8ebw/K0lTcRoWQn2pe3bcYO0gyLBmSswnwSGFtyzZzd6xRVVpybdHR1Sv/NSv17U1atX6J0fOaieGzes556Qm5tbN7o2Z+RgWWMXQig/gWFSpb5Mzc8vHEH46z9k90NglLRuoEfNmP9pAZEqzODNgmkEZeECyadUBKbFsXIRPALTbnP0tyMpqRIYU9Ty5Z7NJLUsvGvlsKGDaVQB5Vy/fo1P9NPyZfRfDTQppEK4BHoMSEXxi2dK0iem7yNHDDOUzSd5WKMhSIsyEZh2kRqBaY2zDAgTAmMp/16IKtCMIsxd2rhlqEdxiAkMoaV5BxOY+j+T6lkMT6UnkU7/0sIOYFz1vy1YaLmNC45QnovSq7gRZpNiOITA+Mrz8vLUR4gR3v4Aafl1c/Udb6uWLWrXqk5/GUzP0An8noC2PaRVaYT52sYoXkvaWWhTxKg6tWijOTKGHMpPYEDnTh1w+/ximKsInxhrsH7FAOqHwEraQI/nYRFmb6J9FNUsY7x/nkJR69G9Ky01SkVgaPyYl9SvF41JG9krEcEjMLrNCPOvX8ktwly/qgS2YcM6jh37YKyjvZVp10r6qzx6Z0lzaHUFBsKI8G4jqX75y/C+duFtmulE9CwnNTUFOvMWbz5Ju1by9WhRJgI7lp2NqwLV4ZKw2LKuwNA4PX+4WvxbC/YRDgQmCCD89z2CHZ/yQP1yTRVHQAhMECgEhMAcAu1HOyEKITBBMdjpe3Z8BAGBEJijEE4EFh4QAhMUg52+Z8dHEBAIgTkKQmBOQ2gQ2J7E7bpJEBzY6XvwufXLTd0qCAJOnzqhm3zh7FnPu0NBsHHjxjWbHUQ3CYKD3fFF330NFAJPYNIgKgaYyNup6mPHDqcfCPpv7AWG518iC/8o1T/i4zx/UiwINtJSdx8/flS3WoBOdO3aFd0qCALsjFelReAJDN345MnjulUQaKA1nDt7Srf6QjDajUCDzQdWRmE4PL/REQQVNsNx+vQJm56C8uDEiWNxsZt0a7kReAK7c+c2GgT9jE4QPNjvdSnJcbdu/aJbBQEFwnE8t/Brzf6RnZ1hP3aCsuHmzeuptl/GSziCjfv3PdO7e/cKv44fQASewAi4XHnWHyQcTN9X2i4H/4TdW/j3HIIA4pdfbqB6r1wuxY4qBQUXkEVmFcHA3bt3dsdvLkMHOXQoWbcKAgFq7bo1QAgWgRlmm4DEx206nnu0JMnOOmQ1iviUnJzMxIRtJhV5tnYsLQ4dTKaIHDlywFq4SBlk756dVKW0g1ypcPu250EFJGlfjLVkkTLIkcz9VKWHM8ryS9vd8VuQF10MHc1aOEnm4f1Wo0hJQuNV8NjLCCqBGebjROtdqbLL8+BFN4r4Eb2KSwlrgarExmxISY6z2kVKksulWXhZUVBw0VqmKgnxW61GET+iV3EpYS1QFRmvSiXnz5/R6zfQCC6B+UemOWM6eNCzn4qg0nH6dH6wp0uCUoHCcfNm4QbngspFwu6t0kGchsokMGoN0iAcAiUc8gWcyse1a1ekgzgKEg4HotIIjJZfJLIIcwI4HGV7xyYILDgcu2QR5gDQzyRITp8u2rRXULmoHAJDh1T75y6Z1FQ2+PsIJO78XN1DUIHAlE46iKMg4XAmKofAGNIUHIV9e2POyOzSSTh6xPMPTAKHQMYrp0EITFAEITCnQQjMUZDxymkQAhMUQQjMaRACcxRkvHIahMAERRACcxqEwBwFGa+cBiEwQRGEwJwGITBHQcYrp0EITFAEITCnQQjMUZDxymkQAhMUQQjMaRACcxRkvHIahMAERRACcxqEwBwFGa+cBiEwQRGEwJwGITBHQcYrp0EITFAEITCnQQjMUZDxymkQAhMUQQjMaRACcxRkvHIahMAERRACcxqEwBwFGa+cBiEwQRGEwJwGITBHQcYrp0EITFAEITCnQQjMUZDxymkQAhMUQQjMaRACcxRkvHIahMAqFAf27zc8//aUrh9wBkKOwNLSUnVTKZF3/PiNGzd0q2NQuQSWnn7g7t27urUKoyLHq7Nnz7rdpeuMBQUF586d063lwK1bt3JzcnSrk+BEAouOqsX66tWr8Bnx1ed+RHVYv34d52Vjo4b1yNKta2eydOjQlixnzpwhS7u2rdUsVCxj3769X7doCuPaNatVe2lRq2akYZ5FP+AMlERgXCeHDh3ULCdPniRL40b1yYJeNGrk8JJqMrAoc+G9enYnZfToUdnZWcUP+gNnrBj4JDC1bvfsSdQsSM6bN4f01atW5uXl2Y8F6Irc6kbXQbJO7RpXr17VnezB/klDCD7HK7QfvtPFixfBsvLnFWyhOVbNGhGUvHfvnloz6ClqUWqN/bR82fRp36tHH4jt27cuW7rEKF75ICHdzzbAoEMGD9StTkJoEBiB4uozufhHT7vRjKxPmfzdtm1bkbx//752VCsTiN0VM3XqZM3IM33Vf+DA/kgOVgKMJCat+Ny2dQtZRowYhmT7dm0oGaIEdjC9cMlorTQQwOTJ30Hp0rkjGwnW22zerDGMGzdugI51T1SdWqC9O3fuIIlqxKGePbuR5/BhQ5CEw+3bt5GcOmVShEKfDBjnzJmFT77CZk09p/h+6hRKdu7UAaPwlStXyHnTpo0RxQdWIjDoHdoXxmjLls1aCUiOGjWCSoCgQDpUASiJwDRdtViTQJs2rS4XFGhGhGDWzOmqBbx182bRerTl181IafNNS7r3rl06YlBDr4SOqqajM2ZMQ3LXrhjOaBS/hjVrinpxSMPneKVOgOiuQWBFhw1j1aqf58yeqVoMXzGCm5rEkLV06WLDbKJU+ZTl0qVLoMMa1b8it8zMwxHe9skEVj3ySzqKzlW/XjTpBAofxq7ataqDTQ3lSlSlRfOm5AwCa9WyBcfaaXAogS38YQHJgP592e6nl04YPw4cA1GNEeb0JyUlGQoCGVWnJh8CaFkGpsHR3bvj2e6TwBhq+Zjn4nP+/Lnq0Q0bPEtAtDC0MygLFy7A59GjR65fv26ELIFhIk812aB+tLUm6XbwiWFOrUnrbd68edMwK4eOgpwuX75MblRRY8d8S57kc+rUyfr1oq5evdK1SyfK4i2pELCcPXuGD+Xm5Jw/fx7K7Fme8QLtZ//+NFww9Xb4rF+3ljOSQqODYU6VwMEogbouSqDVNkrAZ4vmTbSMFYOSCIxae6dO7YljYKH+Qguytm1aY3ii4Y9gk8COH8+N8M4wDIXAEsyw4nSGOahRdHbs2I55BoJIq1KtZtSLpDlKGMDneAUCoztF5VPNgMB4BCMf1AY4zDqB1qC6EYGhC3Tq6Kl29u/dq4dhMhM93CM72ue1a9eYwCIjvqBLwoCzedPGwtJNIHwNG9QFdXHX45JJoZkcumqP7l3hTEaKdVEpjoFDCYxqHzJt2lS2W3sI671791CbC4F7NS2imzZpqB79pnVL1mkKSfORkgiM1v7kQ6DyL128qFpIiY+LnTRpYlpq0RsaupEQJbDx48dy9YJOtJrk2zl79ixqsn//PpqdUa9uHepgd+/e5ee6BPAQFmGgQEryKpz7mDpRYGh9D30bgykJRerIkUzoXIg1IwiMRmcyogQsuagEmsaihH59ezdu3EDLWDEoicAQC4yVCxbMYwv1l/z8wvChza9fv45n4lYCQwnz5s7p1rWz1msAxAgFYgbGBEbTAqyDDeWxEoKIYg2TCHkewLBeZBjA53gFAqPewTUAAuMRjN1iYnZGeJ8xGiU0JDRacjO8BJacnPTdxAmG4s8LvljvkpfaZ0pykvoIEdeDnohJJ/kwED5+gaL1C1J+Wr4MvZjmbdZYOw0OJTDWS/sIUYXVnx/oo3trwcOJZs7wzEZ9EhjmOzTxseLo0aOsc2lz58zeuGE9rboImMIYIUtg/ICOoF7/1y2aUltfsWK5dlS7zQLvADp40ADr0fPnPS+fF8wvHOxUAsOgjNml4XnAVdvrXgjtXHPmzFKP8vCtxVrVMfKqNIAStm7dzG78/gCzUfbhoxWAkgiMFZqta1dFb7CA+vWiqRFaCczwtQLjcjC779ihHRPYjOnfg9HzT5wwLIPavHlzMG6qeQklNYOQhs/xihkFk7CLFy8YlkeIaDw8SvipFm5jQELCbiKwY8ey0V9Q+bx6UwkM7bPl180pr0pgWstXwQtow9IvSGHSRVII7AHw2SCCRGBkQbektxrUIDCvh45uzBYmMDU7dJ7as7FJ44ZoZ40b1VfdIsy5j9omkOQH1uFBYIZ5C1hioiZ5BIwwvxqD5LChg9lSlMHE8GFDsCwge/t2bVq3+hodj9574RN9D0s9el+iEhimHag3LGop48QJ47hAtZ5JadWyRXx8XP16UdARa1xkndo1IswvO6jXg/N26dwRE14QGE+f6TuiEeY0GSXE7NyBJErATeGTvy5hXbIED/4JLO/4cXqcG6G0TywosdKFHddZu1Z18vRJYFZgEERRmEZEKCsw1BJV0dIlnmeS2qCWmJjQrGmjzZs2durUXn3To16knVOHBHyOVz7fgXE4Fi36gb4ag1oFr/CAxo153bo1ZIEbHMjN8K7AMA8eOWIYKp/dtBVYhDl8oX1ihm0lMPQ4TKahcHaEr3u3Lui5DepH9+nd0zC7TP9+fVAIvf4YOLA/Tg3WHDZssBDYA+CzQQQVmHVev+6ZzjNu3ryprvQZE8YXDZQlITPzsJqkRnnypFs1aj5ORkkE5hPHsrO1mtSemfiEWjnq81iscTHZ5KQVR45kkqLm8gn2BGjp9kBkZRUtow3vcpCAEug1W6XAJ4HZQW5u7gNj4ROoXi3jrl0xWJXCiMnH2rWF46AKzPysU5ywRHnGK1SgtenCkpqawkk0PM2ta5eOCxcugHHc2NHaU3eGnfbJZ2FOUl9MYoGoBh2Nh3WHo8oRWFChzvFDEaUiMEEFoMwEFkBMnTJp4IB+WARgzUpfCq2yqPjxqk7tGm2+aYnKx5I6IWG3frj0YAILDwiBCYogBOY0OIHABAwZr5wGITBBEYTAnAYhMEdBxiunQQhMUAQhMKdBCMxRkPHKaRACExRBCMxpEAJzFGS8chqEwARFEAJzGoTAHAUZr5wGITBBEYTAnAYhMEdBxiunQQhMUAQhMKdBCMxRkPHKaRACExRBCMxpEAJzFGS8chqEwARFEAJzGoTAHAUZr5wGITBBEYTAnAYhMEdBxiunQQhMUAQhMKdBCMxRkPHKaRACExRBCMxpEAJzFGS8chqEwARFEAJzGoTAHAUZr5wGITBBEYTAnAYhMEdBxiunoXIIrKDgApqCKrqHoGKhheN4brH/xxJUMPanJUgHcRQkHM5E5RCYIQ3CYbh7946Ew1FQwwE+0w8LKhaY0nE44uM264cFlYRKIzB1EQZdPyyocHA4ZPnlBKiLMP2YoDLA4cBsTz8mqCRUGoEZ3i4qs0uHgOeY+gFBJUGmd44CFl7SQZyGyiQwQ16KOgwIR1zsJt0qqCTQUwrdKqgk0GN2eT7hKASRwDouzH+t+yERERERkSorNb87pnND4BAUAluceIkufU7sBfel2yIiIiIiVVC2HLxCXLAyuUDniUAg8ASWdeYWXbH1ZkREREREqpoQI5y4cFtni3Ij8ARG15p99pb1NkREREREqppknfmFeEFni3IjKAS2M/Oa9R5ERERERKqmbE73PEvU2aLcCAqBWa9eRERERKQqSwgQ2Nkrd4TAREREREQ0ATVcv3Vf54zyIcAEdqpACExERERERBdQw6Xrd3XOKB+EwEREREREgi5CYCIiIiIiISlhRWAuBX94+x2rg1VGjpsMZ6vdpmzYkVhS9td+9wZfzOyFy9lO/vjcFLNXy/Lwww+//NtXOLkjIY1LSEg7QrkYzz3/ArktXbXJpVxD114DKKk6l2Rh+XHFera/+NJv1EMiIiIizpRwI7A3/vD28rVb+wwarg3QJUmQCGzt1njYB48cl5l3gVjhYM4ZOkT+1lz5F2+RJ1ug/9sTT+w/6q722GOci25w0PAx7EkE9uRTT1FSIzA4k8BCCowjxk4iCwld7Suvvo6r/TKylku5WhERERHHSrgR2J/f/wvrpDz73PM0lGefuoLk4ePnKfnQQw+5FQL7x6f/hAK2OHHhFxyCzosh6D8sW0O5jp2+CsvWuBRK/rxhB2W3Xsm+9GOc/OR/P+vVf0idug0pF0PNElkriow9+w3mQho3b6UVa71BENjb7/wRyZpR9dwWAlOzc8aVG3Zqlscef5yTdRs2xdVCAY1RIR9+9DF7Yn1Gxbbt1J2OaqWJiIiIVIyEG4ExPv7Hp7CkHcmnpUZU/cYwHjlxEZ/7DubAAp7AQo0ILC45w+Ud66H8uGK92xzHyYjPxT9vcHu5kCz0TO+r6rXZ8sGHH6lXwroqtaMb/P7Nt1q37/LUU0+rdlp+JR3KHTD0W867OzXTcycmxk+ZRcWqIDcQWFS9RlnuAljSs0/5fIT47888y+dyWSgHlgVLV6kWyNH8S3yKX//7M1RpbFF1KHMW/aRlFxEREQm2hBuB0QIFy6xq1aotXb0Z+nPPv8Dj+NRZC9Uh2O1dgQF5529yISrIcvzcDSj/+ac/s4WcV2/axboqPo1Yhz388MP/8cpr//bEEy+8+BKSfIiXXwRaAJFsitkLzuPz0iNE9QEgERgUkBAcyrYC69yjn+am1lWHLr0GDhtNnmRJzjhO5RNw/Vp2ERERkWBLeBIYpOnXbSD0YBDJWtH1oWyLT+UhmGTUuCmwTJ654JFHHuFCDuWe1YoticAwrGsFkqC0sZNmkE6vwTp27Q3GgvJf//0/+PzL3/7evFU79RQasJZymRfs9q7PyI1vkIUJTC2Hdc2Z7BqB4WpVz1/96te4WrWuPv7kf3EWystu9AxWREREpLIk3AhMBSzjJs8kHWsaskQ3aMIOWKjxO7C33vlPKAeyTo6fMosdxnw3nYrVCOz9v3xIDr0GDCWLq/gjRO1i+FUWO6ueVgslwXBcwn//z/+RXSUwclMJjIx8FhWqg/WtVY06da3OtaMbaBZW3CaB0SFhMhERkUqRsCKwkmTvgWzNoj6C8ylb41KsRlW2xCXHJWdY7apkn7qyYv12q71UsnZrvNUYJMHV0pqPJe1IftKhXKsnybHTVx9YkyIiIiJBkipBYCIiIiIi4SdCYCIiIiIiISlCYCIiIiIiISlCYCIiIiIiISlCYCIiIiIiISlCYCIiIiIiISnhSWB5564dyMjYl7RbJOQkOTXpaN4pa0ztS2ZufuqBNGvJIs6X1PS0I8fd1pjalyPHTyan7rOWLOJ8waCdd/66NaZ+JNwILCvv1K6Y9cfPXrYeEgkh2ZeUgDha7f4lPn5rGXKJOE0QxPiEUv+AErmSUvZY7SIhJLlnChDH7PxieyH5kbAisKN5J2X8ChtBU46P32K1lySxuzbs3RdntYuEoiTu2RUbu9FqL0ni4jYdP+P5uwmRMBAM4zYfw4QVgeG2T1z4xWoXCVGJjd20/2C61e5T4ndvsxpFQlfsBzT1QGp8nGfnbpHwkBPnb9pcioQPgeGG885ds9pFQlo8YbXxWNxmcxcJLbETViy87LiJhJbQs0SrXZOwIjCrUSTUJSll34GMB+w56Zboh6nYCWvawQMp+5OtdpFQFzvRFwITcbQcyclPSNhhtWsi0Q9LsRPW+PitR46ftNpFQl3sRF8ITMTRkpl74oFfSDtx4ReJfliKnbDGxW0RAgtLsRN9ITARR4sQWFUWO2EVAgtXsRN9ITARR4sQWFUWO2EVAgtXsRN9ITARR4sQWFUWO2EVAgtXsRN9ITARR0uQCKw8fyS9amOM1ajK9t1pDyzfjo+InbAGg8AQ4oqMTmbehS1xRV+kxKlj9x20ulW1NmMn+lWFwFzFsWSl50f+mhGWIaPGc3LyzAVfRNRUjru+6dCVC/x5ww5Y2nbqXtIp2GK9GBH7EhACU+MSs+cAWaxuNoXyHj93Qy1WLbBmVL0Hlm/HR8R/WEkeSGBqjDp27W11sMpzz79QkdHZsCPxfz/7nJM4dfNW7axuVa3N2Il+1SIw0ldu2FmtWjUyWt3Sj52Gsv+om49CeeSRRzTPxx5//J3//JNagkthOLKrJxUpmwSKwFh59rnnofTsN5gs6dmnImtF9eg7CJYtsUnrtu3OOXNt4fK1X1WvzdknzZj/zy8i12yOVUsjAlNPkX/xFuk00IyfMiu6QZPUzBNuc07NZySFfKbPXYwTHc2/xOWIqOI/rCR2CIyU5IzjrPcbPDK6fuPDx8+zW1S9RggNwupWCGzmgqUcOAQRE1YkyUKfNerUpaN9Bg1HKFMO51GSc02ft3h3aiZZjp2+Wju6wYixk/ikETXqTJ21UCMweC5dtYmL5aKYwNQ2gzLbd+mJJsrZw0bsRL8qElj3PgP/45XXyKi5PfHkk888+5y2fnf5IjAYieRikwqvzSUEFgQJFIG9+94HaUfyVQsrb7/zR4rUd9Pmjhw3+dN/foHZCZK/+tWv4QBagv7Hd99Ts7h9ERjrNNDQIEh2jEFadvJBe2MfEav4DyuJfQIbPHLcn9//C5R5i3+G8df//owaFHR8jgXFLulQLj7rNmwKy9/+/t/Qqz32GPu4zMkQ6ROmzobyyquvU1I9KQJNbEQZX3jxJT5EZ/y3J5548623tRVYp259OAuBilItCWlHyOepp57G5wcffsQlhIfYiX7VIjAChierkT07dOlFFjRHdtMIDCU8/fSvoPzujT9wXrW0Vm07sUXNKFJaCQiBwaFRs5YUjv/715duZXzBgOI212EffvQxFBAYjR2qz5xFP4HVXv7tK5NnLmC79ggxI/ccn0591ENKSQRGlo//8SmGVM4uwuI/rCR2CIzxxh/eJuPQbyd88r+fUQhYYXn+hRfJn+ey0EeNn0rKop/WkaJOXknZGpfy1jv/qVpUAiMLBodpc35cunozW76bPs9KYOpVQUGxWpuBjhWky6TVlRt2cvawETvRr1oEBkWbdmlu6jtS1U0jMCqNQe3YVfwlGbupFpHSSkAIjMP6h7ffoYhwXKD8/eN/4JOe9YHAuvYawIfwOXXWQkS/S8/+mOFaCQxK+rHTWpRLS2BR9RpNmfmDWoIIif+wktghMFXPzLuA9fRrr/+eg/LeB3/VIsirZ37GWKduQ5ey5KKi6Hmjegqs8l/8zcuqpSQCo1UgWZas3GglsPf/8qF6LhSrtRnSt8Qm0cqPD4WN2Il+lSOw3LPX1WZhdVux3jNcam5WAlN1zNdIEQILuASEwBCF5IzjbvMRMUWEPvceyB49cRoGsvFTZpGnlcCwRNt3MMdtDmr0poHs6iPE/3jlNfXrPFYCAz9puTQftDfOLsLiP6wkpSUwtBYtOgirZqEVGNEVvdqEgoV474HD1KJUAss7fxNKZK2o/kNGcTlus21Q22MLERg9mibL7974g5XA6KqoWCgoltoMrfVd5pNDelyE5PezF3FpYSN2ol/lCAyybM0W0snIoKOv/e4Nl/l8XM2rEhhm8Vjyc3LVxhguTQgs4BIQAtu1N53eN2jkRArD7YvASHn44Yd5xKFP6zuwBUtXkW4lMLd3lAQ27EgkHyzpfvsfr8ISUaMOlyOiiv+wktghMEaWu8CTJTkD+ptvvZ1z5prLDBBZAPqNBH+Jo3X7LqTQiodA7yBcCoFB6PXYZ59HaOd9970POEkKEZjb/Pa8y1xaQbcSGJSYPQdQLAafddt2u71tZtS4KS6lzQweOc5lPkUMvzmQnehXFQITCVEJCIGVJP/+zLP8bS6MAjMXLLX6iFSi2AnrAwms/NJn0HCewsYmHWIqCpIwgVVxsRN9ITARR0tQCeyJJ59s1rJtz36Du/UeGOxRSaQMYiesFUBgWJSjeXTvMxBNpVq1akFtKrRuoxcZVVzsRF8ITMTRElQCE3G42AlrBRCYSKWInegLgYk4WoTAqrLYCasQWLiKnegLgYk4WoTAqrLYCasQWLiKnegLgYk4WoTAqrLYCasQWLiKnegLgYk4WoTAqrLYCasQWLiKnegLgYk4WoTAqrLYCasQWLiKnehXdQJLzz7Zo7etf1ggGTx8RELqYU5GfFX088OSxI6PTaldu8aR/ItWexhLQAiMQozasx6qRBkxeqzVKKKK/7CSBJvAAth/HyiHcjx/hSFCYif6QmDlIrDvZxZtyVGSBLADzJz7Q86Za1Z7GEsACQy1Zz1UHilnZB9IYLjstCOFf89RNcV/WEkeSGA1axTtjlEG4T7epElj69HAihCYKnaiX1UIDGNNXNLBtu3a7dqzf9iIUW6zrWCAYAKDHT48JO0/mg+9d7/CXYVYmMBwNO/8TfZv3KQx9NHjJlCyV99+tWpGonDyJGPXbkXb5Y0ZPxH2mMQ0StapUxPJ+YuWURJdpWlTz584QNq0bYtD47+bAr1582Zk7NCxA4w8uuHWkKxTp5bPwkNaAkhgVHscjoGDh+5Lz9biTqJWIB1FQKG3a98e+sChng3xyE6rOs5OChoPBk1r44EgrOzMBDZxyvQIb/TRwHA7tWpVnzJ9tnphaouqOuI/rCT+Caxj585cjYt/WrPk53WkUyAmT/fsgYk6z8g9y1F2mx1QiykVwg4k2Scvq0n2jzD75s6E1F59+qqFDBg8FMo333xDxrp1oxDo9ds8/zMX4em/NZnAmCyJfamV9ineotRWGrsvHZ+rN+2g3a1+Wu35w14MUCizYcP65J+Rc6Z65Jd8X40aNRw94Tsk+w0cRBYMNXWj66j7Y1Wu2Il+FSIw2gatJALj0QQxJn+3GfKD5v9bshCBNW7SiIt1mwMQJQ9kef5xauX6beMmevhmW9w+8tken8xZPMXmngWVskP7Dh3Ivm6LZx+2r1u2pHa8K3E/Ptds9vxRQtLBbLdlCG7WrGl69ikoWe7C/ZCO5F/UCg91CTiBDR81ZuMOz85yNap/5bbE3W2JjirUt4eP/JaSHAhNKanxoO2RQueiUyP66Vme8RfRxzQFDWza7MI/J+QVmNaiqo74DyuJfwJzKyswEJh2qGnTJm6zUxOLTJz8Pbqb1gE5uNoKLMIkKhLVSAr6JifBZBMmfU/jD8las6ezc2TEF6QQobqLE9jGHfEPbKU8kWrYqAGXrDXL5s2bq0kQGCVp1MLkm4Ya57QxO9GvQgRW6FYCgWnNEcQABXNe/ptdErT1unWjtWJbtm7FFkzq8UlTG3pmxWWqMmPOAhhRGjuoblirQSfS6j9wMHSaRmkENmvewkXLV6rFZh4/pxUe6hJwAoMgrHN/WELTBWvlu0uuQM2zJAWNp379utbGE5+coZZAo5J6Aa1at1KfUauPENUWVXXEf1hJykZgaiC4zrHqXb3B09jUDsjBtT5CtK7A2Bl9E5/LV2/4fta86CjPxrsomU86ZrznT5nZmZUDR92kqARGoVcvmEQbQ9zeBzNQoqJqYSjQcmlJJjDInv1H3d6hhrjcCWIn+lWOwEAw/QZ4lsx7D2QNGjKMCWzYqNGqP01DMOJ079lLtQ8ZPiIxNZO7BBX73dTCFRithPhP8Ljd7NmfpT6ITz6Uc9T0jI7y/G89mh0fciszIGTk5fzchUvcFgLzTN6LP1NCq9UKD3UJBoFxH3Zb4u62RIeF3z526tKFy/GplNR4NDciMER//9Giv4r2SWBai6o64j+sJGUgsM0xnj8E4EMagakdkD/dpSQwfqwCC631sQLTJjTszOuq+T8uJ4U4D1K/Qb2NO3Y/sJW2bd8Oc1mMaf0GDsLd0SNErbXQopCFCYxGLe2unSB2ol/lCAzy40+rkaQ3UkxgMYlpEea4htEQya2xe6F37OT5Y2UMfLSuchd/Bxa79wAXS+/ARo0dT8l27dtHRnyxLbbwESIZa9WqTorbfKUB+8Klhf/DW69eNJK9zSfs6BVolFjnHTvl6R4tWrTAob79B7ot78BohqgKrcC0wkNagkFgoCIeKbS4k2gViFBSEKHQWINJMT4xZHBwqZCM3LPu4o2HHg+SrFy/Dfa6daNaf9MKAyU/F6LXXRR9lcDcZpvBUXcJLSrsxX9YSR5IYKAN1NiWmERtBYZAHMo5jUBoBEYdEA7UAbm2wSJ2ap5aAvdNrMC4aWH6i0PMHGppEeY7MPaM3ZcOCz3hdHtb6TfffFNSK809e51LYwVGDCx16tTCSIXkwWOnQdg4etgcJTzvwMZNiFDegWGoQXtLOez59zIniJ3oVxUCK48MHT7SahSpGAkIgVWiqCNOoGTytMI3JWEvdsL6QAIT8SnqI0Rnip3oC4GJOFpCncBEyiN2wioEVjYRAisJQmAiARMhsKosdsIqBBauYif6QmAijhYhsKosdsIqBBauYif6QmAijhYhsKosdsIqBBauYif6QmDBFe1rS1VwM8NySqgQmJ3vp4mUVuyENeAERr8ZtyOlCrrV2WoJhqB3zJizAEpiWub3M+dBZi/40ermQLET/SpKYMtW+nYOeJPSCqyUzQzLuRdc5YoQGEsFnMJpYiespSIwO3VIG7XYETulWZ3592Slyl42QdfAWWgE6NOvv3O2ibIjdqJfVQhM3Z4uQvk5+vhJU6G0bNVSs3MyNbPoVxH9Bw5u8bXnV1np2ScjI75o3Ljwazwotnrkl4mpmZSkbdYycs5QIfRDrh+Xr3J7f4rUqFFD2r1wzPiJlEXbJI1F3b1t2aoNUPjHZJ6SzYuhHy26i2+QGGHu/YhPdS84t/O2O3ugBITAECDUQOeuXSmJONao/hUsmXnn3WZd7UhI4ZpEdGCn3X1o+ziKy86EVC4QJbjN32Z5ltQnLlAhfJRKIAtKUCO7ZvNOJDdsj6OjnIuVknbFVLdGpMZcq2YknzFcxX9YSR5IYLxnIG1eCpmzYLG7+L6UZKetDmfO92yiQc68kSD0iZO/x+fOxKJmEFG8d7s9fbBjhHfQOJTj+d0V/0iZzqWeKMLzWzTPD0DVpqUWjs5+7NTl7j16ar9kp7PQ1ogpGTkLlqzgwslt7ATPTh+Q5IPH3N4pLB9Vxcn7ptqJflUhMAoeb0/HK7DkQzluc0RQ3VTlm7ZtuBAmD9qFCKOe22ym9MNArQ3xRohqgUxg9Ov3tu3aHcm/aN0kjUX96eVPazeR0qaNZzTkkoePGqMmaYPECO/ej25lBebA7c4eKAEhMAoQZgCU1IKCT9oiATWJCkd0tscnI3nUfYm3DSNP2jOFhpt96dk0D9Di7jbjSyUgBOoGdKh83uFXy0WK/10xNWe3+dNUUsJV/IeVxD+BaXsGctVp+1KqQgRmbSRqUtM1HwwamMFwL5sx1/MEj49aV2BqmZpF3ZoVTIbhYuOOeHbDWUBg/D9BmAeruVi8KzBP2zuQlc8/bPWz7acTxE70qwqBadvTMYFFR9WJKL7qYoWFC4mKqkUKPWSgPoACaY9nrRFbC3QrBEZGLI8yj5+zbpLG4nP3Nu1ENDvjJG2QqF6G+gjRadudPVACQmBqgNzKH4PRZuFqTaJ+ODqIy4RJ35Ou1jlt84OFl89wuJX4qpGNMP+sYN3WXdYC1aRapruETfmoMUd4eTeMxX9YSfwTmNvXnoFuy76UqoDA0CvbtG1LSZVCVMVqVMO3euOOCVOmkU57qbCzTQJjcZuLxZwz10hXt0bEWUBgvEs9ZlRoEt9Nna4t6bSXCOrpStr20wliJ/pVhcC07emYwGhZs2XXHkr6aVLuEgisY+dO6t+maBm1An0SmHWTNBaVwJavLlxAkHDJk76fqSZpg0T1Mrj5OnC7swdKQAiMAjR1+hxK8u3TJnVqTdIKjJLa+sltLtFAcpTL+miIku5iu8wVqBvQYXnN20dpuUjxsyum6sx2ba/F8BP/YSXxT2DanoFahasKS/lXYNrRshGYmsSUBZOt8ZOmui2v6FQCc3vpTXVwe0cAfrrDDiVt++kQsRP9qkJg6vZ0kIaNGlAUGzasH2FuYUdJmlbnnb/pNsMMmTpzLhfik8Cy3Jdq1ao+ZPiI+T8up23p6dl6fLLnmrU26pPA3MU3SRvx7RjeY14lMHoZxmwU4X0Hxlv2qRsk8nnd5hoxMuKLLeYGpk7b7uyBEhACwy1TWClAiCO9A6ONCqFs2pnANanuUJB2JI/fgZFEeHdNTEzNRK0uWLJiwOCh2qihlnDw2GmKLD3GXLF2c4Q5cSZ/fivDO0752RWTFtYYDakx839whLH4DyuJfwJzF98zkNfN2r6UbmXHSyKwY6euRJjvwCg0HF810FZj1+6eFTMNGoOGDIOOrq3Nk3hPRS27WjIl0dl/WrOJkuorTzoLNUuNwGCHRS3H7SWweYuW4qj2dNHJ+6baiX5VIbAQEhCV1WgVrbmHqwSEwDThiQhJpdRkpZw05MROWB9IYKEi2vq7bBJO7cpO9IXAQlXCqaX6ESGwqix2who2BBYQ4WfUYSB2oi8EJuJoCQaBiYSK2AmrEFi4ip3oC4GJOFoysrL37I2z2jWR6Iel2Alr4p6Yw8dyrXaRUBc70RcCE3G0JKXsSUt/8K8sJfphKXbCmrw/OTktyWoXCXWxE/3wIbD4hO2Hjhy12kVCWuw0YsiefQ9epYmEnOxN9nx19oFis5GIhJCkHz6ckFhsVwefEj4E5r50C+04/2Lg/wBXpLIkLm5TWrrn39DtyO4EzyYjImEj8bu3WY0+JXV/SlzcFqtdJEQl/8JNm5OScCKw25m5+TZvW8T5knvmcqlGpdhdG/bsDZkdRkT8S+KeXbGxhZt82hHMdY6f9fxaTiQMBMN41glb26SFFYGR4OYhe5Pi0w9nioScpKXvpwimZ2RYg+tfjp+9SnlT0pKsJYs4X5LTkiiCeedK/acNBzIOUV6s2q0lizhf9u6Lowhag1uShCGBkRzIyNiXtFsk5CQ5NenYSc8m8WUWzN1SD6RZSxZxvqSmp2Xle/7GocxyLP9ccuo+a8kizpcDpZ+zhi2BiYiIiIiEtwiBiYiIiIiEpAiBiYiIiIiEpAiBiYiIiIiEpAiBiYiIiIiEpIQAgd2+e18ITEREREREE1DD/fs6ZZQTASYwQAhMREREREQTUIPOFuVGUAjsy3GePxoWERERERGB/N/orNAgsD/0zsCF7jx81XoPIiIiIiJVTbYevAJS+GO/wzpblBuBJzB6DSYPEkVERERE3ObDQ8idezpZlB+BJzBC1x/z6aJFRERERKqyTN9xXmeIACFYBAYs33vpP/t6HieKiIiIiFRB+evgzNUpBTo3BA5BJDBBBaOg4MKumPX70xL0AwKBwDDQNdBBrl27oh8QhCyEwMIH9O8GEP2AQCCQDhKOEAILH3D/xFJMPyYQVG3Q8wkhsDCDEFiYgB6PSBcVCHxC7R0HDybphwWhCSGwsIJQl0DgB9JBwgxCYGEF6Z8CgR9IBwkzCIGFFaR/CgR+IB0kzCAEFlaQ/ikQ+IF0kDCDEFhYQfqnQOAH0kHCDEJgYQXpnwKBH0gHCTMIgYUVpH8KBH4gHSTMIAQWVpD+KRD4gXSQMIMQWFhB+qdA4AfSQcIMQmBhhUrvn7VqRuqmwOH69eu6SSAoDQLSQfJPnLh27ZpqOX36lJr0g7S0VN0kKAeEwMIKPvtndnZWxFefkyz8YQEsnISonqAfMk6e/J1qtw+1QFUfN3Z0bk4OJ8uGw4czdJNAUBr47CClxaRJEw+mp3MyLy9POfgAUKc4fjx36dLF+jFB6SEEFlbw2T9BYJpF4y02clesXy9686aNpGdmFvsj8Js3b9675/lr1Vu3bl24oO8arK7Avmndsm50bdI1Art//z7r2uWdPXuG9RsmOCkEJignfHYQwtGjR0jRGjzaOet37ty5dOmSRmBIsu4HXD6QkXEIPYKT2hkF9iEEFlbw2T/BEFh4kZAFXJWWlgrJzMxktxUrlrNOGDVy+MKFniw1a0TQ47t2bVvTIabAxo3qe92NOXNmxcfHcXLihHFXr14lTyKwjRvWN2xQ1zA7c+1a1aF06tgen3sSEykLOeN0pN++fRsKZTGEwATlhs8OgpZ29+5dw+Sn9PQDUPbs8TRIdBBq/9Qs8Xn+/DlSVAKzPnXAAosUerQ4evSoqDq1VAcmMJyxRvWvDPOMI0YM8xYjsAshsLCCz/4JAiO64ufvEeazRMjaNavZbePGDawTuGfu2hUzbdpU9VCD+tG9enaHqL1XewEGAsPnyp9XgMaYwGbMmEZHKeN3Eyfg83JB4X+2wrhs6RLSGzWsRwpRnSEEJig3fHYQbsOgK2rVkAP79xvm8wBu5OzWv1+fkgisdauv8dmje9cWzZvcu3dv9LcjDZPADh4s9NcIDGds1bKFtSsJbEIILKzgs3/afITYtElD1jHTzMk5xm5YIWkENnHieDVJ0IolAiM7E9iC+fPYSJ9a1/1p+TIkb9261fLr5mSJjiqcvQqBCcoJnx1EJTDVvnjxov79+7ADuw0dMogJLC8vb9TI4d4cxu7d8evWrYEn+G/mjOmUBQTGfdBKYNu3b+XsgtJCCCys4LN/ovPwvHLY0MGGhWkI+fn5sA8ePLBG9a/oicfJkycjzLWa1b9udJ2xY75ds2ZVu3bfkOXixQsoX/VhAjPMMxKBDR40YOSIYTjFksU/wg5de7a5fv06Ol2L5k3BYT/8MJ+ZTAhMUE747CBq864bXRskRAupWTOn9+zZDWup6pFfoql/O2oE+gXaKuZYTGCtW7VQX5IZZmmJiQmkoATDF4GRQs0+MuILOmOZvzlVlSEEFlbw2T9LhbNnz5w/f161lPSG+fbt2yAtTmovwHwCBLby5xWG90scN2/exAw0LS01KWkfPzA8edLN/vQlDowRbBEIygM7HUSdJ925c0c5UvglDtVinduVATIzKzOEwMIKdvpnkGDnF2BMYAT1ayMN6kezrkEITBAoBLyDBITABGWGEFhYIeD9UyAIJ0gHCTMIgYUVpH8KBH4gHSTMIAQWVpD+KRD4gXSQMIMQWFhB+qdA4AfSQcIMQmBhBemfAoEfSAcJMwiBhRWkfwoEfiAdJMwgBBZWkP4pEPiBdJAwgxBYWEH6p0DgB9JBwgxCYGEF6Z8CgR9IBwkzCIGFCbKzDqFzksTHbdYPCwRVG9w7IMdzj+qHBaEJIbDwAfdPbQM3gUBw8+Z17iD6MUHIQggsfCD9UyDwA+kg4QchsPDB7Vu/yOMRgaAkHD2Sjg5y9648nwgfBJHA7ty5nXEohWc9IiLhJ6kp8VeuFP6ddGlRUHAhOTnOWqaISNhIRkbKvXv39KYfOASLwG6Zq4GcY77/SkogCA+cOeNGOz958rh+4EE4ceIYMp49e1I/IBCEEbKOHkQ7v337tn4gQAgKgSXs3oKppW4VCMIUp06d2FWaNyse6joj1CWoKti3NyYxYZtuDQQCT2A5OZlxsZt0q0AQ1sg4lBIfZ6vZx+7acCRzv24VCMIaaPZ5edm6tdwIPIFhdhnUh54CgTNhcxFm000gCCfcvXs3GC0/KASmmwSCKoDsrEO6yRdyc4/oJoGgCiAY1BB4AktOitVNAkEVwLlzp3STL1y8eE43CQRVAHv37NBN5UbgCSwtdbduEgiqAC5dOq+bfOHy5Yu6SSCoAgjGN/uEwASCwEAITCDwAyEwgcC5EAITCPxACEwgcC6EwAQCPwgHAhvmxaxZs27duqUfDgI6derUvn37jIwMtpw7dw6WunXr3rhxgyz37t3DJd28eZN9BILSovwERu1QRWJiosvlwiF8/uMf/9AzCAShg3AgMFdx6Id9AW7jx4/XrfZgPVd+fr5qrFGjhuHZtvEO9EuXLhXLLBCUBuUnMGqHKspMYI888sjTTz+tWwWCykOYENhf//pX1kmZPXt2z5492efMmTNYNq1f7/nRwK5du+D21VdfYTZKRxcvXjxgwACan8KT7MRDQN++fZs2bUpLq/T0dD7F448/fuDAAcM8KbKTMTIyEkm32y0EJig/AkVgajs8d+4ctXCVwNBf0HTZhxEVFTVt2jQoI0aMeOihh6pVq8a9Ru0Xhvkg5O7du61atYK+Z8+e+vXrz5gxw1uMp4uhKOpiPrMLBGVAmBDYyy+/jI7RrFkz6Pfv38fn0KFDs7KyoEyZMmXhwoXEOi+99NIzzzxDWXgFBr1Xr1779u0jH6Kop556io+mpKRAefTRR2n7SJeJF198cccOz08QfvjhB8rIIAfrwCEQlBaBIrBPP/30nyZgOXz4MLVYl5fAoDClgck4L7mhd5CirsBcZr+4desWFHpODuXzzz8nQnrsscfwiRlk+/btofTp0weFcIGc3VC6lUBQBoQJgTG++OILdEXuJy+88AL07du3u0zKyczM5CwqgR065NnvAMr169eJwMCChrfzU89/6623unXrRlnee+89Oh1WWkuWLOHTcYEuITBBIBAoAmMYJRAYNfKHH36YDhGgf/bZZxs2bKAkExiVScapU6cSS6kZMzIymjRp8j//8z9vv/02ktHR0dTF0HHQxUrqVgJBaREmBMaPEA1z3sd96d133yV91apVzz77LHTqgS6FwN58800k0TnJU31IePnyZZc5OSUsWrQIR3fu3ElHW7duDb7E9FPtuoZZeI0aNYTABOVHoAhMbYc+CYwb+TDvIz7g9OnTRGnkzwRG/YJ8li9fDq6iQsjyyy+/QO/QoQNWXURg165dc5lcSD7WbkUZBYLSIgwJjCyvvvpq8+bNoWzevHnIkCFQkpKS0P2oC+ETizN0HnUuSVAJzDA77ciRI0Fav/71r3fs2HH79m0cbdOmTd++faHQO7CYmBjon3zyyTfffAPl9ddfNyyPbv5pPr0RCEqFCiMwNFQ0cpe5MCI3ZEHy3LlzUVFR5E/TQWI49It69eqNGTPG5X1cwb1m/fr1v/nNb86cOfPMM888+uijUNQORdC6lXZUILCJ8CSwq1evPv/887Dz5A6rJSTRrygJlvrzn/9M/eqjjz5yeYEJo0ZgAE1C4U9J6thA27Zt2adbt25cCFms3/5iZ4HAJiqGwG7cuIEJH5La0zx69g6cPXvWMIuqWbMmt2Q61LJlS05yxmrVqiF58OBBfKJD5eXlkbPL7GLko3UrgaAMCAcCKw++/PLLDz74gPQ5c+aonbBsQAkvvfSSbhUIyoTyE5gToHar8ncxgYBR1QmM1lsMJHWPUiI3N3fnzp1JSUn6AYGg9AgPAnvmmWcC2MUEAkZVJzCBwMkIDwITCIIEITCBwLkQAhMI/EAITCBwLoTABAI/EAITCJwLITCBwA+EwAQC50IITCDwAyEwgcC5EAITCPygqhNYWlqqZrl+/bpmCR4OHpSvFAv8odIJLIC7xecdPx7A0soAa2cXhDrCgcAivvr8woULK39eER1Vi5LoKidO5PXq2Z19ataIKMqgAM6a5fDhor+pDDasZw8UmjdrrJsEIYhKJ7Ds7CzdVDL8t7rRo0f5L23c2NG6KaBY+MMCfPbv3+f06VP6sfIhI8OzVbGg4hEOBMYTK+KDpUsXq0mge7cu0DnZuVOHOrVrXLlyhXzS0w/gc9vWLXSUCOzSxYswtm/XhoxTp0xC8tChg5RkWLOPGDFMzYiWjeTAgf2hu935q1evgl67VvV79+5RdnKLqlMTOjiYkoyLFy/A3rNn4QY/2mVAb9G8KelbtmxG8vupU4zi97t/fxqUenXrkJsV2p3OmDENyV27YgqPXroE7q9R/StK4vpxdOPGwu3JBcFGQAhs7do1iBrTw9GjRyIjvoiq45ntGZYGkJKSjGS/vr0pSZQzauTwu3fvQunapSOOEgHwpLB1qxaGpZcZZvtEa8fnrFmePwYDgSUnJ5GRHGbPmonkqlU/kzNnxyVVj/ySi7p16xZ0dNvCchVofZmMrKAQ3Cn/Szvs8+fP1S4SV4XOiC5peM/LVTF82JCpUyfD+fLly2Rp1rQxklMmfwd944b1uTk5SKJmqMyfli8zTBaPkD5SUQgHAiNcLiioG+0Zpgd5u4faTLmzYRaGMf3OnTs0KMNnw4Z15ED7xRGBUd7z5883blT/6tUrXbt0YuPECeMKC/WVfcniHynjHROUBeM+5n0gsIYN6qK3oD+QnT7Xr1tLf4nUrWtnLplADmPHfLtnT6J2GR3ae7rZzZs3e3Tvio5ETIYRYe2a1YYyF+ZK4G6sgRwwqIHkcBm0bOVcvXv1MMxN8HAKtpe0nBUEHOUnsGPZ2U2bNIQyeNAAGmHnzJmFz1OnTpKD2tS5xcKTaAYEFrNzB1EUykHf4SwagRmWFRjcaKJGDqAKal1t27RGc1q3bg06BR3NMP9shSmWmx9NvCiZkpy0YP48shOsfZnspKz4aTl1K5CuatdWYLgq5nK1KqCgt6rUiGu+cOGCYU5SDZPAwJ2UUV2B0b+jSR+pGIQJgWHqtHRJ4cILY3GEOSGiTbIJ3J7QIukoNUpu9JmZmZhwGSaBxe6KYR9yWPzjIiho64XFeaFlVzNiMYTpW0JC4ZXDAgLjuSfN+Pga1HOpwNSV7Jg5GpbLoEMnTuS1adNKK4SHEnQt3Lu1ZAIueOaM6aSTDyYB6pXwM59Yc022datnndelc+GIIAg2yk9gaBslvdbFnE9r6mqLJdSvF80PBrhVoK+BfuwQmJrkR4hozHRePtSwYT1DITCtTRKtQq5fv+bN4UFJfVlLMshiJTC6KmuvZ34aOKAf2As1ybny8vJAYFwzKoFhzhchfaSiEA4Edv78Oa2xomdqFu5s1SO/JEVr5XPnzEaLNEwCQ4f/ukXhozkgPz//2jVPz6kbXZuNBC07MqqsuXfvnu8mTmBPEBhfhnp2niFaQQ6YeKLPa5ehPjjFnBrUouQrGkowASeFloYacMEtv25OOsqZN2/O9u1bSSejSmAFBQVnzpwxzLm89WmqIBgoP4HNmT1zx/ZtutUEuonW1NUWS0D7QXtLTfX8ezK3CozO6HRgHWrtDepHk70kAkvat9ewEBgVguS+fXsnfec5KROY2iYNb1PHYo4fZRNK6suk0CMKQ+kCZC+JwLSqMJQC6byoSUoSj/okMPQRUtBHSBEEFeFAYGhnvXp2J2GL9sRswYJ56F0nT57s2KHdpEkTMbeCz549iRHmbGvhDwu4sdIjRCxEdu2K6dO7Z7t231y9erVWzcj4uFjy0R4hatkjzBdIyEgXwEePHcsGgXXv1qVzpw7o8HCgo4bZM3v27IZRJjLiCzZyacuWLhk/fmyL5k21y8Bibtu2regnw4YNJs/FixfVrxcVs3MHJbF6w/1GmO8YcMs3btw4d84z6HDhhKg6NXGF6KIbN25ITExo1rTR5k0bO3VqT91VW4GhtPXr19EFqNcpCBLKT2CGGSlMsPCp/b3qZXO0VZs6OaO1RNWplZKSbHgbAFEF3KCMHDGM5mFHjx79/+3d61MTVxjH8X+xjQoKeKu3qq2jgqC2rxy06lgdqyjFttOqiGg7jtY3dcbLVEFt1WLF64taC+OUqtNYKpAE2T7ZB47HDQmh2QXO5vuZHSZ7shwS5pz8stndJzq89eME/V0ddWZVRru8/dKhEggw3a8KzB2ZpzIdZEzKwG5padYjSTImZdivW7fm+zOnZfbJzp9uH5jLO7Zvk31B+XM7/Y/40um0BGFr65E1H642/Xv+QT7pXyPZe/vUEvlX7Nm9y/wrqqsqFy+aL49w0cIas4F5wHaAeX6o60ki2z/ZyhyZMnEIsGk0qQEqAba1cUuwNYeeSxkFeWm4efNGsPX/iu5xwgglwKbLpGZHkc6d+yHYFJnSR3iBD1cQCgKsJJOaokUGGGAQYNOo9ABD1AgwYOZyOsCAqBFgwMxFgAEFEGDAzEWAAQWUe4DlFo6KqGCadlt85xOWSSy+K7hrigMsmUw+e5Y9td2WSqX0MvZ8JhyrQETKPcDMFSfmEhY9FzZ0ekBbO79//96EZd8mPAA+4QaIgVAC7ItDn9dUz5UcOtF+3D5nXd4DydLe3mbOKb948fy3J0+8+U3fhCcfhTUUw+oH5SMOAZbIKUhYv6FWVrVYjky/CxfOy+qypaMR1di4Zfasd/TyRg0wu4ybmUVa90yrC3r+RSfza+ZlMhldNQLFAwM6OzsSYxeceWOd69/S2/mqC5qHoc/FvIIcbzsmq729vbrBlSuX7d60uJwWwvGyZRSq5lbOvn79mq7COaUH2MDAgBlLnn9V7/Pn2T7txh3bt+kNE2AyRxJjRTg1wGTV1PAcHh6umldhhpndldbelMjU1cJ1F7VSqI5tu0phX19fxZxEZcUs3QzIJyYBZhckXLZ0seSZtnv+9NNCAJcuXfT8T96OHcvuBum9uXtg2v7748c6zyUSPP897K1bN72xa/KN3OKBtsHBQW3vGLv6WH/ae2Dakls5TdslL/W5SAR6fsGqJe9l69ppVV+zWW3tWk3rRv+1QF5f9DMfXgJcV3qAHT78dVtbq92yb99ezx85ugcm6fXHkyd6lwkwnSN7du/y/Bmkw8yu4SkjX4vY6upo12O3G+rr9EL+wnUXdTZlr0H2Lz02/ZgbejE1kE9MAkxvaEHChFXQTHZQZPrpvVpOe2RkRAtd62/lCzC7uqDWotaec/dmAsUDbQcP7LdrIZqfdoDlqy6oW2oxbPNcPli90tS1szuU/JNnpwW0dNHqA+M+Kjik9AA7deq7QHUoDRUdG3e7u00lQ88KMHuOBGp42sPMHoRKa2+anTNj3LqL+fqRhFu0sCbxdjlTIFesAkwLEtrTyfOnn97QANvYUKcV2HSzfAGmk9ywCw/a7bnFA+0pd/Vqp77bNRvoTxNgBaoL6pY3/H1HQ3YE9c+ZquEyzz/+aFNvT49uoL0ZgUcL55QeYN7bw+D06ex3l9iN9t6/CTCdI1r9PV8NT8OsyrDUT+YlNQO1N3PrLsrY3rt3j7XJm37MdDPf6gKMKyYBJktLS7NOANnpqameK+Ghq4EA++rLQ5s3N6xYvkTeY549e8YuG2qKB2rLqpUrOjs7Fsyv8vwJWbt+bVPTPs05U1Ewt3hgwi/vplUNzao+Ql017UePZl8d5IYeopPbckPvtbfU57J61fumXTrU+m+vX79euKBaVk+eaNc9M2mUJyXp2NubfdamEzgqlADTI6YyPqvmVeYeuEqn07e7RgPDBJjMES3CKcNJZpCMMVlMDc+G+jrZQIaZ1mu3h1nCr705Z/a7gS9fHrfuokwTmY8ytg/437Alv9u0/7Ourl9kbra1tcq7w0ePHtqdAAExCbBgU8RCrChoM1VQi7Ri+VKzwzf1/wRMgVACzDBHs4B4IMAc1nywqbJi1pEj32yoW79pY33wbrgv3AATn+7aGWwCnBWHAAPiKvQAA+LEjQC7dm38b+QD4u3p09ET3Avr+3P0QC9QVjo7zgWbShZ+gF3+MftdyUC5ufPrT8Gm8dy7dyvYBJSBKKIhkgAbHg6WwABir8j5WeRmQJxkMukoRn74AeZ5I/JA0+nstf1AmZAxn0wWdXDrxYu/opjJwIyVSg1FNOajCDCvvz8Z0cMFZiAZ7Q/uT+ILB+5232CCoHzIaH/1qj/YGoZIAkykhgblQXd1XX358u/gfUAsvPr3H8ktGedFnr5h6+n5TX7x4YPbEU1sYNr197/svvOzjHOtKx2FqALMyGQyyeQLFpb4LanUUHC4T550ktszC0sMluBYj0DkAQYAQBQIMACAkwgwAICTCDAAgJMIMACAkwgwAICTCDAAgJMIMACAkwgwAICTCDAAgJMIMACAkwgwAICTCDAAgJMIMACAkwgwAICTCDAAgJMIMACAkwgwAICTCDAAgJMIMACAkwgwAICTCDAAgJMIMACAk/4DWL6zfMNkpIQAAAAASUVORK5CYII=>

[image3]: <data:image/png;base64,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Wq1duyREOGJpOnhwT55ff2VHXn8FVhigAJGCgAJESBwQVAHCmMELF/4yf3l569Z1amfa1gKfUlM3aTFDnfC3iiIJBYiQ6HDNBYgQcvUEWYCEv/++oF81bUpeWeDTls1r1b69aVZtIwcFiJDoQAEiJA6gAAUHChAh0YECREgcQAEKDhQgQqIDBYiQOIACFBwoQIREBwoQIXEABSg4UIAIiQ4UIELiAApQcKAAERIdKECExAEUoOBAASIkOlCACIkDKEDBgQJESHSgABESB1CAggMFiJDoQAEiJA6gAAUHChAh0YECREgcQAEKDhQgQqIDBYiQOIACFBwoQIREBwoQIXEABSg4UIAIiQ4UIELiAApQcKAAERIdKECExAEUoOBAASIkOlCACIkDKEDBQQQIx75k8S8xOR09csip9dVBASIFQcQFaODAgapr167q4sWL7qIcKVKkiBvKNePGjVPdu3d3wwXOiBEjVL169dxwgZDd+c1uGSl4KEDBAQL0559HtWicPn1SnTmTEVPTyZPH1bKlc9TpjJNu1fMNBYgUBBEVIDSibdu2Vf369dPpS5cuuUWyJadGuFmzZqp///5uWFWtWlXVqFFDLV68OMdtXA3h9p8dsSpA7nly8yS2oAAFh5MnT2j5yciIPfmxJ9Tx4sW8va6bNGmiOnXqlCeWmro93wJ07Ngxk75w4YIaP26stTRvhKtbfjhx/LhK7Nld7dyZZmKnT59W8+cnWaVIQRNxAXJJTk5Wbdq0Ua+//rpe/vzzz5tljz/+uPrPf/6jXn31VZ2X9e+880515MgRncd07tw5LRGSb9y4sdmGi18dbGQbN998s85/9tlnqn379p7lYOvWrabst99+61nX3kfRokV1Xo4BDBgwQMduvPFGI0B9+vRR1apVM2XatWunOnfubPICjh03fdnPihUrzLLHHntMx2666SYTQx77wPz222838ZdeeimkrpIeMmSIWfbAAw94lgHUAfn777/fxMqUKROyPRI9KEDBAWLhykasTqhrXqhVs5pqmFDfE5sxY7oRIMxz8/agfv06Kilpntq+PcXEKlZ4yypxBTeOB/ODBw96YiBc3YTc1m3p0iVGxOYn/aa++WagrsPmTZtUly6h93xScERUgEqUKKEbyDlz5pgYBOjee+/NfKrJ6i596KGHVGJiok5DHhYsWGDKSuOKBlhk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>