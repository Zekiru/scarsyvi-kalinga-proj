# MBEd Backend API (Django 6.1.1 / DRF 3.18.3)

The **MyBasic Education (MBEd)** Backend is a modular, API-first Django REST Framework service built to support multigrade lesson planning, classroom management, learner performance analytics, and teacher collaboration.

---

## Architecture & Project Structure

The backend follows a clean separation of concerns across four domain apps (`models`, `permissions`, `selectors`, `services`, `serializers`, `views`, and `urls`), mounted under `/api/v1/`:

```text
backend/
├── README.md                              # Master backend documentation (this file)
├── manage.py
├── backend_django/                        # Project settings & root /api/v1/ router
└── apps/
    ├── accounts/
    │   └── accounts.md                    # Authentication, RBAC roles & user profile docs
    ├── curriculum/
    │   └── curriculum.md                  # Multi-grade lesson plans, flows, gradings & fork docs
    ├── classrooms/
    │   └── classrooms.md                  # Classrooms, student rosters, attendance & grades docs
    └── forums/
        └── forums.md                      # Lesson plan forums, threads, nested posts & moderation docs
```

---

## App Documentation Directory

Explore the detailed endpoint references, permissions, business logic, and sequential JSON payloads for each domain app:

* **[Accounts App Documentation](apps/accounts/accounts.md)** (`/api/v1/accounts/`)
  * Token-based authentication (`register`, `login`, `logout`, `me`), custom `Account` roles (`TEACHER`, `AUTHOR`, `CHECKER`, `MODERATOR`, `ADMIN`), and shared RBAC permission classes.
* **[Curriculum App Documentation](apps/curriculum/curriculum.md)** (`/api/v1/curriculum/`)
  * Multi-grade `LessonPlan` templates, differentiated `LessonGradeLevel` standards, instructional `LessonFlow` steps, `LessonGrading` tasks, offline-cacheable `Material` assets, and atomic deep-clone **forking**.
* **[Classrooms App Documentation](apps/classrooms/classrooms.md)** (`/api/v1/classrooms/`)
  * Multigrade `Classroom` management, batch student enrollment, daily `AttendanceSession` recording, batch `StudentGrade` submission, and SQL-annotated student sorting (`grade_average` and `attendance_average`).
* **[Forums App Documentation](apps/forums/forums.md)** (`/api/v1/forums/`)
  * On-demand `LessonPlanForum` workspaces, pinned/locked discussion threads (`ForumThread`), nested comment replies (`ForumPost`), and author/moderator content controls.

---

## API Root Endpoints (`/api/v1/`)

All endpoints are discoverable via browsable DRF root views when authenticated:

| App | Base Path | Browsable Root Name | Primary Responsibility |
| :--- | :--- | :--- | :--- |
| **API v1 Root** | `/api/v1/` | `API v1 Root` | Top-level dynamic directory of all mounted app routers. |
| **Accounts** | `/api/v1/accounts/` | `Accounts Root` | Registration, token login/logout, profile & role assignment. |
| **Curriculum** | `/api/v1/curriculum/` | `Curriculum Root` | Lesson plans, grade levels, materials, flows, gradings & forks. |
| **Classrooms** | `/api/v1/classrooms/` | `Classrooms Root` | Classrooms, student rosters, attendance logs & gradebooks. |
| **Forums** | `/api/v1/forums/` | `Forums Root` | Lesson-plan discussions, nested replies & moderation tools. |

---

## Authentication

The API uses DRF `TokenAuthentication`. Obtain a token via `POST /api/v1/accounts/register/` or `POST /api/v1/accounts/login/`, then include it in the `Authorization` header on all subsequent requests:

```http
Authorization: Token <your_token_key>
Content-Type: application/json
```

---

## End-to-End Sequential Data Flow

When bootstrapping or testing the platform sequentially across apps, follow this dependency order:

1. **Accounts (`/apps/accounts/accounts.md`)**: Register users and assign roles (`AUTHOR`, `CHECKER`, `TEACHER`, `MODERATOR`, `ADMIN`).
2. **Curriculum (`/apps/curriculum/curriculum.md`)**: Create `GradeLevel`s and `Material`s $\rightarrow$ `LessonPlan` $\rightarrow$ `LessonGradeLevel` $\rightarrow$ `LessonGradeMaterial`, `LessonFlow`, and `LessonGrading`.
3. **Classrooms (`/apps/classrooms/classrooms.md`)**: Create `Student`s and `Classroom` (linked to `GradeLevel`s and a `LessonPlan`) $\rightarrow$ enroll students $\rightarrow$ record attendance and submit grades against `LessonGrading` tasks.
4. **Forums (`/apps/forums/forums.md`)**: Initialize a `LessonPlanForum` via `/forums/by-lesson-plan/` $\rightarrow$ create `ForumThread`s $\rightarrow$ post top-level and nested `ForumPost` replies.

---

## Local Development Setup

```bash
# 1. Activate virtual environment
source env/bin/activate        # macOS/Linux
.\env\Scripts\Activate.ps1     # Windows PowerShell

# 2. Apply database migrations
python manage.py makemigrations
python manage.py migrate

# 3. Create an initial superuser / Admin account
python manage.py createsuperuser

# 4. Run the development server
python manage.py runserver
```