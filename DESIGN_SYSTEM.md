Design a complete, high-fidelity UI for a Vietnamese university library entry and exit management system.

Working product name: “Library Access”.
UI subtitle: “Hệ thống ghi nhận ra vào thư viện”.

This is an operational application with four experiences:
1. Student mobile app.
2. Librarian desktop web application.
3. Administrator desktop web application.
4. Touchscreen kiosk at the library gate.

Create all screens, dialogs, important states, and connected user journeys specified below. Maintain one cohesive design system across all four experiences.

## 1. Product scope and business rules

The system serves one library.

Students enter and leave using face recognition at a kiosk, with a short-lived personal QR code as the fallback. Librarians can explicitly record entry or exit for students and external visitors. Administrators manage accounts, kiosks, staff shifts, operational settings, and analytics.

Account roles:
- STUDENT → “Sinh viên”.
- LIBRARIAN → “Thủ thư”.
- ADMIN → “Quản trị viên”.

Kiosks authenticate as devices and are not another user role.

Each account has a shared account code, full name, email, role, and status. Use “Mã tài khoản” in account management, because both students and staff have codes. Do not use “Mã sinh viên” as the universal account field.

Login accepts either account code or email.

Students can view only their own profile, entry/exit status, QR code, biometric enrollment, and history.

Librarians can view occupancy, current occupants, shared access history, external visitors, their own shifts, and read-only library rules.

Administrators have access to operational librarian functions plus account management, kiosk management, full shift scheduling, configuration, and analytics.

Only active librarians can be assigned to shifts. Scheduling is not employee attendance tracking and does not restrict login or operational access.

Face enrollment requires explicit consent to the current biometric policy. Students may decline and continue using QR. Removing enrollment revokes biometric consent and removes face data while retaining entry/exit history.

Do not add unsupported product features:
- Public registration.
- Email verification or email password reset.
- Editable student self-profile fields.
- Seat reservations, room bookings, book borrowing, payments, or fines.
- Multiple branches.
- Payroll, staff attendance, leave requests, recurring shifts, or shift swaps.
- Push notifications, notification inbox, chat, or report exports.
- User deletion, kiosk deletion, access-history editing, or visitor editing.
- A biometric policy editor.
- A standalone audit-log browser.
- A direct internal AI service console.

## 2. Visual direction

Use a polished, calm university application style inspired by Untitled UI’s application layouts and Tabler’s clear operational dashboards.

Use original compositions with:
- Light theme.
- White surfaces on a soft gray background.
- Navy as the primary brand color.
- Restrained blue accents.
- Clear data hierarchy.
- Subtle borders and minimal shadows.
- Consistent outlined icons.
- Spacious forms and readable tables.

Suggested palette:
- Primary navy: #173B63.
- Primary action blue: #2563EB.
- Background: #F5F7FA.
- Surface: #FFFFFF.
- Main text: #182230.
- Secondary text: #667085.
- Border: #E4E7EC.
- Success: #15803D.
- Warning: #B45309.
- Error: #B42318.

Use semantic colors for statuses. Do not rely on color alone: pair colors with icons and Vietnamese labels.

Use an 8-point spacing system, approximately 12px corner radii for cards, and consistent button/input geometry.

Avoid excessive gradients, glass effects, decorative charts, oversized empty spaces, and stock photography. Use initials for account avatars, not retained enrollment photographs.

## 3. Vietnamese language and typography — mandatory

All visible interface text must be natural Vietnamese with complete, correct diacritics. This includes navigation, headings, form labels, buttons, helper text, tooltips, table columns, chart legends, validation messages, dialogs, and empty states.

Use Be Vietnam Pro throughout. If unavailable, use Noto Sans with Vietnamese glyph coverage. Do not mix fonts across screens.

Keep text editable. Do not render interface labels as images.

Use comfortable line heights of approximately 1.5 for body text. Prevent Vietnamese accents from clipping at the top or bottom of text containers.

Use:
- Mobile body text: approximately 16px.
- Desktop body text: 14–16px.
- Kiosk instructions: 24–32px.
- Kiosk result headings: 40–56px.

Allow long Vietnamese labels and names to wrap naturally. Avoid fixed-height text containers that clip content. Do not shrink essential text to fit.

Verify these strings render correctly:
- “Đăng ký nhận diện khuôn mặt”.
- “Nguyễn Thị Huyền”.
- “Số người đang trong thư viện”.
- “Xác nhận hủy phân công”.
- “Dữ liệu đã được cập nhật”.
- “Vui lòng quay đầu sang trái”.

Use Vietnamese date formatting: DD/MM/YYYY.
Use 24-hour time: HH:mm.
Display schedules and timestamps in Vietnam time.

Use a consistent vocabulary:
- “Ghi nhận vào” and “Ghi nhận ra” for explicit staff actions.
- “Đang trong thư viện” and “Ngoài thư viện” for student status.
- “Khuôn mặt”, “Mã QR”, and “Thủ công” for access methods.
- “Đang hoạt động”, “Đã khóa”, “Đã thu hồi”, and “Đã hủy” for applicable states.

Internal enum names and API error codes belong in design annotations, not normal user-facing copy.

## 4. Devices and navigation

Student:
- Primary frames: 390 × 844.
- Bottom navigation: “Trang chủ”, “Mã QR”, “Lịch sử”, “Tài khoản”.
- Face enrollment is accessible from Home and Account.
- Add representative responsive web adaptations for Home and QR.

Librarian and Administrator:
- Primary frames: 1440 × 1024.
- Desktop sidebar, page title, breadcrumb where useful, profile menu.
- Table-heavy pages should remain usable at 1280px.
- Provide a representative 768px tablet adaptation.
- Preserve important actions and use horizontal scrolling only within complex tables.

Librarian sidebar:
- Tổng quan.
- Người đang trong thư viện.
- Ghi nhận thủ công.
- Khách ngoài.
- Lịch sử ra vào.
- Ca trực của tôi.
- Quy định thư viện.

Administrator sidebar:
- Tổng quan.
- Người đang trong thư viện.
- Ghi nhận thủ công.
- Khách ngoài.
- Lịch sử ra vào.
- Tài khoản.
- Thiết bị Kiosk.
- Phân ca nhân viên.
- Thống kê.
- Cấu hình hệ thống.

Kiosk:
- Primary frames: 1280 × 800 landscape.
- Large touch targets, minimum approximately 56px.
- Camera preview is central.
- No desktop sidebar or student login form.
- Device setup is separate from the public scanning experience.
- Do not expose credentials in the normal kiosk interface.

## 5. Shared authentication and account screens

AUTH-01 — Login
- Brand, subtitle, account identifier, password.
- Identifier label: “Mã tài khoản hoặc email”.
- Password visibility toggle.
- Primary action: “Đăng nhập”.
- Help text: “Chưa có tài khoản hoặc quên mật khẩu? Vui lòng liên hệ quản trị viên.”
- No public role selector, registration, or email-reset flow.
- Variants: loading, incorrect credentials, account locked, rate limited, network unavailable.

AUTH-02 — Required first password change
- Explain that the initial password must be changed.
- Current password, new password, confirmation.
- No bypass into the main application.
- Validation for mismatch, incorrect current password, unchanged password, and password requirements.
- Requirements: 12–64 characters, maximum 72 UTF-8 bytes. Use a tooltip for the byte detail rather than a prominent technical warning.

AUTH-03 — Change password
- Accessible from Account/Profile menu.
- Same fields and validation.
- Success feedback.
- Recovery state for an interrupted response: direct the user to sign in again rather than blindly resubmit.

AUTH-04 — Staff account profile
- Read-only full name, account code, email, and role.
- Change password and logout.
- Use student Account screen for the student equivalent.

AUTH-05 — Session expired / access denied
- Separate variants for expired login, insufficient permissions, and missing resource.
- Clear return or login action.
- Do not leave protected data visible.

AUTH-06 — Logout confirmation
- Concise dialog with “Hủy” and “Đăng xuất”.

## 6. Student mobile screens

STU-01 — Home
- Greeting with Vietnamese name.
- Prominent current status: inside or outside the library.
- If inside, show check-in time and elapsed stay.
- Primary shortcut to personal QR.
- Face enrollment status and action.
- Link to recent personal history.
- Show the time of the latest status update when relevant.
- Do not show global occupancy, which is reserved for staff.

STU-02 — Personal QR
- Large scannable QR.
- Student name and account code.
- Remaining validity countdown; default validity is 30 seconds.
- Brief instruction to present the code to the kiosk.
- States: generating, active, expired, generation failed, rate limited.
- Never present an expired QR as usable.
- Offer “Tạo mã mới” when permitted.
- Do not add QR download or screenshot-saving actions.

STU-03 — Personal access history
- Date-range filter.
- Cards with entry time, exit time or open-session status, duration, and methods.
- Empty, loading, error, and additional-results states.
- Default view covers the most recent 30 days.

STU-04 — Access session detail
- Timeline of entry and exit.
- Access method for each direction.
- Kiosk or staff actor where applicable.
- Explain automatic checkout due to closing time or maximum stay.
- Do not fabricate a staff actor for automatic checkout.
- Open-session variant.

STU-05 — Account
- Read-only full name, account code, email, role.
- Face enrollment status.
- Change password.
- Logout.
- No unsupported edit-profile action.

STU-06 — Face enrollment overview
- Variants: not enrolled, enrolled, current consent required, enrollment temporarily unavailable.
- Explain that QR remains available.
- Actions: “Đăng ký khuôn mặt”, “Đăng ký lại”, and “Xóa dữ liệu khuôn mặt”, as applicable.
- Display enrollment time, sample count, and policy version when available.
- Do not display stored face photos or embeddings.

STU-07 — Biometric consent
- Readable policy notice.
- Purpose of processing, handling of temporary capture media, deletion option, and QR alternative.
- Current policy version.
- Explicit unchecked consent checkbox.
- “Đồng ý và tiếp tục”.
- “Sử dụng mã QR”.
- Consent is optional and never preselected.

STU-08 — Enrollment preparation / camera permission
- Explain adequate lighting, a single face, and unobstructed capture.
- Request camera access at the point of use.
- Camera permission denied and camera unavailable variants.
- Offer device-image selection as a supported alternative for enrollment.

STU-09 — Capture or select enrollment images
- Collect 3–5 images of the same student.
- Progress indicator, temporary thumbnails, remove and retake controls.
- Label the images as temporary capture previews.
- Continue only when the required image count is met.
- Supported formats: JPG/PNG, maximum 5 MB each.
- Useful guidance for blurry images and poor lighting.
- Avoid promising that client-side checks guarantee server acceptance.

STU-10 — Enrollment processing and result
- Processing state that prevents duplicate submission.
- Success.
- No face, multiple faces, low-quality image, inconsistent faces, invalid file, oversized upload, AI unavailable, changed policy, and concurrent-update variants.
- Failed replacement preserves the previous valid enrollment; explain this clearly.
- Recovery action returns to capture or QR as appropriate.

STU-11 — Delete enrollment confirmation and result
- Explain that face data and consent will be removed.
- Entry/exit history remains.
- QR remains usable.
- Destructive confirmation, processing, success, and failure variants.

## 7. Librarian operational screens

LIB-01 — Live occupancy dashboard
- Main metric: current occupants / configured capacity.
- Near-capacity warning when applicable.
- Connection indicator and last updated timestamp.
- Preview of current occupants.
- Quick actions for manual recording and visitor registration.
- Optional compact personal shift summary.
- Do not invent analytics or kiosk-health metrics unavailable to librarians.
- Reconnection and stale-data variants.

LIB-02 — Current occupants
- Search by supported identity fields.
- Paginated list with name, student or visitor code, subject type, entry time, and elapsed stay.
- No emails or biometric data.
- Open-session detail and explicit manual-checkout action.
- Empty and stale-data variants.

LIB-03 — Manual entry/exit
- Choose student or external visitor.
- Student lookup uses the shared history/occupants information available to staff, not the administrator account directory.
- Permit entering a known student account code.
- Visitor picker uses the visitors directory.
- Explicit “Ghi nhận vào” / “Ghi nhận ra”.
- Required reason.
- Review target and action before submitting.
- Success result.
- Error variants for already inside, not inside, unavailable subject, closed library, full capacity, and uncertain request outcome.
- Preserve the same action during outcome recovery.

LIB-04 — External visitors directory and create dialog
- Search, pagination, visitor name, reference code, created time.
- “Thêm khách ngoài” asks only for full name.
- The reference code is generated by the system.
- No identity-document, phone, email, or address requirements.
- Duplicate names are possible; distinguish visitors by reference code.
- Creating a visitor does not automatically record entry.

LIB-05 — Visitor detail
- Read-only name, reference code, created time.
- Visitor access history and current presence derived from available records.
- Manual entry/exit shortcut.
- No visitor account or self-login.
- No edit/delete action.

LIB-06 — Shared access history and detail
- Search and supported filters: date range, subject type, method, and open/closed state.
- Paginated table.
- Detail drawer with entry/exit timeline, kiosk, staff actors, manual reasons, and automatic closure explanation.
- No editing records or export button.

LIB-07 — My shifts and detail
- List or calendar of the signed-in librarian’s assigned shifts.
- Shift name, start/end, and active/cancelled status.
- Overnight shifts clearly show both dates.
- Read-only detail.
- No staff clock-in, swap, leave, or self-assignment action.

LIB-08 — Library rules
- Read-only opening hours, capacity, and applicable stay rules.
- Explain that checkout remains possible outside opening hours.
- No editable controls.

Reuse these operational screens for administrators with the correct administrator shell and permissions.

## 8. Administrator screens

ADM-01 — Overview
- Current occupancy.
- Actual access analytics for a clearly labeled selected period.
- Compact kiosk summary based on available kiosk records.
- Quick links to accounts, shifts, and configuration.
- Avoid fabricated trends, comparison percentages, or “accuracy” claims.

ADM-02 — Accounts directory
- Search by code, name, or email.
- Role/status filters and pagination.
- Columns: account code, full name, email, role, status.
- Create, view, edit, lock/unlock, and password-reset actions.
- No delete or CSV import/export.

ADM-03 — Create account
- Full name, shared account code, email, role, initial password.
- Require password change at first login by default.
- Validation for duplicate code/email and invalid fields.
- Do not imply credentials are emailed.

ADM-04 — Account detail and edit
- View and edit supported fields.
- Explain that changing role/status may end active login sessions.
- Conflict state: “Dữ liệu đã được cập nhật. Vui lòng tải lại trước khi lưu.”
- Do not overwrite another administrator’s changes automatically.

ADM-05 — Lock/unlock confirmation
- Explain that locking prevents account use.
- Existing library presence is not automatically closed.
- Protect the last active administrator.
- Handle attempted role change for a student with an open visit.

ADM-06 — Reset password
- Administrator enters a new password.
- Requires first-login password change.
- Does not automatically unlock a locked account.
- Confirmation, validation, success, and concurrent-update states.
- No emailed-password claim.

ADM-07 — Kiosk directory
- Code, name, mode, administrative status, last seen, reported camera status, and app version.
- Distinguish “Đang hoạt động / Đã thu hồi” from connectivity inferred from last seen.
- Do not claim real-time connectivity from an old heartbeat.
- Create and detail actions.

ADM-08 — Create kiosk and one-time credential result
- Code, name, mode: “Chỉ vào”, “Chỉ ra”, “Tự động”.
- Credentials shown once after creation.
- Explicit copy action and guidance to save securely.
- No promise that the secret can be viewed again later.

ADM-09 — Kiosk detail and edit
- Edit name and mode.
- View last-seen and camera/app information.
- Revoke and rotate-credential actions.
- Revoked-device state.
- Reactivation requires new credentials rather than a simple status-only switch.

ADM-10 — Revoke / rotate credential dialogs
- Explain interruption of device access.
- One-time new credential result after rotation.
- Lost-response state instructs recovery through another rotation after refreshing current device data.

ADM-11 — Shift scheduling
- Week calendar plus list alternative.
- Previous/next week and “Hôm nay”.
- Active/cancelled status.
- “Tạo ca trực”.
- Clear shift blocks showing names, time ranges, and assignments.
- Do not require dragging shifts; form-based actions must work independently.
- If an employee-row view is included, build it from actual assignment data.

ADM-12 — Create/edit shift
- Shift name, start date/time, end date/time.
- End must follow start; maximum duration 24 hours.
- Overnight shifts supported.
- Editing a shift affects all assigned staff.
- Handle overlap and concurrent-update errors.

ADM-13 — Shift detail and assignments
- Shift information and assigned staff.
- Add one or more active librarians.
- Replace an assigned staff member.
- Remove assignment through confirmation.
- Explain overlapping shift errors.
- Adjacent shifts are allowed.
- Do not offer students or administrators as assignable staff.
- No artificial staffing minimum.

ADM-14 — Cancel shift
- Required cancellation reason.
- Explain the effect on assignments.
- Cancelled shifts are read-only and cannot be reopened.
- Clearly distinguish cancelling a shift from removing one assignment.

ADM-15 — Access analytics
- Date range and day/hour grouping.
- Total entries, total exits, average completed stay.
- Entry/exit chart and entry-method breakdown.
- Hour grouping supports at most 31 days; overall date range at most 366 days.
- Empty metrics use “Chưa có dữ liệu”, not fabricated zero averages.
- No export action.

ADM-16 — Recognition analytics
- Total actual recognition attempts, matched attempts, failed attempts, failure rate, and P50/P95 processing time.
- Outcome breakdown.
- Explicitly distinguish an identity match from successful entry/exit.
- Do not label match rate as AI accuracy.
- No stored face previews, embeddings, or per-attempt browsing unsupported by the API.

ADM-17 — Operational configuration
- Opening hours per weekday; allow closed days and overnight slots.
- Capacity.
- Near-capacity warning percentage.
- Capacity-enforcement toggle.
- Optional maximum stay duration.
- Scan cooldown.
- Vietnam timezone displayed read-only.
- Group settings into understandable cards.
- Save, validation, confirmation where appropriate, and concurrent-update states.
- Explain that opening-hour and maximum-stay changes apply to future entries.

ADM-18 — Advanced recognition configuration
- Separate advanced section within configuration.
- Model version, maximum cosine distance, minimum distance gap, and minimum liveness score.
- Plain-language helper text.
- Empty values mean recognition is not configured; do not insert “verified” thresholds.
- Explain calibration is required before using face recognition.
- No model-upload, deployment, or training interface.
- No biometric policy editor.

## 9. Kiosk screens and states

KSK-01 — Device provisioning
- Device ID and credential inputs.
- Connect action.
- Invalid credential, revoked device, and network error states.
- Mask credentials.
- Separate this from public scanning.

KSK-02 — Ready / idle
- Library name, kiosk name, current time, and gate mode.
- Large camera area.
- Instruction: “Đưa khuôn mặt vào khung để ghi nhận ra vào”.
- Visible fallback: “Sử dụng mã QR”.
- ENTRY/EXIT variants say “ghi nhận vào” / “ghi nhận ra”.
- AUTO mode determines direction from the current session.

KSK-03 — Face positioning
- Face guide, clear single-person instruction.
- Low-light, no-face, and multiple-face guidance.
- Avoid unnecessary personal information.

KSK-04 — Liveness challenge
- Show the ordered challenge returned for this attempt.
- Vietnamese instructions for blinking, turning left, or turning right.
- Short progress indicator.
- Capture is a short 1–3 second clip, not a static image.
- Challenge-expired variant starts a new challenge.

KSK-05 — Processing
- Clear “Đang xác thực, vui lòng chờ”.
- Prevent repeat scanning while the same action is pending.

KSK-06 — Successful entry
- “Ghi nhận vào thành công”.
- Name, account/reference code, and timestamp.
- Clear success icon.
- Briefly show the result, then clear identity information and return to idle.

KSK-07 — Successful exit
- “Ghi nhận ra thành công”.
- Same structure as successful entry.
- Do not show another person’s history.

KSK-08 — Recognition unsuccessful
- Distinct guidance for no match, low-quality capture, and failed liveness.
- Retry and QR actions.
- Recommend QR after two consecutive face failures.
- Do not claim to know whether an unmatched face is enrolled.

KSK-09 — QR scanner
- Camera scan frame and short instructions.
- Back to face scanning when available.
- Invalid, expired, or already-used QR variants.
- Explain that the student should generate a new QR on their own device.

KSK-10 — Face unavailable / camera unavailable
- AI unavailable: immediately recommend QR.
- Local camera unavailable: explain that camera-based QR scanning is also unavailable and direct the person to a librarian.
- Face not configured: offer QR when the camera works.
- Do not imply QR requires the AI service.

KSK-11 — Business-rule result
- Separate variants:
  - Library closed for entry.
  - Capacity reached when enforcement is enabled.
  - Scanned too soon.
  - Already inside at an entry-only gate.
  - Not inside at an exit-only gate.
  - Ineligible or locked account.
- Clear next action without exposing internal codes.
- Checkout remains possible outside opening hours.

KSK-12 — Network interruption / unknown outcome
- “Đang kiểm tra kết quả ghi nhận”.
- Recover the pending result before starting a new access action.
- Do not show “Thất bại” merely because the response was lost.
- No offline-success claim or invented offline queue.
- Separate terminal unavailable state with librarian guidance.

## 10. Components and interaction states

Create reusable components:
- Desktop shell and mobile bottom navigation.
- Buttons and icon buttons.
- Text/password inputs.
- Select and multi-select.
- Date/date-range/time pickers.
- Search and filters.
- Tables, pagination, and mobile list cards.
- Status badges.
- Inline alerts, banners, and toasts.
- Dialogs, drawers, and bottom sheets.
- Skeleton loaders.
- Empty and retry states.
- Camera guide.
- QR card and countdown.
- Occupancy indicator.
- Shift calendar blocks.

For relevant screens, include:
- Default.
- Hover, focus, pressed, and disabled.
- Loading.
- Empty dataset.
- No search results.
- Inline validation.
- Server failure.
- Unauthorized/session expired.
- Network loss.
- Stale data.
- Concurrent-update conflict.
- Success feedback.

On occupancy reconnect, display stale data honestly and refresh before marking it current.

Access recording must not duplicate an action during retry or uncertain response recovery. Express this through interaction states and developer annotations, not technical explanations in normal UI.

Use destructive confirmation for face deletion, account locking, kiosk revocation, shift cancellation, and assignment removal.

Do not add confirmation dialogs to every routine action.

## 11. Prototype journeys

Connect these journeys:
1. Login → required password change → correct role Home.
2. Student Home → QR → expired code → generate new code.
3. Student Account → consent → enrollment capture → success.
4. Enrollment replacement fails → previous enrollment remains.
5. Student deletes face data → QR remains available.
6. Kiosk idle → liveness → successful entry → idle.
7. Kiosk face failure → QR → successful exit → idle.
8. AI unavailable → QR fallback.
9. Lost access response → check pending result → show confirmed result.
10. Librarian adds visitor → explicitly records entry → visitor appears in occupants.
11. Librarian manually checks a person out → history detail.
12. Administrator creates account → first-login password change.
13. Administrator creates kiosk → one-time credential → provisioning.
14. Administrator creates shift → assigns librarians → handles overlap.
15. Administrator edits configuration → handles concurrent update.
16. Administrator views both analytics pages with populated and empty data.

## 12. Deliverable organization and quality checks

Organize the design into:
- Foundations.
- Shared components.
- Authentication.
- Student.
- Librarian.
- Administrator.
- Kiosk.
- Error and recovery states.
- Prototype flows.

Use the screen IDs above as frame names followed by Vietnamese screen titles.

Use editable text, reusable components, consistent spacing, and Auto Layout where supported.

Use realistic Vietnamese sample names and clearly fictional example emails. Do not use Lorem ipsum. Keep all sample records and metrics consistent across related screens.

Represent dialogs and state variants separately when they matter; do not replace the complete inventory with only a dashboard and login screen.

Before finishing:
- Check every listed screen and critical state is represented.
- Check all visible text is Vietnamese with correct diacritics.
- Check font coverage, wrapping, and accent clipping.
- Check long names and labels.
- Check role permissions.
- Check touch target sizes and readable contrast.
- Check success is never shown before an operation is confirmed.
- Check the design does not introduce unsupported features.
- Check face recognition, QR fallback, visitors, and staff scheduling all have complete flows.

If generation requires multiple passes, retain this full brief and the same design tokens. Continue through every screen group without silently dropping scope.