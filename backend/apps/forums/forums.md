# Forums App (`apps/forums`)

The `forums` app provides lesson-plan-scoped collaboration workspaces (`LessonPlanForum`), discussion threads (`ForumThread`), and nested replies (`ForumPost`). It supports on-demand (`get_or_create`) forum initialization per `LessonPlan`, role- and author-based moderation (`is_pinned`, `is_locked`, `is_hidden`), and visibility filtering so soft-hidden content is excluded from regular users' feeds.

---

## Architecture Overview

```text
apps/forums/
├── models.py        # LessonPlanForum, ForumThread, ForumPost
├── permissions.py   # IsAuthorOrForumModerator & IsForumModeratorPermission
├── selectors.py     # Optimized QuerySets with thread/post counts and soft-hide filtering
├── services.py      # Atomic get_or_create forum setup, lock guards, nested reply validation, moderation
├── serializers.py   # Forum, Thread (List/Detail/Write/Update), Post, and Moderation serializers
├── views.py         # ViewSets and custom actions (/by-lesson-plan/, /toggle-lock/, /moderate/, /toggle-hide/)
└── urls.py          # ForumsRouter (ForumsRootView) mounted under /api/v1/forums/
```

---

## Data Model & Moderation Mechanics

* **`LessonPlanForum`**: One-to-one discussion container attached to a `curriculum.LessonPlan`. Can be lazily initialized on demand without modifying `LessonPlan` creation flows. Supports `is_locked` to freeze new threads and replies.
* **`ForumThread`**: A discussion topic or adaptation proposal inside a `LessonPlanForum`. Ordered by `['-is_pinned', '-created_at']`.
  * `is_pinned`: Keeps important announcements or teacher guides at the top of the thread list.
  * `is_locked`: Prevents non-moderators from adding new posts to the thread.
  * `is_hidden`: Soft-hides the thread from regular users while keeping it visible to moderators and its original author.
* **`ForumPost`**: Comment/reply inside a `ForumThread`, supporting optional `parent_post` self-references for nested comment replies (validated to belong to the same `thread`).

---

## Permissions & Moderation (`permissions.py`)

A user qualifies as a **Forum Moderator** for a given `LessonPlanForum` if they are:
1. An **`ADMIN`** or superuser,
2. A **`CHECKER`**, or
3. An assigned **`AUTHOR`** (`LpAuthor`) of the linked `LessonPlan`.

* **Read Access (`GET`, `HEAD`, `OPTIONS`)**: Any authenticated user (soft-hidden threads/posts are automatically filtered out for non-moderators).
* **Creating Forums, Threads & Posts**: Any authenticated user (unless the target `LessonPlanForum` or `ForumThread` has `is_locked=True`, in which case only Forum Moderators can post).
* **Editing / Deleting Threads & Posts (`PATCH`, `DELETE`)**: Restricted to the content's `author` or a Forum Moderator via `IsAuthorOrForumModerator`.
* **Moderation Endpoints (`/toggle-lock/`, `/moderate/`, `/toggle-hide/`)**: Restricted strictly to Forum Moderators via `IsForumModeratorPermission`.

---

## Service Layer (`services.py`)

* **`get_or_create_forum_for_lesson_plan(lesson_plan)`**: Atomically retrieves or creates the `LessonPlanForum` for a `LessonPlan`.
* **`create_forum_thread(author, validated_data)`**: Enforces forum lock checks before creating a `ForumThread` assigned to `author`.
* **`create_forum_post(author, validated_data)`**: Enforces forum lock, thread lock, and hidden-thread checks, and validates that `parent_post` (if supplied) belongs to the same `thread`.
* **`update_thread_moderation(thread, *, is_pinned, is_locked, is_hidden)`**: Atomically updates moderation flags on a `ForumThread`.

---

## API Endpoints (`/api/v1/forums/`)

| Method | Endpoint | Permission | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/forums/` | `IsAuthenticated` | Browsable `ForumsRootView` directory. |
| `GET, POST` | `/api/v1/forums/forums/` | `IsAuthorOrForumModerator` | List (`?lesson_plan=`, `?is_locked=`, `?search=`) or initialize a forum. |
| `GET, PATCH, DELETE` | `/api/v1/forums/forums/{id}/` | `IsAuthorOrForumModerator` | Retrieve, update, or delete a lesson plan forum. |
| `POST` | `/api/v1/forums/forums/by-lesson-plan/` | `IsAuthenticated` | Idempotently gets or creates the forum for `lesson_plan_id`. |
| `POST` | `/api/v1/forums/forums/{id}/toggle-lock/` | `IsForumModeratorPermission` | Toggles `is_locked` on the entire lesson plan forum. |
| `GET, POST` | `/api/v1/forums/threads/` | `IsAuthorOrForumModerator` | List (`?forum=`, `?forum__lesson_plan=`, `?author=`, `?is_pinned=`, `?search=`) & create threads. |
| `GET, PATCH, DELETE` | `/api/v1/forums/threads/{id}/` | `IsAuthorOrForumModerator` | Retrieve thread with ordered nested posts, edit `title`/`body`, or delete. |
| `POST` | `/api/v1/forums/threads/{id}/moderate/` | `IsForumModeratorPermission` | Updates `is_pinned`, `is_locked`, and/or `is_hidden` on a thread. |
| `GET, POST` | `/api/v1/forums/posts/` | `IsAuthorOrForumModerator` | List (`?thread=`, `?author=`, `?parent_post=`) & create top-level or nested replies. |
| `GET, PATCH, DELETE` | `/api/v1/forums/posts/{id}/` | `IsAuthorOrForumModerator` | Retrieve, edit `content`, or delete a post. |
| `POST` | `/api/v1/forums/posts/{id}/toggle-hide/` | `IsForumModeratorPermission` | Toggles `is_hidden` soft-hide flag on a post. |

---

## Example Payloads (Sequential Usage Flow)

### 1. Initialize or Fetch Forum for a Lesson Plan (`POST /api/v1/forums/forums/by-lesson-plan/`)
```json
{
  "lesson_plan_id": 1
}
```

### 2. Create a Discussion Thread (`POST /api/v1/forums/threads/`)
```json
{
  "forum": 1,
  "title": "Adapting the Place Value Station for 45-Minute Periods",
  "body": "Has anyone tried splitting the Guided Practice station into two 15-minute rotations for larger multigrade sections?"
}
```

### 3. Post a Top-Level Reply (`POST /api/v1/forums/posts/`)
```json
{
  "thread": 1,
  "content": "Yes! We paired Grade 2 peer leaders with Grade 1 groups and finished right at the 40-minute mark."
}
```

### 4. Post a Nested Reply to Another Comment (`POST /api/v1/forums/posts/`)
```json
{
  "thread": 1,
  "parent_post": 1,
  "content": "That peer-leader pairing worked well for us too—especially when distributing the base-ten blocks."
}
```

### 5. Moderate a Thread (`POST /api/v1/forums/threads/{thread_id}/moderate/`)
```json
{
  "is_pinned": true,
  "is_locked": false,
  "is_hidden": false
}
```

### 6. Soft-Hide or Restore a Post (`POST /api/v1/forums/posts/{post_id}/toggle-hide/`)
```json
{}
```

### 7. Lock or Unlock an Entire Lesson Plan Forum (`POST /api/v1/forums/forums/{forum_id}/toggle-lock/`)
```json
{}
```