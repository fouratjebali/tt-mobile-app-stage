# Admin Dashboard Integration

This file is for the AI agent that will build the Angular admin dashboard for the TT Mail Assistant project.

Angular must call the backend API only. Do not connect Angular directly to PostgreSQL and do not call `ai-email-agent` directly.

## Backend Base

- Backend base URL: `http://localhost:8000`
- API prefix: `/api/v1`
- Admin prefix: `/api/v1/admin`
- Planning admin prefix: `/api/v1/admin/planning`

Every authenticated admin request must include:

```http
Authorization: Bearer <backend_session_token>
```

Common response rules:

- Backend admin endpoints return typed JSON.
- Planning endpoints are proxied by the backend to the planning service, so some payloads can include extra fields. Angular should read the stable fields listed below and tolerate additional fields.
- Most list endpoints support `limit` and `offset`; keep these in component state for pagination.
- Show friendly errors from `detail` when the backend returns `4xx` or `5xx`.

## Roles

- `admin`: full dashboard access, users, audit logs, settings.
- `reviewer`: planning editor/reviewer access.
- `viewer`: read-only dashboard access.
- `user`: normal mobile user, no admin dashboard access.

For Angular route guards:

- Admin-only pages: users, audit logs, dashboard policies.
- Admin/reviewer pages: planning imports, sessions, responsables, drafts, automation.
- Viewer pages: overview, planning lists, read-only details.

## Preset Admin Credentials

The dashboard login uses preset credentials stored in the backend database. Set these in `backend/.env` before starting the backend:

```env
ADMIN_DASHBOARD_USERNAME=admin
ADMIN_DASHBOARD_PASSWORD=change-this-password
ADMIN_DASHBOARD_EMAIL=dashboard.admin@tunisietelecom.tn
ADMIN_DASHBOARD_DISPLAY_NAME=Dashboard Admin
```

The backend seeds or updates the admin credential row on startup. The password is hashed in the DB. Never display the password in Angular.

## Auth APIs

### POST `/api/v1/auth/admin/login`

Use it on the Angular login page.

Request:

```json
{
  "username": "admin",
  "password": "change-this-password"
}
```

Expected output:

```json
{
  "session_token": "backend-session-token",
  "token_type": "Bearer",
  "expires_at": null,
  "user": {
    "id": "user-id",
    "email": "dashboard.admin@tunisietelecom.tn",
    "display_name": "Dashboard Admin",
    "photo_url": null,
    "role": "admin",
    "is_active": true
  }
}
```

Frontend usage:

- Store `session_token` securely.
- Send it as `Authorization: Bearer <token>`.
- Redirect to dashboard if `user.role` is `admin`, `reviewer`, or `viewer`.
- Block access if `is_active` is false.

### GET `/api/v1/auth/me`

Use it when the Angular app starts to restore the session.

Expected output:

```json
{
  "id": "user-id",
  "email": "dashboard.admin@tunisietelecom.tn",
  "display_name": "Dashboard Admin",
  "photo_url": null,
  "role": "admin",
  "is_active": true
}
```

Frontend usage:

- Validate the saved token.
- Fill the current user store.
- Apply route guards from `role`.

### GET `/api/v1/auth/session`

Same output as `/auth/me`. Use it if you want a semantic validate-session call.

### POST `/api/v1/auth/refresh`

Current behavior validates the session and returns the current user.

Expected output is the same user object as `/auth/me`.

Frontend usage:

- Call before important operations if the user was idle.
- If it returns `401`, clear the token and go to login.

### POST `/api/v1/auth/logout`

Use it from the dashboard logout button.

Expected output:

- HTTP `204 No Content`.

Frontend usage:

- Call endpoint.
- Clear local token and user state.
- Redirect to login.

### POST `/api/v1/auth/microsoft`

Mobile app only. Do not use as the main admin dashboard login unless SSO is requested later.

## Core Admin APIs

### GET `/api/v1/admin/me`

Use it to validate dashboard access specifically.

Expected output:

```json
{
  "id": "user-id",
  "email": "dashboard.admin@tunisietelecom.tn",
  "display_name": "Dashboard Admin",
  "photo_url": null,
  "role": "admin",
  "is_active": true,
  "created_at": "2026-09-13T10:00:00",
  "updated_at": "2026-09-13T10:00:00"
}
```

Frontend usage:

- Prefer this endpoint for admin layout bootstrap.
- If it returns `403`, show "You do not have admin dashboard access".

### GET `/api/v1/admin/overview`

Use it for the dashboard home page.

Expected output:

```json
{
  "generated_at": "2026-09-13T10:00:00Z",
  "users": {
    "total": 3,
    "active": 3,
    "inactive": 0,
    "admins": 1,
    "reviewers": 1,
    "viewers": 0,
    "regular_users": 1
  },
  "email": {
    "total": 0,
    "unread": 0,
    "awaiting_review": 0,
    "urgent": 0,
    "analysed": 0,
    "pending": 0,
    "ignored": 0,
    "sent_replies": 0,
    "received_today": 0,
    "received_last_7_days": 0
  },
  "notifications": {
    "total": 0,
    "unread": 0
  },
  "training": {
    "available": true,
    "source": "planning-service",
    "message": null,
    "total_sessions": 735,
    "total_participants": 378,
    "drafts_waiting_review": 31,
    "missing_responsibles": 0,
    "sent_drafts": 0
  },
  "system": {
    "api_prefix": "/api/v1",
    "admin_api_prefix": "/admin",
    "admin_base_path": "/api/v1/admin"
  }
}
```

Frontend usage:

- Cards: users, sessions, participants, drafts waiting review, missing responsables.
- If `training.available` is false, show a degraded planning-service warning.

### GET `/api/v1/admin/health`

Use it for a diagnostics/health page.

Expected output:

```json
{
  "status": "healthy",
  "checked_at": "2026-09-13T10:00:00Z",
  "latency_ms": 42,
  "services": [
    {
      "name": "Backend API",
      "status": "healthy",
      "message": "Operational"
    },
    {
      "name": "Database",
      "status": "healthy",
      "message": "Connected"
    },
    {
      "name": "Mail connector",
      "status": "healthy",
      "message": "Operational"
    },
    {
      "name": "Audit stream",
      "status": "healthy",
      "message": "Writing events"
    }
  ]
}
```

Frontend usage:

- Display each service as healthy/degraded/down.
- Refresh manually with a button.

## Admin Settings APIs

### GET `/api/v1/admin/settings`

Use it if you only need dashboard policy settings.

Expected output:

```json
{
  "status": "ok",
  "settings": {
    "review_threshold": 40,
    "audit_retention_days": 180,
    "support_email": "dashboard.admin@tunisietelecom.tn"
  }
}
```

Frontend usage:

- Populate simple settings form.
- Use `review_threshold` to show warnings when review queues are too large.

### PATCH `/api/v1/admin/settings`

Admin-only. Updates dashboard policy settings.

Request:

```json
{
  "review_threshold": 50,
  "audit_retention_days": 180,
  "support_email": "support@tunisietelecom.tn"
}
```

Expected output:

```json
{
  "status": "ok",
  "settings": {
    "review_threshold": 50,
    "audit_retention_days": 180,
    "support_email": "support@tunisietelecom.tn"
  }
}
```

Frontend usage:

- Save dashboard policy form.
- Ignore unsupported keys; backend only keeps allowed settings.

### PATCH `/api/v1/admin/settings/policies`

Same behavior as `PATCH /settings`, but clearer for the Angular settings page.

Frontend usage:

- Prefer this endpoint for the Settings page.

### GET `/api/v1/admin/settings/system`

Use it for read-only operational settings. It does not expose passwords or database URLs.

Expected output:

```json
{
  "status": "ok",
  "settings": {
    "application": {
      "name": "TT Mail Assistant Backend",
      "version": "0.1.0"
    },
    "backend": {
      "api_prefix": "/api/v1",
      "admin_api_prefix": "/admin",
      "admin_base_path": "/api/v1/admin",
      "cors_origins": ["http://localhost:4200"]
    },
    "database": {
      "configured": true,
      "driver": "postgresql+psycopg"
    },
    "mail_connector": {
      "agent1_configured": true,
      "agent2_configured": true,
      "outlook_client_configured": true,
      "agent1_endpoint": "http://agent1:8001"
    },
    "email_pipeline": {
      "enabled": true,
      "interval_seconds": 60,
      "max_emails": 10
    },
    "admin_credentials": {
      "preset_username_configured": true,
      "preset_password_configured": true,
      "admin_email_configured": true,
      "display_name": "Dashboard Admin"
    }
  }
}
```

Frontend usage:

- Show read-only diagnostic cards.
- Do not create edit inputs for this response.

### GET `/api/v1/admin/settings/supervision`

Use it as the main Settings page bootstrap endpoint.

Expected output:

```json
{
  "status": "ok",
  "generated_at": "2026-09-13T10:00:00Z",
  "settings": {
    "dashboard_policy": {
      "review_threshold": 40,
      "audit_retention_days": 180,
      "support_email": "dashboard.admin@tunisietelecom.tn"
    },
    "planning_automation": {
      "available": true,
      "settings": {
        "auto_run_after_import": true,
        "default_email_type": "auto",
        "include_population": true,
        "max_drafts_per_run": 100
      },
      "error": null
    },
    "system": {
      "application": {},
      "backend": {},
      "database": {},
      "mail_connector": {},
      "email_pipeline": {},
      "admin_credentials": {}
    }
  },
  "sections": [
    {
      "key": "dashboard_policy",
      "title": "Dashboard policy",
      "editable": true,
      "endpoint": "/api/v1/admin/settings/policies",
      "settings": {},
      "controls": []
    }
  ]
}
```

Frontend usage:

- Use `sections` to render the settings page.
- If `planning_automation.available` is false, disable automation inputs and show `error`.
- Use each section `endpoint` for save actions.

## Usage And Admin Management APIs

### GET `/api/v1/admin/usage/overview?date_from=&date_to=&admin_id=`

Use it for the Admin Usage page analytics cards.

Expected output:

```json
{
  "total_actions": 124,
  "login_count": 12,
  "create_count": 20,
  "update_count": 35,
  "delete_count": 4,
  "health_check_count": 18,
  "failed_actions": 3,
  "active_admins": 2,
  "most_active_admin": {
    "id": "uuid",
    "email": "admin@tunisietelecom.tn",
    "display_name": "Dashboard Admin",
    "actions": 80
  }
}
```

Frontend usage:

- Render cards for actions, logins, creates, updates, deletes, failed actions, active admins.
- Use `admin_id` to filter the cards for one dashboard admin.
- Use ISO date strings for `date_from` and `date_to`.

### GET `/api/v1/admin/usage/actions?admin_id=&action=&resource_type=&status=&date_from=&date_to=&limit=20&offset=0`

Use it for the usage trace table.

Expected output:

```json
{
  "items": [
    {
      "id": "log-id",
      "actor_user_id": "admin-id",
      "actor_email": "admin@tunisietelecom.tn",
      "actor_role": "super_admin",
      "action": "admin.planning.responsable.delete",
      "resource_type": "responsable",
      "resource_id": "123",
      "status": "success",
      "summary": "Deleted responsable",
      "metadata": {
        "before": {},
        "after": null,
        "changed_fields": []
      },
      "ip_address": "127.0.0.1",
      "user_agent": "Mozilla/5.0",
      "request_method": "DELETE",
      "request_path": "/api/v1/admin/planning/responsables/123",
      "created_at": "2026-09-13T10:00:00"
    }
  ],
  "total": 124,
  "limit": 20,
  "offset": 0
}
```

Frontend usage:

- Render a paginated trace table.
- Filters should include admin, action, resource type, status and date range.
- Show `summary` in the table and open full metadata in a detail drawer.

### GET `/api/v1/admin/usage/actions/{log_id}`

Use it for the trace detail drawer.

Expected output:

```json
{
  "status": "ok",
  "item": {
    "id": "log-id",
    "metadata": {
      "before": {},
      "after": {},
      "changed_fields": ["nom_complet"]
    }
  }
}
```

Frontend usage:

- Show full metadata/diff.
- Do not show passwords, tokens, authorization headers or secret env values.

### GET `/api/v1/admin/usage/admins?search=&role=&limit=20&offset=0`

Use it for an admin selector and usage ranking.

Expected output:

```json
{
  "items": [
    {
      "id": "uuid",
      "email": "admin@tunisietelecom.tn",
      "username": "admin",
      "display_name": "Dashboard Admin",
      "role": "super_admin",
      "is_active": true,
      "last_login_at": "2026-09-13T10:00:00",
      "actions_count": 80
    }
  ],
  "total": 2,
  "limit": 20,
  "offset": 0
}
```

Frontend usage:

- List dashboard admins only.
- Use `role=super_admin` or `role=admin` to filter.
- Show `actions_count` as usage intensity.

### GET `/api/v1/admin/usage/admins/{admin_id}/overview?date_from=&date_to=`

Use it for a per-admin usage detail page.

Expected output:

```json
{
  "total_actions": 80,
  "login_count": 8,
  "create_count": 12,
  "update_count": 20,
  "delete_count": 2,
  "health_check_count": 6,
  "failed_actions": 1,
  "active_admins": 2,
  "most_active_admin": {},
  "admin": {
    "id": "uuid",
    "username": "admin",
    "email": "admin@tunisietelecom.tn",
    "role": "super_admin"
  }
}
```

Frontend usage:

- Reuse the same cards from usage overview.
- Add admin identity header.

### GET `/api/v1/admin/admins?search=&role=&limit=20&offset=0`

Super admin only. Use it for the Admin Management page.

Expected output is the same shape as `/usage/admins`.

Frontend usage:

- Table of dashboard admin credentials.
- Never expect or display password hashes.

### POST `/api/v1/admin/admins`

Super admin only. Creates a dashboard admin.

Request:

```json
{
  "username": "admin2",
  "password": "strong-password",
  "email": "admin2@tunisietelecom.tn",
  "display_name": "Second Admin",
  "role": "admin",
  "is_active": true
}
```

Expected output:

```json
{
  "id": "uuid",
  "email": "admin2@tunisietelecom.tn",
  "username": "admin2",
  "display_name": "Second Admin",
  "role": "admin",
  "is_active": true,
  "last_login_at": null,
  "actions_count": 0
}
```

Frontend usage:

- Valid roles: `super_admin`, `admin`.
- Require a strong password in the form.
- Do not store the password after submit.

### GET `/api/v1/admin/admins/{admin_id}`

Super admin only. Returns one dashboard admin.

Frontend usage:

- Detail drawer/page.

### PATCH `/api/v1/admin/admins/{admin_id}`

Super admin only. Updates username, email, display name, role, or active state.

Request:

```json
{
  "username": "admin2",
  "email": "admin2@tunisietelecom.tn",
  "display_name": "Second Admin",
  "role": "admin",
  "is_active": true
}
```

Frontend usage:

- Send only fields that changed or send the full editable form.
- Backend prevents deactivating/demoting the last active `super_admin`.

### PATCH `/api/v1/admin/admins/{admin_id}/active`

Super admin only.

Request:

```json
{
  "is_active": false
}
```

Frontend usage:

- Use for enable/disable toggles.
- Require confirmation before disabling.
- Backend prevents disabling the last active `super_admin`.

### PATCH `/api/v1/admin/admins/{admin_id}/password`

Super admin only.

Request:

```json
{
  "password": "new-strong-password"
}
```

Frontend usage:

- Use a dedicated reset password modal.
- Never display or store password hashes.

## Users APIs

### GET `/api/v1/admin/users?search=&limit=100&offset=0`

Admin-only. Use it for user management.

Expected output:

```json
{
  "users": [
    {
      "id": "user-id",
      "email": "user@tunisietelecom.tn",
      "display_name": "User Name",
      "photo_url": null,
      "role": "reviewer",
      "is_active": true,
      "created_at": "2026-09-13T10:00:00",
      "updated_at": "2026-09-13T10:00:00"
    }
  ],
  "total": 1,
  "limit": 100,
  "offset": 0
}
```

Frontend usage:

- Table with search, role badge, active toggle.
- Use pagination from `total`, `limit`, `offset`.

### PATCH `/api/v1/admin/users/{user_id}/role`

Admin-only.

Request:

```json
{
  "role": "reviewer"
}
```

Expected output: updated user object.

Frontend usage:

- Use a role select.
- Supported roles: `admin`, `reviewer`, `viewer`, `user`.
- Backend blocks an admin from removing their own admin role.

### PATCH `/api/v1/admin/users/{user_id}/active`

Admin-only.

Request:

```json
{
  "is_active": false
}
```

Expected output: updated user object.

Frontend usage:

- Use an enable/disable toggle.
- Backend blocks an admin from disabling their own account.

## Audit Log APIs

### GET `/api/v1/admin/audit-logs`

Admin-only. Use it for compliance and troubleshooting.

Supported filters:

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

Expected output:

```json
{
  "logs": [
    {
      "id": "log-id",
      "actor_user_id": "user-id",
      "actor_email": "admin@tunisietelecom.tn",
      "actor_role": "admin",
      "action": "admin.planning.import.create",
      "resource_type": "planning",
      "resource_id": "import-id",
      "status": "success",
      "metadata": {},
      "created_at": "2026-09-13T10:00:00"
    }
  ],
  "total": 1,
  "limit": 100,
  "offset": 0
}
```

Frontend usage:

- Filterable table.
- Detail drawer opens `/audit-logs/{log_id}`.

### GET `/api/v1/admin/audit-logs/{log_id}`

Expected output: one audit log object.

Frontend usage:

- Show metadata in an advanced panel.
- Keep raw JSON only inside the detail view.

## Planning Analytics APIs

### GET `/api/v1/admin/planning/analytics/overview?date_from=&date_to=`

Use it for planning dashboard statistics.

Expected output:

```json
{
  "status": "ok",
  "totals": {
    "imports": 2,
    "files": 3,
    "sessions": 735,
    "participants": 378,
    "drafts": 31,
    "sent": 0
  },
  "drafts": {
    "waiting_review": 31,
    "approved": 0,
    "sent": 0,
    "rejected": 0
  },
  "admin_usage": {
    "imports_created": 2,
    "drafts_generated": 31,
    "drafts_reviewed": 0,
    "drafts_sent": 0
  }
}
```

Frontend usage:

- Top analytics cards.
- Use date filters for reporting.

### GET `/api/v1/admin/planning/analytics/files?date_from=&date_to=&limit=20`

Use it to show how many Excel/CSV files were treated.

Expected output:

```json
{
  "status": "ok",
  "summary": {
    "treated_files": 3,
    "successful_files": 3,
    "failed_files": 0
  },
  "files": [
    {
      "filename": "sessions.xlsx",
      "status": "IMPORTED",
      "imported_at": "2026-09-13T10:00:00"
    }
  ]
}
```

Frontend usage:

- File treatment history and import quality cards.

### GET `/api/v1/admin/planning/analytics/drafts?date_from=&date_to=&limit=20`

Use it to show draft preparation statistics.

Expected output:

```json
{
  "status": "ok",
  "summary": {
    "total_drafts": 31,
    "waiting_review": 31,
    "approved": 0,
    "sent": 0
  },
  "by_status": [],
  "by_day": [],
  "recent_batches": []
}
```

Frontend usage:

- Charts for drafts generated by day/status.

### GET `/api/v1/admin/planning/analytics/users?date_from=&date_to=&limit=50&offset=0`

Use it to show dashboard activity per admin/reviewer.

Expected output:

```json
{
  "status": "ok",
  "users": [
    {
      "actor_email": "admin@tunisietelecom.tn",
      "imports_created": 2,
      "drafts_generated": 31,
      "drafts_reviewed": 0,
      "drafts_sent": 0,
      "last_activity_at": "2026-09-13T10:00:00"
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

Frontend usage:

- Admin activity table.
- Useful for drafts prepared per user and files treated per user.

## Planning Import APIs

### POST `/api/v1/admin/planning/imports/preview`

Use it before saving uploaded Excel files.

Request:

- `multipart/form-data`
- Field name: `files`
- Allow one or multiple `.xlsx`, `.xls`, or `.csv` files.

Expected output:

```json
{
  "status": "ok",
  "preview": {
    "files": [],
    "sessions_detected": 735,
    "participants_detected": 378,
    "warnings": []
  }
}
```

Frontend usage:

- Show detected sessions/participants before final import.
- Show warnings but do not save until user confirms.

### POST `/api/v1/admin/planning/imports`

Use it after preview confirmation.

Request:

- Same multipart body as preview.

Expected output:

```json
{
  "status": "ok",
  "import_id": "import-id",
  "files": [],
  "sessions_imported": 735,
  "participants_imported": 378,
  "warnings": []
}
```

Frontend usage:

- Navigate to import detail or sessions page after success.
- Trigger draft generation only after import is stored.

### GET `/api/v1/admin/planning/imports`

Expected output:

```json
{
  "status": "ok",
  "count": 1,
  "imports": [
    {
      "import_id": "import-id",
      "status": "IMPORTED",
      "created_at": "2026-09-13T10:00:00",
      "files": []
    }
  ]
}
```

Frontend usage:

- Import history list.

### GET `/api/v1/admin/planning/imports/{import_id}`

Expected output:

```json
{
  "status": "ok",
  "import": {},
  "files": [],
  "sessions": [],
  "diagnostics": []
}
```

Frontend usage:

- Import detail page with diagnostics and linked sessions.

## Sessions APIs

### GET `/api/v1/admin/planning/sessions`

Use it for calendar/list/table views.

Supported filters:

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

Expected output:

```json
{
  "status": "ok",
  "sessions": [
    {
      "session_key": "T-IRS91-01-2026",
      "code": "T-IRS91-01-2026",
      "title": "Formation reseau",
      "start_date": "2026-09-01",
      "end_date": "2026-09-02",
      "location": "Salle 1 DCSI pole El Ghazela",
      "cabinet": "Cabinet name",
      "responsible": "Formateur",
      "participant_count": 10,
      "status": "UPCOMING"
    }
  ],
  "total": 1,
  "limit": 100,
  "offset": 0
}
```

Frontend usage:

- Calendar month view.
- List/table with filters.
- Use `participant_count` on cards.

### GET `/api/v1/admin/planning/sessions/{session_key}?import_id=`

Expected output:

```json
{
  "status": "ok",
  "session": {
    "session_key": "T-IRS91-01-2026",
    "title": "Formation reseau",
    "start_date": "2026-09-01",
    "end_date": "2026-09-02",
    "location": "Salle 1 DCSI pole El Ghazela",
    "cabinet": "Cabinet name"
  },
  "participants": [
    {
      "matricule": "77291",
      "full_name": "BEN ELBEY Lobna",
      "grande_residence": "Direction Centrale des Services"
    }
  ],
  "drafts": []
}
```

Frontend usage:

- Session detail drawer/page.
- Show important info: dates, location, trainer/cabinet, participants and residences.

## Responsables And Contact APIs

### GET `/api/v1/admin/planning/responsables?search=&residence=&limit=20&offset=0`

Use it for the responsables directory page. This reads the backend `responsable` table.

Expected output:

```json
{
  "status": "ok",
  "responsables": [
    {
      "id": "id",
      "nom_complet": "Responsable Name",
      "fonction": "RESP RH",
      "grande_residence": "DIRECTION REGIONALE SFAX"
    }
  ],
  "total": 178,
  "limit": 20,
  "offset": 0
}
```

Frontend usage:

- Search bar, paginated list.
- Show count of responsables.
- No file import is needed for responsables in the mobile flow anymore.

### POST `/api/v1/admin/planning/responsables/import`

Legacy/admin import endpoint for responsables files.

Frontend usage:

- Hide this from normal users unless the admin dashboard needs maintenance tools.
- Request is multipart with field `files`.

### POST `/api/v1/admin/planning/responsables`

Creates one responsable in the backend `responsable` table.

Request:

```json
{
  "nom_complet": "Responsable RH Gabes",
  "fonction": "RESP RH",
  "grande_residence": "DIRECTION REGIONALE GABES"
}
```

Expected output:

```json
{
  "status": "ok",
  "responsable": {
    "id": "responsable-id",
    "nom_complet": "Responsable RH Gabes",
    "fonction": "RESP RH",
    "grande_residence": "DIRECTION REGIONALE GABES",
    "source_file": "manual",
    "source_sheet": "admin-dashboard",
    "source_row": 0,
    "created_at": "2026-09-13T10:00:00",
    "updated_at": "2026-09-13T10:00:00"
  }
}
```

Frontend usage:

- Use from the "Add responsable" form.
- If the backend returns `409`, show that the same responsable already exists.

### GET `/api/v1/admin/planning/responsables/{contact_key}`

Expected output:

```json
{
  "status": "ok",
  "responsable": {
    "id": "responsable-id",
    "nom_complet": "Responsable Name",
    "fonction": "RESP RH",
    "grande_residence": "DIRECTION REGIONALE SFAX"
  }
}
```

Frontend usage:

- Detail drawer for one responsable.
- Use `id` from the list as `{contact_key}`.

### PATCH `/api/v1/admin/planning/responsables/{contact_key}`

Updates one responsable in the backend `responsable` table.

Request:

```json
{
  "nom_complet": "Responsable RH Gabes",
  "fonction": "DIR C/R",
  "grande_residence": "DIRECTION REGIONALE GABES"
}
```

Expected output:

```json
{
  "status": "ok",
  "responsable": {
    "id": "responsable-id",
    "nom_complet": "Responsable RH Gabes",
    "fonction": "DIR C/R",
    "grande_residence": "DIRECTION REGIONALE GABES"
  }
}
```

Frontend usage:

- Use from the edit responsable form.
- Send the full editable object, not only changed fields.
- If the backend returns `409`, show a duplicate-responsable message.

### DELETE `/api/v1/admin/planning/responsables/{contact_key}`

Expected output:

```json
{
  "status": "ok",
  "deleted": true,
  "id": "responsable-id"
}
```

Frontend usage:

- Require confirmation before delete.
- Remove the row from the list after success.

### GET `/api/v1/admin/planning/missing-contacts?import_id=&limit=200`

Expected output:

```json
{
  "status": "ok",
  "missing_contacts": [
    {
      "grande_residence": "DIRECTION REGIONALE SFAX",
      "session_key": "T-IRS91-01-2026",
      "participant_count": 4
    }
  ],
  "count": 1
}
```

Frontend usage:

- Show warnings where drafts cannot be prepared because responsables are missing.

### GET `/api/v1/admin/planning/contact-review?import_id=&review_only=false&limit=200&offset=0`

Expected output:

```json
{
  "status": "ok",
  "items": [],
  "total": 0,
  "limit": 200,
  "offset": 0
}
```

Frontend usage:

- Manual matching review page.

### GET `/api/v1/admin/planning/contacts?limit=200&offset=0`

Expected output:

```json
{
  "status": "ok",
  "contacts": [],
  "total": 0,
  "limit": 200,
  "offset": 0
}
```

Frontend usage:

- Legacy contact list if needed.

### POST `/api/v1/admin/planning/contacts`

Request:

```json
{
  "matricule": "75266",
  "full_name": "BOUNEB Zied",
  "email": "zied@example.com",
  "direction": "Direction",
  "hr_responsible": "Responsable RH"
}
```

Expected output:

```json
{
  "status": "ok",
  "contact": {}
}
```

Frontend usage:

- Legacy/manual contact save.

### POST `/api/v1/admin/planning/contacts/import`

Multipart upload with field `files`.

Frontend usage:

- Maintenance/import page only.

### POST `/api/v1/admin/planning/contacts/apply?import_id=`

Expected output:

```json
{
  "status": "ok",
  "updated": 0
}
```

Frontend usage:

- Button: "Apply contact mapping".

## Automation APIs

### GET `/api/v1/admin/planning/automation/settings`

Expected output:

```json
{
  "status": "ok",
  "settings": {
    "auto_run_after_import": true,
    "default_email_type": "auto",
    "include_population": true,
    "max_drafts_per_run": 100
  }
}
```

Frontend usage:

- Drafts/automation settings form.

### PATCH `/api/v1/admin/planning/automation/settings`

Request:

```json
{
  "auto_run_after_import": true,
  "default_email_type": "auto",
  "include_population": true,
  "max_drafts_per_run": 100
}
```

Expected output:

```json
{
  "status": "ok",
  "settings": {}
}
```

Frontend usage:

- Save automation settings.
- Do not show technical labels like `auto_run_after_import`; use user-friendly labels.

### POST `/api/v1/admin/planning/automation/run`

Runs the planning flow: find upcoming sessions, group participants by residence, match responsables, prepare drafts.

Request:

```json
{
  "import_id": "import-id",
  "email_type": "auto",
  "include_population": true,
  "limit": 100,
  "replace_existing": false,
  "upcoming_days": 7
}
```

Expected output:

```json
{
  "status": "ok",
  "job_id": 1,
  "result": {
    "sessions_checked": 20,
    "drafts_created": 31,
    "drafts_skipped": 0
  }
}
```

Frontend usage:

- Manual "Generate drafts" action.
- Show loading and then job result.

### GET `/api/v1/admin/planning/automation/jobs?job_status=&job_type=&limit=100&offset=0`

Expected output:

```json
{
  "status": "ok",
  "jobs": [
    {
      "id": 1,
      "job_type": "draft_generation",
      "status": "SUCCESS",
      "requested_by": "admin@tunisietelecom.tn",
      "started_at": "2026-09-13T10:00:00",
      "finished_at": "2026-09-13T10:00:10"
    }
  ],
  "total": 1,
  "limit": 100,
  "offset": 0
}
```

Frontend usage:

- Automation history table.

### GET `/api/v1/admin/planning/automation/jobs/{job_id}`

Expected output:

```json
{
  "status": "ok",
  "job": {},
  "logs": []
}
```

Frontend usage:

- Job detail drawer/page.

### GET `/api/v1/admin/planning/automation/jobs/{job_id}/logs?limit=200&offset=0`

Expected output:

```json
{
  "status": "ok",
  "logs": [
    {
      "level": "info",
      "message": "Drafts generated",
      "created_at": "2026-09-13T10:00:00"
    }
  ],
  "total": 1,
  "limit": 200,
  "offset": 0
}
```

Frontend usage:

- Show logs only in a detail/diagnostics view.

## Draft APIs

### POST `/api/v1/admin/planning/drafts/generate`

Use it to generate drafts for a specific import/session or upcoming window.

Request:

```json
{
  "import_id": "import-id",
  "session_key": null,
  "email_type": "auto",
  "include_population": true,
  "limit": 100,
  "replace_existing": false,
  "upcoming_days": 7
}
```

Expected output:

```json
{
  "status": "ok",
  "drafts_created": 31,
  "drafts": []
}
```

Frontend usage:

- Use from Drafts page or Session detail.
- If `replace_existing` is true, require confirmation.

### GET `/api/v1/admin/planning/drafts`

Supported filters:

- `import_id`
- `session_key`
- `draft_status`
- `email_type`
- `limit`
- `offset`

Expected output:

```json
{
  "status": "ok",
  "drafts": [
    {
      "id": 1,
      "session_key": "T-IRS91-01-2026",
      "status": "WAITING_REVIEW",
      "email_type": "confirmation",
      "subject": "Confirmation de presence formation",
      "responsables": [
        {
          "nom_complet": "Responsable Name",
          "fonction": "RESP RH",
          "grande_residence": "DIRECTION REGIONALE SFAX"
        }
      ],
      "participants": [],
      "created_at": "2026-09-13T10:00:00"
    }
  ],
  "total": 1,
  "limit": 100,
  "offset": 0
}
```

Frontend usage:

- Draft list with filters and pagination.
- Show responsables, session, participants count, status.

### GET `/api/v1/admin/planning/drafts/review`

Expected output:

```json
{
  "status": "ok",
  "drafts": [],
  "summary": {
    "waiting_review": 31,
    "approved": 0,
    "sent": 0,
    "rejected": 0
  },
  "total": 31,
  "limit": 100,
  "offset": 0
}
```

Frontend usage:

- Review queue page.
- Add pagination using `total`, `limit`, `offset`.

### GET `/api/v1/admin/planning/drafts/{draft_id}`

Expected output:

```json
{
  "status": "ok",
  "draft": {
    "id": 1,
    "subject": "Confirmation de presence formation",
    "body": "Bonjour...",
    "html_body": "<p>Bonjour...</p>",
    "responsables": [],
    "participants": [],
    "session": {}
  }
}
```

Frontend usage:

- Draft detail page.
- Show session info, responsables, candidate list, email body.
- Do not show regenerate controls on the final review detail if the product flow only allows reject or mark as sent.

### PATCH `/api/v1/admin/planning/drafts/{draft_id}`

Request:

```json
{
  "subject": "Updated subject",
  "body": "Updated plain body",
  "html_body": "<p>Updated body</p>",
  "recipients": [],
  "cc": []
}
```

Expected output:

```json
{
  "status": "ok",
  "draft": {}
}
```

Frontend usage:

- Optional edit screen.
- In the current product flow, avoid exposing recipients/cc inputs if responsables are shown as names only.

### POST `/api/v1/admin/planning/drafts/{draft_id}/regenerate`

Request:

```json
{
  "email_type": "auto",
  "include_population": true
}
```

Expected output:

```json
{
  "status": "ok",
  "draft": {}
}
```

Frontend usage:

- Use only from an advanced draft tools screen, not from simple final review.

### POST `/api/v1/admin/planning/drafts/{draft_id}/approve`

Expected output:

```json
{
  "status": "ok",
  "draft": {}
}
```

Frontend usage:

- Marks draft as approved by the dashboard user.

### POST `/api/v1/admin/planning/drafts/{draft_id}/reject`

Request:

```json
{
  "reason": "Needs correction"
}
```

Expected output:

```json
{
  "status": "ok",
  "draft": {}
}
```

Frontend usage:

- In the current simple review flow, use Reject to remove/close the draft.
- Ask for optional reason.

### POST `/api/v1/admin/planning/drafts/{draft_id}/send`

Sends one approved draft if automatic sending is enabled. In the current business flow, the user usually sends manually from Outlook, so use this only if product owner enables backend sending.

Request:

```json
{
  "confirmation": "SEND_APPROVED_DRAFT",
  "confirmed_recipient_count": 1,
  "confirmed_subject": "Confirmation de presence formation"
}
```

Expected output:

```json
{
  "status": "ok",
  "send_log": {}
}
```

Frontend usage:

- Always show a safety confirmation before calling.
- If the user manually sent from Outlook, prefer a "Mark as sent" flow if available in the product.

### POST `/api/v1/admin/planning/drafts/bulk-action`

Request:

```json
{
  "draft_ids": [1, 2, 3],
  "action": "approve",
  "reason": "",
  "email_type": "auto",
  "include_population": true
}
```

Expected output:

```json
{
  "status": "ok",
  "updated": 3,
  "results": []
}
```

Frontend usage:

- Bulk approve/reject/regenerate.
- Require confirmation for bulk reject/regenerate.

### POST `/api/v1/admin/planning/drafts/bulk-send`

Request:

```json
{
  "draft_ids": [1, 2, 3],
  "confirmation": "SEND_APPROVED_DRAFT",
  "confirmed_draft_count": 3,
  "confirmed_total_recipient_count": 3
}
```

Expected output:

```json
{
  "status": "ok",
  "sent": 3,
  "results": []
}
```

Frontend usage:

- Use only after explicit confirmation.
- Show failed results clearly.

### GET `/api/v1/admin/planning/send-history?import_id=&draft_id=&send_status=&limit=100&offset=0`

Expected output:

```json
{
  "status": "ok",
  "history": [
    {
      "draft_id": 1,
      "status": "SENT",
      "sent_at": "2026-09-13T10:00:00",
      "subject": "Confirmation de presence formation"
    }
  ],
  "total": 1,
  "limit": 100,
  "offset": 0
}
```

Frontend usage:

- Send history page.
- Remember: for Outlook manual sending, history should eventually be read from the sent Outlook mailbox, not only local draft send logs.

## Error Handling

Expected error shape:

```json
{
  "detail": "Human readable message"
}
```

Frontend behavior:

- `401`: clear token and redirect to login.
- `403`: show access denied.
- `404`: show not found state.
- `409`: show conflict message and ask user to refresh.
- `422`: show form validation errors.
- `502`: backend cannot reach planning service; show "Planning service unavailable. Check backend containers."

## Angular Pages To Build

1. Login
   - Uses `POST /api/v1/auth/admin/login`.

2. Admin layout
   - Uses `GET /api/v1/admin/me`.
   - Contains logout via `POST /api/v1/auth/logout`.

3. Dashboard overview
   - Uses `/admin/overview`, `/admin/planning/analytics/overview`.

4. Planning imports
   - Preview/import files.
   - Import history and detail.

5. Training sessions
   - Calendar and table.
   - Month/year filters.
   - Detail with participants and residences.

6. Responsables directory
   - Search, count, paginated list from `/planning/responsables`.

7. Contact review
   - Missing contacts and matching review.

8. Draft review
   - Paginated review queue.
   - Draft detail with responsables, session and participants.
   - Reject or mark/send according to product flow.

9. Automation center
   - Settings, manual run, job history, logs.

10. Analytics
    - Files treated.
    - Drafts prepared.
    - Usage by admin user.

11. Admin usage
    - Uses `/admin/usage/overview`, `/admin/usage/actions`, `/admin/usage/admins`.
    - Shows usage cards, trace table and per-admin usage detail.

12. Admin management
    - Super admin only.
    - Uses `/admin/admins`.
    - Create, edit, disable and reset dashboard admin passwords.

13. User management
    - Admin-only list, role update, active toggle.

14. Audit log
    - Admin-only table and detail.

15. Settings
    - Bootstrap with `/admin/settings/supervision`.
    - Edit dashboard policies.
    - Edit planning automation settings.
    - Read-only system supervision.

## UI Guidance

- Use clear French labels for business screens.
- Avoid raw names like `AGENT1_URL`, `job_type`, or raw JSON in normal screens.
- Keep raw diagnostics inside advanced details only.
- Always show loading, empty and error states.
- Never send emails without explicit confirmation.
- For normal users, prefer business wording: "Brouillons", "Formations", "Responsables", "Historique", "Parametres".
