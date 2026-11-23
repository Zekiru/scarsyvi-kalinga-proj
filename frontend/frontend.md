# MyBasic Education (MBEd) — Flutter Client Documentation

**MyBasic Education (MBEd)** is an offline-first multigrade education application built with **Flutter**, **Riverpod**, and **Hive**, backed by a **Django REST Framework (DRF)** API. It empowers teachers, curriculum checkers, and administrators in low-connectivity environments to author multigrade lesson plans, manage classroom rosters, record attendance and grades, and collaborate in lesson plan forums seamlessly both online and offline.

---

## Table of Contents

1. [Architecture & Tech Stack](#1-architecture--tech-stack)
2. [Directory Structure](#2-directory-structure)
3. [Core Features](#3-core-features)
4. [Offline-First Synchronization Engine](#4-offline-first-synchronization-engine)
5. [Caching, Prefetching & Conflict Resolution](#5-caching-prefetching--conflict-resolution)
6. [Theming & Navigation](#6-theming--navigation)
7. [Getting Started & Configuration](#7-getting-started--configuration)
8. [Platform Display Naming](#8-platform-display-naming)

---

## 1. Architecture & Tech Stack

MBEd follows a **feature-first, layered architecture** with unidirectional data flow and strict separation between UI presentation, state orchestration, offline caching, and network transport.

| Layer | Technology / Pattern | Responsibility |
| :--- | :--- | :--- |
| **UI & Design System** | Flutter (Material 3) | Adaptive Light/Dark/System themes (`AppTheme`), responsive shell navigation (`AppShell`), filter chips, and offline status indicators. |
| **State Management** | `flutter_riverpod` (v3.x `Notifier` / `AsyncNotifier`) | Reactive state stores for auth, sync engine status, theme mode, home dashboard, curriculum, classrooms, and forums. |
| **Local Persistence** | `hive` & `hive_flutter` | Dedicated typed/JSON local boxes (`HiveBoxes`) storing offline mutations, ID mappings, and full domain entity trees. |
| **Networking** | Custom `ApiClient` + `ApiException` | RESTful JSON client communicating with the Django REST Framework API, normalizing offline vs. HTTP error states. |
| **Sync & Prefetch** | `SyncQueueService`, `IdMappingStore`, `OfflinePrefetchService` | FIFO offline mutation replay, parent-child `tmp_*` ID resolution, remote `updated_at` conflict detection, and startup hydration. |

---

## 2. Directory Structure

```text
lib/
├── main.dart                                  # App entry point, Hive initialization, KalingaApp root widget
├── core/
│   ├── config/
│   │   └── api_endpoints.dart                 # Centralized Django REST Framework route definitions
│   ├── network/
│   │   ├── api_client.dart                    # HTTP wrapper (GET, POST, PATCH, PUT, DELETE) with auth headers
│   │   ├── api_exception.dart                 # Unified error model (isOffline, statusCode, unique constraint checks)
│   │   └── connectivity_provider.dart         # Real-time online/offline connectivity stream
│   ├── presentation/
│   │   └── app_shell.dart                     # Authenticated shell, bottom/rail navigation, lifecycle sync listener
│   ├── storage/
│   │   └── hive_boxes.dart                    # Hive box initialization (queue, id_mappings, curriculum, classrooms, forums)
│   ├── sync/
│   │   ├── id_mapping_store.dart              # Maps client-generated tmp_* IDs to server integer PKs
│   │   ├── offline_prefetch_service.dart      # Eager background downloader for owned offline datasets
│   │   ├── sync_operation.dart                # Hive model representing a queued offline HTTP mutation
│   │   ├── sync_queue_service.dart            # FIFO queue processor, cache reconciler, and conflict detector
│   │   └── sync_status_provider.dart          # Riverpod notifier driving sync UI, auto-replay, and store refreshes
│   └── theme/
│       └── app_theme.dart                     # Material 3 Light/Dark themes and ThemeModeNotifier
└── features/
    ├── accounts/
    │   ├── data/account_model.dart            # User profile & RBAC flags (canTeach, canModerate, canAdminister)
    │   ├── presentation/
    │   │   ├── account_screen.dart            # Profile, Appearance switcher, RBAC summary, Sync Engine monitor
    │   │   └── login_screen.dart              # Authentication screen
    │   └── providers/auth_provider.dart         # Auth lifecycle state (initializing, authenticated, unauthenticated)
    ├── home/
    │   └── presentation/home_screen.dart      # Unified dashboard summarizing owned plans, classrooms, and sync state
    ├── curriculum/
    │   ├── data/
    │   │   ├── curriculum_cache_store.dart    # Structured Hive helper for lesson plans & nested children
    │   │   ├── curriculum_models.dart         # LessonPlan, LessonGradeLevel, LessonFlow, LessonGrading, LessonMaterial
    │   │   └── curriculum_repository.dart     # Network-first CRUD + offline draft queuing for curriculum entities
    │   └── providers/curriculum_provider.dart # Riverpod stores for grade levels and lesson plans
    ├── classrooms/
    │   ├── data/
    │   │   ├── classroom_models.dart          # Classroom, Student, AttendanceSession, StudentGrade
    │   │   └── classroom_repository.dart      # Network-first CRUD for classrooms, rosters, attendance, and gradebook
    │   └── providers/classroom_provider.dart  # Riverpod stores for classrooms and active classroom details
    └── forums/
        ├── data/
        │   ├── forum_models.dart              # Forum, ForumThread, ForumPost
        │   └── forum_repository.dart          # Network-first CRUD, participation tracking, and moderation actions
        └── providers/forum_provider.dart      # Riverpod stores for forums, threads, and participated forum IDs
```

---

## 3. Core Features

### A. Accounts & Role-Based Access Control (RBAC)
* **Authentication Flow:** `KalingaApp` watches `authProvider` to route cleanly between a loading splash (`AuthStatus.initializing`), `LoginScreen` (`AuthStatus.unauthenticated`), and `AppShell` (`AuthStatus.authenticated`).
* **Role Capabilities:** Surfaces granular permissions directly on `AccountScreen`:
  * **Classroom & Curriculum Authoring (`canTeach`):** Create and edit lesson plans, rosters, attendance sessions, and student grades.
  * **Checker & Forum Moderation (`canModerate`):** Approve or unapprove lesson plans, lock/unlock forums, and pin, lock, or hide threads and posts.
  * **System Administration (`canAdminister`):** Assign curriculum checkers and administer platform accounts.
* **Sync Engine Monitor:** Displays live online/offline status, pending queue counts, failed operations with detailed error messages, and one-tap **Sync**, **Retry**, or **Discard** controls.

### B. Multigrade Curriculum Authoring (`features/curriculum`)
* **Lesson Plan Management:** Full CRUD for multigrade lesson plans including learning area, primary language, suggested demographic, learning model description, shared sub-theme intentions, and reflection notes.
* **Nested Grade-Level Structure:** Each `LessonPlan` supports multiple `LessonGradeLevel` entries, each containing:
  * **Standards & Competencies:** Content standards, performance standards, DepEd competency codes, specific objectives, learner context, reflection questions, remediation, and enrichment.
  * **Lesson Flows (`LessonFlow`):** Timed instructional stages per grade level.
  * **Grading Tasks (`LessonGrading`):** Weighted assessment tasks with configurable max scores.
  * **Learning Materials (`LessonMaterial`):** Linked files and external resource URLs.
* **Forking & Approval:** Educators can fork existing public lesson plans into their own workspace; checkers can toggle approval status online or offline.

### C. Classroom, Roster, Attendance & Gradebook (`features/classrooms`)
* **Classrooms & Filtering:** Manage multigrade classrooms linked to specific grade levels and lesson plans, with horizontal `FilterChip` filtering.
* **Student Roster Management:** Create new students (with LRN, gender, and grade level) or enroll existing master-list students into a classroom—even when the classroom itself is still an unsynced offline draft.
* **Daily Attendance (`record-attendance/`):** Record per-student attendance statuses (`Present`, `Absent`, `Late`, `Excused`) and session remarks by date, deduplicated by session date on sync.
* **Batch Gradebook (`submit-grades/`):** Score students against `LessonGrading` tasks defined in the classroom's assigned lesson plan, with optimistic local persistence and batch sync.

### D. Lesson Plan Forums & Collaboration (`features/forums`)
* **Idempotent Forum Initialization:** Automatically initializes or retrieves the `LessonPlanForum` tied to any `LessonPlan` via `POST /forums/forums/by-lesson-plan/`.
* **Threads & Nested Replies:** Create discussion threads and nested replies (`parent_post`) with full offline draft support.
* **Participation Tracking:** `fetchParticipatedForumIds` tracks all forums where the user has authored threads or replies (both online and in local drafts) for quick filtering.
* **Moderation:** Supports forum locking (`toggle-lock/`), thread pinning/locking/hiding (`moderate/`), and post hiding (`toggle-hide/`).

---

## 4. Offline-First Synchronization Engine

MBEd guarantees zero data loss during connectivity drops using a **deterministic FIFO queue** backed by Hive (`HiveBoxes.queue`).

### How Offline Mutations Work
1. **Optimistic Local Write:** When a repository mutation catches `ApiException` with `isOffline == true` (or detects that a parent record is still an unsynced `tmp_*` draft), it generates a unique client ID via `IdMappingStore.generateTempId(prefix)` (e.g., `tmp_lp_...`, `tmp_cls_...`, `tmp_stu_...`, `tmp_frm_...`, `tmp_thr_...`, `tmp_pst_...`).
2. **Enqueue with Dependencies:** The mutation is persisted in `HiveBoxes.queue` as a `SyncOperation` recording the HTTP method, endpoint, serialized JSON payload, `tempClientId`, `primaryKeyField`, and `dependsOnTempIds`.
3. **Strict FIFO Replay:** When `SyncQueueService.processQueue()` runs:
   * Verifies all `dependsOnTempIds` have been resolved in `IdMappingStore`.
   * Rewrites any `tmp_*` placeholders in both the target URL (`resolveEndpoint`) and JSON body (`resolvePayload`) to their real server integer primary keys.
   * Dispatches the HTTP request to the Django REST Framework API.
4. **Post-Create Cache Reconciliation:** Upon receiving a `201 Created` response, `SyncQueueService` saves the `tmp_* -> serverId` mapping in `IdMappingStore` and runs `_reconcileLocalCacheAfterCreate()` across `HiveBoxes.curriculum`, `HiveBoxes.classrooms`, and `HiveBoxes.forums` to remove the temporary draft entry and rewrite any lingering `tmp_*` references.
5. **Failure Isolation:**
   * **Connectivity Loss (`e.isOffline`):** Reverts the operation to `SyncOpStatus.pending` and pauses the queue until connectivity returns.
   * **Duplicate Retry (`e.isUniqueConstraintCollision`):** Safely deletes the already-applied operation.
   * **Validation / RBAC / Conflict (`400`, `403`, `404`, or `updated_at` mismatch):** Marks the item as `SyncOpStatus.failedNeedsReview` so independent items behind it in the queue can still sync.

### Automatic Sync Triggers
* **Network Reconnection:** `SyncStatusNotifier` listens to `connectivityStreamProvider` and automatically calls `syncNow()` when the device transitions back online.
* **App Lifecycle Resume:** `AppShell` uses an `AppLifecycleListener` to trigger a throttled `syncNow()` (at most once every 15 seconds) whenever the app returns to the foreground.
* **Post-Sync Provider Refresh:** Every completed sync automatically refreshes `lessonPlansProvider`, `classroomsProvider`, `forumsProvider`, and `participatedForumIdsProvider` so the UI reflects server state immediately.

---

## 5. Caching, Prefetching & Conflict Resolution

### Network-First Reads with Full Fallback
Every repository read (`fetchLessonPlans`, `fetchClassrooms`, `fetchForums`, etc.) follows a three-step strategy:
1. **Attempt Network Fetch:** Queries the DRF endpoint and merges fresh server records with any still-unsynced local drafts (`isLocalDraft` / `isPendingSync`).
2. **Prune Orphaned Details:** Diffs incoming server IDs against previously cached IDs and deletes per-entity detail keys (`classroom_<id>`, `attendance_sessions_<id>`, `grades_<id>`, `forum_threads_<id>`, `thread_detail_<id>`, and lesson plan detail entries) that were deleted remotely by other users.
3. **Graceful Error Fallback:** Uses a broad `catch (e)` block so that whether the device is offline, timed out, or the server returns a `5xx` error, the repository seamlessly returns the local Hive cache without crashing the UI.

### Eager Startup Prefetching (`OfflinePrefetchService`)
Because teachers frequently prepare lessons while online and travel to off-grid schools, `AppShell` invokes `OfflinePrefetchService.prefetchOwnedData()` on login and startup to proactively hydrate:
* All **Grade Levels** and top-level lists for **Lesson Plans**, **Classrooms**, and **Forums**.
* Full nested detail trees (grade levels, flows, gradings, materials) for all **owned and co-authored lesson plans**.
* Full rosters, attendance histories, and student grades for all **advised classrooms**.
* Complete thread lists and nested post trees for all **owned or participated forums**.

### Remote Edit Conflict Detection
Before replaying any `PATCH` or `PUT` mutation against an existing server record, `SyncQueueService._checkRemoteConflict()` fetches the live resource and compares its `updated_at` timestamp against the queued operation's `createdAt` (with a 5-second clock-skew buffer). If another user modified the record on the server while the client was offline, the operation is paused as `failedNeedsReview` so the user can choose to **Retry** (overwrite) or **Discard** (keep the server version).

---

## 6. Theming & Navigation

* **Centralized Material 3 Theme (`lib/core/theme/app_theme.dart`):** Driven by a single brand seed color (`0xFF1B6B52`) generating cohesive `ColorScheme.fromSeed` palettes for both `AppTheme.light` and `AppTheme.dark`.
* **Runtime Theme Switching:** `themeModeProvider` (`NotifierProvider<ThemeModeNotifier, ThemeMode>`) allows users to toggle between **System**, **Light**, and **Dark** modes live from `AccountScreen`.
* **Unified Shell (`AppShell`):** Provides persistent top-level navigation across **Home**, **Curriculum**, **Classrooms**, **Forums**, and **Account**.

---

## 7. Getting Started & Configuration

### Prerequisites
* Flutter SDK (Dart 3.x+)
* Running instance of the **MBEd Django REST Framework** backend

### Installation & Run
1. **Install dependencies:**
   ```bash
   flutter pub get
   ```
2. **Configure API Base URL:**
   Update the backend host URL in `lib/core/config/api_endpoints.dart` to point to your Django REST Framework server (`/api/v1/`).
3. **Run the application:**
   ```bash
   # Mobile / Desktop
   flutter run

   # Web
   flutter run -d chrome
   ```

---

## 8. Platform Display Naming

To customize the exported app display name without altering the internal Dart package name:
* **Flutter App Title (`lib/main.dart`):** Set `MaterialApp(title: 'MyBasic Education', ...)`.
* **Web (`web/index.html` & `web/manifest.json`):** Update `<title>`, `apple-mobile-web-app-title`, `"name"`, and `"short_name"`.
* **Android (`android/app/src/main/AndroidManifest.xml`):** Set `android:label="MyBasic Education"` on `<application>`.
* **iOS (`ios/Runner/Info.plist`):** Set `CFBundleDisplayName` and `CFBundleName` to `MyBasic Education`.