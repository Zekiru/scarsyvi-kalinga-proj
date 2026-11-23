# MyBasic Education (MBEd)

**MyBasic Education (MBEd)** is an offline-first multigrade education platform combining a **Flutter** (Riverpod/Hive) client with a **Django REST Framework** API—enabling multigrade curriculum authoring, classroom management, learner analytics, and educator forums both online and off-grid.

---

## Repository Structure & Documentation

```text
mbed/
├── README.md                  # Master repository documentation (this file)
├── backend/
│   ├── backend.md             # Django REST Framework API & domain app documentation
│   └── ...
└── frontend/
    ├── frontend.md            # Flutter offline-first client & sync engine documentation
    └── ...
```

### Detailed Sub-Project Documentation

* **[Backend API Documentation (`backend/backend.md`)](backend/backend.md)**
  * Covers the **Django 6.1.1 / DRF 3.18.3** REST API mounted under `/api/v1/`, `TokenAuthentication`, role-based access control (`TEACHER`, `AUTHOR`, `CHECKER`, `MODERATOR`, `ADMIN`), sequential data dependencies, and domain references for **Accounts**, **Curriculum**, **Classrooms**, and **Forums**.
* **[Frontend Client Documentation (`frontend/frontend.md`)](frontend/frontend.md)**
  * Covers the **Flutter** Material 3 application, **Riverpod** state stores, **Hive** local persistence, the FIFO offline `SyncQueueService`, `tmp_*` ID mapping, remote `updated_at` conflict detection, startup data prefetching, and multi-platform build naming.

---

## Full-Stack Architecture Overview

| Layer | Technology | Key Responsibilities |
| :--- | :--- | :--- |
| **Client Application** | Flutter (Dart 3, Material 3) | Cross-platform UI (Android, iOS, Web, Desktop), adaptive Light/Dark/System themes, and responsive navigation shell. |
| **Client State & Cache** | Riverpod v3 + Hive | Reactive domain notifiers, structured local caching, orphaned detail pruning, and startup hydration of owned datasets. |
| **Offline Sync Engine** | FIFO `SyncQueueService` + `IdMappingStore` | Persists offline mutations with temporary client IDs, resolves parent-child dependencies on reconnect, and detects server edit conflicts. |
| **Backend API** | Django 6.1.1 + Django REST Framework 3.18.3 | Modular domain apps (`accounts`, `curriculum`, `classrooms`, `forums`), token authentication, RBAC permissions, and atomic lesson plan forking. |

---

## Core Domain Capabilities

1. **Accounts & Role-Based Access Control**
   * Token-based registration, login, and profile management (`POST /api/v1/accounts/login/`).
   * Granular capability flags governing curriculum authoring (`AUTHOR`/`TEACHER`), lesson plan approval and forum moderation (`CHECKER`/`MODERATOR`), and system administration (`ADMIN`).
2. **Multigrade Curriculum Authoring**
   * Create and fork multigrade lesson plans differentiated across multiple grade levels (`LessonGradeLevel`), complete with DepEd standards/competencies, timed `LessonFlow` stages, weighted `LessonGrading` tasks, and offline-cacheable `Material` resources.
3. **Classrooms, Attendance & Gradebook**
   * Manage multigrade classrooms, enroll student rosters, log daily `AttendanceSession` records, submit batch `StudentGrade` scores, and view SQL-annotated grade and attendance averages.
4. **Lesson Plan Forums & Collaboration**
   * Automatically initialize dedicated `LessonPlanForum` workspaces per lesson plan (`POST /api/v1/forums/forums/by-lesson-plan/`), create discussion threads, post nested replies, and moderate content.

---

## Quick Start

### 1. Start the Backend API (`backend/`)
Refer to [Backend Setup in `backend/backend.md`](backend/backend.md#local-development-setup) for full environment instructions:

```bash
cd backend
source env/bin/activate        # Windows: .\env\Scripts\Activate.ps1
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

### 2. Run the Flutter Client (`frontend/`)
Refer to [Frontend Setup in `frontend/frontend.md`](frontend/frontend.md#7-getting-started--configuration) for API endpoint configuration and platform builds:

```bash
cd frontend
flutter pub get
flutter run                    # Or: flutter run -d chrome
```