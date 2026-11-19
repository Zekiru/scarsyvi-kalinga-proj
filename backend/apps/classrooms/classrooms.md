# Classrooms App (`apps/classrooms`)

The `classrooms` app manages multigrade classrooms, student rosters, batch attendance sessions, and student assessment grades tied to `curriculum.LessonGrading` tasks. It computes weighted grade averages and attendance percentages per student and supports sorting classroom rosters directly by either metric.

## Architecture Overview

```text
apps/classrooms/
├── models.py        # Classroom, Student, StudentClassroom, AttendanceSession, StudentAttendance, StudentGrade
├── permissions.py   # IsClassroomAdviserOrAdmin (restricts mutations to classroom adviser or Admin)
├── selectors.py     # QuerySets with two-step SQL annotations for `grade_average` and `attendance_average`
├── services.py      # Atomic classroom creation, batch enrollment, attendance recording, and grade submission
├── serializers.py   # Read/Write serializers plus batch input serializers
├── views.py         # ViewSets and custom actions (/students/, /enroll-students/, /record-attendance/, /submit-grades/)
└── urls.py          # ClassroomsRouter (ClassroomsRootView) mounted under /api/v1/classrooms/
```

## Data Model & Analytics

* **`Classroom`**: Represents a section or multigrade class (`name`, `school_name`, `section`, `school_year`, `is_active`), linked to an `adviser` (`Account`), multiple `GradeLevel`s, an active `LessonPlan`, and enrolled `Student`s via `StudentClassroom`.
* **`Student`**: Learner profile (`first_name`, `last_name`, `gender`, `lrn`, `grade_level`).
* **`AttendanceSession` & `StudentAttendance`**: Daily attendance log per classroom (`PRESENT`, `ABSENT`, `LATE`, `EXCUSED`), unique per `(classroom, date)` and `(session, student)`.
* **`StudentGrade`**: Numeric score per `(student, grading_task)` linked to `curriculum.LessonGrading`.

### Computed Averages (`selectors.py`)

* **`grade_average` (0–100%)**: Weighted percentage across graded tasks:
  $$
  \text{Grade Average} = \frac{\sum \left(\frac{\text{score}}{\text{max\_score}} \times 100 \times \text{grade\_weight}\right)}{\sum \text{grade\_weight}}
  $$
  When queried per classroom (via `/classrooms/{id}/students/` or `/students/?classroom={id}`), calculations are scoped to tasks under that classroom's active `lesson_plan` (if set).
* **`attendance_average` (0–100%)**: Percentage of sessions marked `PRESENT` or `LATE` out of total recorded sessions for that classroom.

## Permissions (`permissions.py`)

* **Read Access (`GET`, `HEAD`, `OPTIONS`)**: Any authenticated user.
* **Classroom Creation (`POST /api/v1/classrooms/classrooms/`)**: Any authenticated user (automatically sets `adviser = request.user` if omitted).
* **Classroom & Roster Mutations**: Restricted via `IsClassroomAdviserOrAdmin` to the classroom's assigned `adviser` or an `ADMIN`.

## API Endpoints (`/api/v1/classrooms/`)

| Method | Endpoint | Permission | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/classrooms/` | `IsAuthenticated` | Browsable `ClassroomsRootView` directory. |
| `GET, POST` | `/api/v1/classrooms/classrooms/` | `IsClassroomAdviserOrAdmin` | List (`?school_year=`, `?adviser=`, `?is_active=`, `?search=`) and create classrooms. |
| `GET, PATCH, DELETE` | `/api/v1/classrooms/classrooms/{id}/` | `IsClassroomAdviserOrAdmin` | Retrieve, update, or delete a classroom. |
| `GET` | `/api/v1/classrooms/classrooms/{id}/students/` | `IsAuthenticated` | Classroom roster with `grade_average` & `attendance_average`, sortable via `?ordering=`. |
| `POST` | `/api/v1/classrooms/classrooms/{id}/enroll-students/` | `IsClassroomAdviserOrAdmin` | Batch-enrolls existing students into the classroom. |
| `POST` | `/api/v1/classrooms/classrooms/{id}/record-attendance/` | `IsClassroomAdviserOrAdmin` | Upserts a daily `AttendanceSession` and student attendance statuses. |
| `POST` | `/api/v1/classrooms/classrooms/{id}/submit-grades/` | `IsClassroomAdviserOrAdmin` | Batch-submits or updates `StudentGrade` scores for enrolled students. |
| `GET, POST` | `/api/v1/classrooms/students/` | `IsAuthenticated` | Master student directory (`?classroom=`, `?grade_level=`, `?gender=`, `?search=`, `?ordering=`). |
| `GET` | `/api/v1/classrooms/attendance-sessions/` | `IsAuthenticated` | Read-only history of attendance sessions (`?classroom=`, `?date=`). |
| `GET, POST, PATCH` | `/api/v1/classrooms/student-grades/` | `IsClassroomAdviserOrAdmin` | Individual student grade records (`?student=`, `?grading_task=`). |

## Querying & Sorting Classroom Students

You can query students per classroom using either the nested classroom action (`GET /api/v1/classrooms/classrooms/{id}/students/`) or the filtered student endpoint (`GET /api/v1/classrooms/students/?classroom={id}`).

Pass the `ordering` query parameter (with `NULL` averages always placed last on the nested endpoint):

* **Highest Grade Average first:** `?ordering=-grade_average`
* **Lowest Grade Average first:** `?ordering=grade_average`
* **Highest Attendance Average first:** `?ordering=-attendance_average`
* **Lowest Attendance Average first:** `?ordering=attendance_average`
* **Alphabetical (default):** `?ordering=last_name` or `?ordering=first_name`
* **Optional filters:** `?grade_level=1&search=Juan`

## Example Payloads (Sequential Setup Order)

### 1. Create Students (`POST /api/v1/classrooms/students/`)

```json
{
  "first_name": "Juan",
  "last_name": "Dela Cruz",
  "gender": "M",
  "lrn": "109876543210",
  "grade_level": 1
}
```

### 2. Create Classroom (`POST /api/v1/classrooms/classrooms/`)

```json
{
  "name": "Grades 1 & 2 Multigrade - Acacia",
  "school_name": "Pasig Elementary School",
  "section": "Acacia",
  "school_year": "2026-2027",
  "is_active": true,
  "grade_levels": [1, 2],
  "lesson_plan": 1
}
```

### 3. Enroll Students (`POST /api/v1/classrooms/classrooms/{classroom_id}/enroll-students/`)

```json
{
  "student_ids": [1, 2, 3]
}
```

### 4. Record Batch Attendance (`POST /api/v1/classrooms/classrooms/{classroom_id}/record-attendance/`)

```json
{
  "date": "2026-11-19",
  "remarks": "Morning multigrade session",
  "records": [
    { "student": 1, "status": "PRESENT" },
    { "student": 2, "status": "LATE", "notes": "Arrived 10 mins late due to rain" },
    { "student": 3, "status": "ABSENT", "notes": "Excused medical visit" }
  ]
}
```

### 5. Submit Batch Grades (`POST /api/v1/classrooms/classrooms/{classroom_id}/submit-grades/`)

```json
{
  "grades": [
    {
      "student": 1,
      "grading_task": 1,
      "score": "19.00",
      "feedback": "Excellent grouping of tens and ones."
    },
    {
      "student": 2,
      "grading_task": 1,
      "score": "16.50",
      "feedback": "Good effort; review numbers above 50."
    }
  ]
}
```