# Admin Dashboard Integration

This file is for the AI agent that will build the Angular admin dashboard for the TT Mail Assistant project.

## Backend Base

Use the backend API, not the `ai-email-agent` service directly.

- Backend base URL: `http://localhost:8000`
- API prefix: `/api/v1`
- Admin prefix: `/api/v1/admin`
- Planning admin prefix: `/api/v1/admin/planning`

All admin requests must include:

```http
Authorization: Bearer <backend_session_token>
```

## Login And Admin Roles

The app uses Microsoft/Outlook auth.

1. Angular must run Microsoft OAuth and obtain a Microsoft `access_token`.
2. Send the token to:

```http
POST /api/v1/auth/microsoft
```

Body:

```json
{
  "access_token": "<microsoft_access_token>",
  "id_token": "<optional_id_token>",
  "refresh_token": "<optional_refresh_token>",
  "expires_at": "2026-09-11T12:00:00Z"
}
```

The response returns `session_token`. Store it securely and use it as the Bearer token.

Admin access is controlled in the backend database table `users`:

- `role = "admin"`: full admin access, user management, audit logs.
- `role = "reviewer"`: planning editor/reviewer access.
- `role = "viewer"`: read-only admin dashboard access.
- `role = "user"`: normal mobile user, no dashboard access.
- `is_active = true`: user can access the app.

To bootstrap the first admin, either configure the backend env var:

```env
ADMIN_EMAILS=admin@tunisietelecom.tn
```

or update the DB after the user signs in once:

```sql
UPDATE users
SET role = 'admin', is_active = true
WHERE email = 'admin@tunisietelecom.tn';
```

Use `POST /api/v1/auth/refresh` or `GET /api/v1/auth/me` to validate an existing session.

## Core Admin APIs

Use these for dashboard shell and access control:

- `GET /api/v1/admin/me`
- `GET /api/v1/admin/overview`
- `GET /api/v1/admin/users?search=&limit=&offset=`
- `PATCH /api/v1/admin/users/{user_id}/role`
- `PATCH /api/v1/admin/users/{user_id}/active`
- `GET /api/v1/admin/audit-logs`
- `GET /api/v1/admin/audit-logs/{log_id}`

Audit log filters:

- `actor_email`
- `action`
- `resource_type`
- `resource_id`
- `status`
- `search`
- `date_from`
- `date_to`
- `limit`
- `offset`

## Planning Import APIs

Planning files are Excel uploads. The backend proxies them to the AI planning service.

- `POST /api/v1/admin/planning/imports/preview`
- `POST /api/v1/admin/planning/imports`
- `GET /api/v1/admin/planning/imports`
- `GET /api/v1/admin/planning/imports/{import_id}`

Use `multipart/form-data` with field name `files`.

## Sessions APIs

Use this for calendar, list, detail and filters:

- `GET /api/v1/admin/planning/sessions`
- `GET /api/v1/admin/planning/sessions/{session_key}?import_id=`

Important filters:

- `import_id`
- `year`
- `month`
- `date_from`
- `date_to`
- `status`
- `domain`
- `training_mode`
- `training_type`
- `cabinet`
- `location`
- `responsible`
- `search`
- `has_participants`
- `missing_contacts`
- `sort_by`
- `sort_direction`
- `limit`
- `offset`

## Responsables Directory APIs

This directory contains RH and DIR C/R contacts used as recipients for training emails.

- `POST /api/v1/admin/planning/responsables/import`
- `GET /api/v1/admin/planning/responsables`
- `POST /api/v1/admin/planning/responsables`
- `GET /api/v1/admin/planning/responsables/{contact_key}`
- `DELETE /api/v1/admin/planning/responsables/{contact_key}`

Useful filters:

- `search`
- `role`
- `residence`
- `direction`
- `has_email`
- `duplicate_emails`
- `source_file`
- `limit`
- `offset`

Save responsable body:

```json
{
  "role": "rh",
  "residence": "DIRECTION REGIONALE GABES",
  "email": "resp.rh@tunisietelecom.tn",
  "full_name": "Responsable RH Gabes",
  "direction": "Gabes",
  "hr_responsible": ""
}
```

## Contact Matching APIs

Use this area to show missing contacts and manual matching:

- `GET /api/v1/admin/planning/missing-contacts`
- `GET /api/v1/admin/planning/contact-review`
- `GET /api/v1/admin/planning/contacts`
- `POST /api/v1/admin/planning/contacts`
- `POST /api/v1/admin/planning/contacts/import`
- `POST /api/v1/admin/planning/contacts/apply`

## Draft Review APIs

Use these for the review queue and email approval workflow:

- `GET /api/v1/admin/planning/drafts`
- `GET /api/v1/admin/planning/drafts/review`
- `GET /api/v1/admin/planning/drafts/{draft_id}`
- `PATCH /api/v1/admin/planning/drafts/{draft_id}`
- `POST /api/v1/admin/planning/drafts/{draft_id}/regenerate`
- `POST /api/v1/admin/planning/drafts/{draft_id}/approve`
- `POST /api/v1/admin/planning/drafts/{draft_id}/reject`
- `POST /api/v1/admin/planning/drafts/{draft_id}/send`
- `POST /api/v1/admin/planning/drafts/bulk-action`
- `POST /api/v1/admin/planning/drafts/bulk-send`
- `GET /api/v1/admin/planning/send-history`

Bulk action body:

```json
{
  "draft_ids": [1, 2, 3],
  "action": "approve",
  "reason": "",
  "email_type": "auto",
  "include_population": true
}
```

Bulk send body:

```json
{
  "draft_ids": [1, 2, 3],
  "confirmed": true,
  "confirmed_draft_count": 3,
  "confirmed_total_recipient_count": 3
}
```

Only approved drafts can be sent. The UI must show a confirmation dialog before calling send.

## Automation APIs

Use these for background-like generation controls and history:

- `GET /api/v1/admin/planning/automation/settings`
- `PATCH /api/v1/admin/planning/automation/settings`
- `POST /api/v1/admin/planning/automation/run`
- `GET /api/v1/admin/planning/automation/jobs`
- `GET /api/v1/admin/planning/automation/jobs/{job_id}`
- `GET /api/v1/admin/planning/automation/jobs/{job_id}/logs`

Automation run body:

```json
{
  "import_id": "<import_id>",
  "email_type": "auto",
  "include_population": true,
  "limit": 100,
  "replace_existing": false
}
```

The backend injects `requested_by` from the connected admin user.

## Database Notes

The Angular app should never connect directly to PostgreSQL.

Angular must talk only to the backend APIs. The backend connects to the DB through `DATABASE_URL`.

Important backend DB tables:

- `users`: auth users, roles, active state.
- `auth_sessions`: backend Bearer sessions.
- `audit_logs`: admin action history.
- email workflow tables: `emails`, `email_responses`, `email_analyses`, `jury_verdicts`.

Planning data is currently stored by `ai-email-agent` in its planning DB through the planning service. The admin backend proxies planning endpoints to `AGENT1_URL`.

## Angular Pages To Build

1. Login page
   - Microsoft login button.
   - Redirect authenticated admins to the dashboard.

2. Admin layout
   - Sidebar or mobile-friendly bottom navigation.
   - Header with current admin identity and logout.

3. Dashboard overview
   - Use `GET /api/v1/admin/overview`.
   - Show users, email workflow, notifications and training counters.

4. Planning imports
   - Upload planning Excel files.
   - Preview before saving.
   - Show import history and diagnostics.

5. Training sessions
   - Calendar/list view.
   - Year/month filters.
   - Strong filters and pagination.
   - Session detail with participants.

6. Responsables directory
   - Import responsible directory files.
   - Search/filter RH and DIR C/R contacts.
   - Create, update and delete responsible contacts.
   - Put contacts with valid emails first.

7. Contact matching review
   - Show missing contacts and review-needed rows.
   - Manual contact save and apply mapping.

8. Draft review queue
   - Show original session, recipients, subject, body and HTML preview.
   - Edit draft.
   - Approve, reject, regenerate.
   - Bulk approve/reject/regenerate.

9. Send center
   - Show approved drafts ready to send.
   - Require safety confirmation before send.
   - Bulk send approved drafts.
   - Show send history and errors.

10. Automation center
    - Edit automation settings.
    - Run automation manually.
    - Show automation jobs and logs.

11. User management
    - Admin-only.
    - List users.
    - Change roles.
    - Enable/disable users.

12. Audit log
    - Admin-only.
    - Search/filter actions.
    - Detail drawer/page with metadata.

## UI Guidance

Build the dashboard for normal business users, not developers.

- Prefer clear French labels.
- Avoid exposing terms like `AGENT1_URL`, `job_type`, or raw JSON in primary screens.
- Use raw technical details only inside advanced drawers or diagnostics pages.
- Always show loading, empty and error states.
- Never send emails without an explicit confirmation step.
