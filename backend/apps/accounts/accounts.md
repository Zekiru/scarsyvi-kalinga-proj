# Accounts App (`apps/accounts`)

The `accounts` app serves as the authentication, user profile, and role-based access control (RBAC) foundation for the Kalinga platform. It provides DRF token-based authentication, account management endpoints, centralized permission classes, and shared user summary serializers consumed across `curriculum`, `classrooms`, and `forums`.

---

## Architecture Overview

```text
apps/accounts/
├── models.py        # Custom Account model (AbstractUser) and Account.Role enum
├── permissions.py   # Centralized RBAC permission classes used across all apps
├── serializers.py   # Registration, login, profile, and AccountSummarySerializer
├── services.py      # Atomic account creation, token issuance/revocation, role updates
├── views.py         # RegisterView, LoginView, LogoutView, MeView, AccountViewSet
└── urls.py          # AccountsRouter + auth endpoints mounted under /api/v1/accounts/
```

---

## User Roles (`Account.Role`)

Every `Account` is assigned one of five system roles:

| Role | Display Name | Primary Responsibilities |
| :--- | :--- | :--- |
| `TEACHER` | Teacher | Default role on public registration. Can view/fork lesson plans, manage their own classrooms, and participate in forums. |
| `AUTHOR` | Author | Can create, edit, and structure multi-grade `LessonPlan` templates and curriculum resources. |
| `CHECKER` | Checker | Quality assurance reviewer who can be assigned to review and validate `LessonPlan` entries (`LpChecker`). |
| `MODERATOR` | Moderator | Can pin, lock, and soft-hide threads and posts across `forums`. |
| `ADMIN` | Admin | Full administrative privileges across all apps, including promoting/demoting user roles. |

---

## Centralized Permission Classes (`permissions.py`)

Other apps import these classes directly from `apps.accounts.permissions`:

* **`IsAdminRole`**: Grants access only to users with `role == ADMIN` or `is_superuser`.
* **`IsModeratorOrAdmin`**: Grants access to `MODERATOR`, `ADMIN`, or superusers (used in `forums`).
* **`IsAuthorOrAdmin`**: Grants access to `AUTHOR`, `ADMIN`, or superusers (used in `curriculum`).
* **`IsCheckerOrAdmin`**: Grants access to `CHECKER`, `ADMIN`, or superusers (used in `curriculum`).
* **`IsOwnerOrModeratorOrAdmin`**: Object-level permission allowing any authenticated user to read (`SAFE_METHODS`), while restricting mutations to the object's `author`/`adviser`, a `MODERATOR`, or an `ADMIN`.

---

## Service Layer (`services.py`)

* **`register_account_with_token(serializer)`**: Atomically creates an `Account` (defaulting role to `TEACHER`) and generates its initial `rest_framework.authtoken.models.Token`.
* **`get_or_create_user_token(user)`**: Retrieves or creates a DRF `Token` on login.
* **`revoke_user_token(user)`**: Deletes the user's active token on logout.
* **`update_account_role(target_user, new_role)`**: Updates a user's `role` field (admin-only).

---

## API Endpoints (`/api/v1/accounts/`)

All authenticated requests must include the header:
```http
Authorization: Token <your_token_key>
```

| Method | Endpoint | Permission | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/accounts/` | `IsAuthenticated` | Browsable `AccountsRootView` listing all account endpoints. |
| `POST` | `/api/v1/accounts/register/` | `AllowAny` | Registers a new `TEACHER` account and returns `{ "token", "user" }`. |
| `POST` | `/api/v1/accounts/login/` | `AllowAny` | Authenticates credentials and returns `{ "token", "user" }`. |
| `POST` | `/api/v1/accounts/logout/` | `IsAuthenticated` | Revokes the caller's active authentication token. |
| `GET` | `/api/v1/accounts/me/` | `IsAuthenticated` | Retrieves the authenticated user's profile. |
| `PATCH` | `/api/v1/accounts/me/` | `IsAuthenticated` | Updates mutable profile fields (`email`, `first_name`, `last_name`). |
| `GET` | `/api/v1/accounts/users/` | `IsAuthenticated` | Lists/searches active accounts (`?search=`, `?role=`). |
| `GET` | `/api/v1/accounts/users/{id}/` | `IsAuthenticated` | Retrieves summary details for a specific user. |
| `POST` | `/api/v1/accounts/users/{id}/set-role/` | `IsAdminRole` | Updates the target user's role (`{ "role": "AUTHOR" }`). |

---

## Example Payloads

### Register (`POST /api/v1/accounts/register/`)
```json
{
  "username": "maria_santos",
  "email": "maria.santos@kalinga.edu.ph",
  "first_name": "Maria",
  "last_name": "Santos",
  "password": "StrongPassword123!",
  "password_confirm": "StrongPassword123!"
}
```

### Login (`POST /api/v1/accounts/login/`)
```json
{
  "username": "maria_santos",
  "password": "StrongPassword123!"
}
```

### Set User Role (`POST /api/v1/accounts/users/{id}/set-role/`)
```json
{
  "role": "AUTHOR"
}
```