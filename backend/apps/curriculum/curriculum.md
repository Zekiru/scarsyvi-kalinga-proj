# Curriculum App (`apps/curriculum`)

The `curriculum` app manages multi-grade lesson plans, differentiated grade-level standards, instructional flows, grading tasks, and shared teaching materials (including offline caching metadata for mobile clients). It supports full-text search, multi-parameter filtering, ordering, pagination, and transactional deep-cloning ("forking") of lesson plans.

---

## Architecture Overview

```text
apps/curriculum/
├── models.py        # LessonPlan, GradeLevel, Material, and differentiated child entities
├── permissions.py   # IsCurriculumEditorOrReadOnly (Author/Admin mutation & ownership checks)
├── selectors.py     # Optimized QuerySets using select_related and prefetch_related
├── services.py      # Atomic LessonPlan creation, checker assignment, and fork_lesson_plan
├── filters.py       # LessonPlanFilter (learning_area, language, grade_level, author, is_fork)
├── pagination.py    # LessonPlanPagination (default 10 items/page, max 100)
├── serializers.py   # List, Detail, Write, Fork, and Checker serializers
├── views.py         # ViewSets with search, filter, ordering, pagination, and custom actions
└── urls.py          # CurriculumRouter mounted under /api/v1/curriculum/
```

---

## Data Model Hierarchy

* **`LessonPlan`**: Top-level multi-grade curriculum container. Tracks `forked_from` (nullable self-FK) for adapted/cloned plans.
  * **`LpAuthor`**: Links `LessonPlan` to `Account` creators (`author_role`).
  * **`LpChecker`**: Links `LessonPlan` to `Account` quality reviewers (`checker_role`).
  * **`LessonGradeLevel`**: Differentiated plan per `GradeLevel` containing DepEd standards (`i_content_standard`, `i_performance_standard`, `i_competencies_codes`, `i_objectives`), localization context (`l_context`), reflection (`w_reflection_questions`), and remediation/enrichment (`re_remediation`, `re_enrichment`).
    * **`LessonGradeMaterial`**: Links shared `Material` assets (with `is_offline_cached` flag) and usage instructions to a grade level.
    * **`LessonFlow`**: Ordered instructional stages and durations (`time_minutes`, `stage`, `description`).
    * **`LessonGrading`**: Differentiated assessment tasks (`task_name`, `grade_weight`, `max_score`) referenced by `classrooms.StudentGrade`.

---

## Permissions & Access Control

* **Read Access (`GET`, `HEAD`, `OPTIONS`)**: Any authenticated user (`TEACHER`, `AUTHOR`, `CHECKER`, `MODERATOR`, `ADMIN`).
* **Create / Edit / Delete**: Restricted to `AUTHOR` or `ADMIN` accounts via `IsCurriculumEditorOrReadOnly`. Object-level edits on a `LessonPlan` require the user to be an assigned author (`LpAuthor`) or an `ADMIN`.
* **Forking (`POST /lesson-plans/{id}/fork/`)**: Open to any authenticated user so teachers can adapt existing lesson plans for their own classrooms.
* **Assigning Checkers (`POST /lesson-plans/{id}/assign-checker/`)**: Restricted to `CHECKER` or `ADMIN` accounts (`IsCheckerOrAdmin`).

---

## Service Layer (`services.py`)

* **`create_lesson_plan(author, validated_data)`**: Atomically creates a `LessonPlan`, registers the caller in `LpAuthor` as `"Primary Author"`, and initializes `LessonGradeLevel` records for any selected grade levels.
* **`fork_lesson_plan(original_lp, new_author, custom_title=None)`**: Atomically deep-clones a `LessonPlan` along with every child `LessonGradeLevel`, `LessonGradeMaterial`, `LessonFlow`, and `LessonGrading` record, assigning `new_author` as Primary Author and setting `forked_from = original_lp`.
* **`assign_lesson_plan_checker(lp, checker, checker_role)`**: Validates that the target user holds the `CHECKER` or `ADMIN` role and creates/updates their `LpChecker` link.

---

## API Endpoints (`/api/v1/curriculum/`)

| Method | Endpoint | Permission | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/curriculum/` | `IsAuthenticated` | Browsable `CurriculumRootView` directory. |
| `GET, POST` | `/api/v1/curriculum/lesson-plans/` | `IsCurriculumEditorOrReadOnly` | Paginated list & creation of multi-grade lesson plans. |
| `GET, PATCH, DELETE` | `/api/v1/curriculum/lesson-plans/{id}/` | `IsCurriculumEditorOrReadOnly` | Full nested detail tree, update, or deletion. |
| `POST` | `/api/v1/curriculum/lesson-plans/{id}/fork/` | `IsAuthenticated` | Deep-clones the lesson plan and all grade-level children. |
| `POST` | `/api/v1/curriculum/lesson-plans/{id}/assign-checker/` | `IsCheckerOrAdmin` | Assigns a `CHECKER` or `ADMIN` reviewer to the lesson plan. |
| `GET, POST` | `/api/v1/curriculum/grade-levels/` | `IsCurriculumEditorOrReadOnly` | Master list and management of grade levels. |
| `GET, POST` | `/api/v1/curriculum/materials/` | `IsCurriculumEditorOrReadOnly` | Shared teaching assets (`?file_type=`, `?is_offline_cached=`). |
| `GET, POST` | `/api/v1/curriculum/lesson-grade-levels/` | `IsCurriculumEditorOrReadOnly` | Differentiated grade-level standards (`?lp=`, `?gl=`). |
| `GET, POST` | `/api/v1/curriculum/lesson-grade-materials/` | `IsCurriculumEditorOrReadOnly` | Attachments linking `Material` to `LessonGradeLevel`. |
| `GET, POST` | `/api/v1/curriculum/lesson-flows/` | `IsCurriculumEditorOrReadOnly` | Timed instructional steps per grade level. |
| `GET, POST` | `/api/v1/curriculum/lesson-gradings/` | `IsCurriculumEditorOrReadOnly` | Assessment tasks and weights per grade level. |

---

## Querying `GET /api/v1/curriculum/lesson-plans/`

* **Pagination**: `?page=1&page_size=20` (default `page_size=10`, max `100`)
* **Search** (matches `lp_title`, `learning_area`, `primary_language`, `suggested_demographic`, and `i_competencies_codes`):
  `?search=fractions`
* **Filtering**:
  * `?learning_area=Mathematics` (case-insensitive exact match)
  * `?primary_language=Tagalog` (case-insensitive exact match)
  * `?grade_level=1` (filters by `GradeLevel.gl_id`)
  * `?author=2` / `?checker=3` (filters by `Account.id`)
  * `?forked_from=5` (lists all forks of lesson plan `5`)
  * `?is_fork=false` (returns only original/root lesson plans)
* **Ordering**: `?ordering=lp_title` or `?ordering=-lp_id`

---

## Example Payloads (Sequential Creation Order)

When building a full multi-grade lesson plan sequentially via REST calls, follow the dependency order below:
**1. Master References (`GradeLevel`, `Material`) $\rightarrow$ 2. `LessonPlan` $\rightarrow$ 3. `LessonGradeLevel` $\rightarrow$ 4. Child Resources (`LessonGradeMaterial`, `LessonFlow`, `LessonGrading`)**.

### 1A. Create Grade Level (`POST /api/v1/curriculum/grade-levels/`)
```json
{
  "grade_level_name": "Grade 1"
}
```

### 1B. Create Material (`POST /api/v1/curriculum/materials/`)
```json
{
  "file_name": "Place_Value_Blocks_Worksheet.pdf",
  "file_url": "https://cdn.kalinga.edu.ph/materials/place_value_blocks_g1.pdf",
  "file_type": "PDF",
  "file_size_kb": 1420,
  "description": "Printable base-ten blocks cut-out and counting worksheet for Grade 1.",
  "is_offline_cached": true
}
```

### 2. Create Lesson Plan (`POST /api/v1/curriculum/lesson-plans/`)
> **Note:** Omit `grade_levels` if you plan to create differentiated `LessonGradeLevel` records via `POST` in Step 3. Including `grade_levels` here pre-creates blank rows that would require `PATCH` instead of `POST`.

```json
{
  "lp_title": "Multi-Grade Place Value & Number Sense",
  "learning_area": "Mathematics",
  "primary_language": "Filipino",
  "suggested_demographic": "Grades 1-2 Combined Multigrade Class",
  "learning_model_description": "Explicit instruction followed by peer-assisted learning stations.",
  "intentions_description": "Build foundational place value fluency using local manipulatives.",
  "notes": "Prepare popsicle stick bundles prior to class."
}
```

### 3. Create Differentiated Lesson Grade Level (`POST /api/v1/curriculum/lesson-grade-levels/`)
```json
{
  "lp": 1,
  "gl": 1,
  "i_content_standard": "The learner demonstrates understanding of whole numbers up to 100.",
  "i_performance_standard": "The learner is able to recognize, represent, and order whole numbers up to 100.",
  "i_competencies_codes": "M1NS-Ia-1.1, M1NS-Ib-2.1",
  "i_objectives": "Identifies tens and ones in two-digit numbers using concrete objects.",
  "l_context": "Use bundled bamboo sticks or local shells from the community.",
  "w_reflection_questions": "How does grouping by tens make counting large sets easier?",
  "re_remediation": "Guided one-on-one counting with ten-frames for numbers 10 to 30.",
  "re_enrichment": "Peer challenge: build three different two-digit numbers using 9 base-ten rods."
}
```

### 4A. Attach Material to Grade Level (`POST /api/v1/curriculum/lesson-grade-materials/`)
```json
{
  "lesson_grade_level": 1,
  "material_id": 1,
  "usage_instructions": "Distribute one printed sheet per pair during the Guided Practice station."
}
```

### 4B. Create Instructional Flow Step (`POST /api/v1/curriculum/lesson-flows/`)
```json
{
  "lesson_grade_level": 1,
  "time_minutes": 15,
  "stage": "Introduction",
  "description": "Warm-up skip counting by 10s using bundled popsicle sticks."
}
```

### 4C. Create Grading / Assessment Task (`POST /api/v1/curriculum/lesson-gradings/`)
```json
{
  "lesson_grade_level": 1,
  "task_name": "Tens and Ones Exit Ticket",
  "task_description": "Identify the tens and ones digits for five illustrated stick bundles.",
  "grade_weight": "1.00",
  "max_score": 20
}
```

### 5. Fork Lesson Plan (`POST /api/v1/curriculum/lesson-plans/{lp_id}/fork/`)
```json
{
  "lp_title": "Multi-Grade Place Value (Pasig Contextualized)"
}
```

### 6. Assign Checker (`POST /api/v1/curriculum/lesson-plans/{lp_id}/assign-checker/`)
```json
{
  "account_id": 3,
  "checker_role": "Curriculum QA Reviewer"
}
```