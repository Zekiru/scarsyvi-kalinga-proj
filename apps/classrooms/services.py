from django.db import transaction
from rest_framework.exceptions import ValidationError
from apps.accounts.models import Account
from .models import (
    Classroom,
    Student,
    StudentClassroom,
    AttendanceSession,
    StudentAttendance,
    StudentGrade,
)


@transaction.atomic
def create_classroom(creator: Account, validated_data: dict) -> Classroom:
    grade_levels = validated_data.pop('grade_levels', [])
    if not validated_data.get('adviser'):
        validated_data['adviser'] = creator

    classroom = Classroom.objects.create(**validated_data)
    if grade_levels:
        classroom.grade_levels.set(grade_levels)
    return classroom


@transaction.atomic
def enroll_students_in_classroom(classroom: Classroom, students: list[Student]) -> list[StudentClassroom]:
    enrollments = []
    for student in students:
        enrollment, _ = StudentClassroom.objects.get_or_create(
            classroom=classroom,
            student=student,
        )
        enrollments.append(enrollment)
    return enrollments


@transaction.atomic
def record_attendance_session(
    classroom: Classroom,
    session_date,
    records_data: list[dict],
    remarks: str | None = None,
) -> AttendanceSession:
    """
    Creates or updates an AttendanceSession for (classroom, date) and upserts
    StudentAttendance records for enrolled students in a single transaction.
    """
    enrolled_ids = set(
        StudentClassroom.objects.filter(classroom=classroom).values_list('student_id', flat=True)
    )

    session, _ = AttendanceSession.objects.update_or_create(
        classroom=classroom,
        date=session_date,
        defaults={'remarks': remarks},
    )

    for item in records_data:
        student = item['student']
        if student.student_id not in enrolled_ids:
            raise ValidationError(
                {'records': f"Student {student.student_id} ({student}) is not enrolled in this classroom."}
            )
        StudentAttendance.objects.update_or_create(
            session=session,
            student=student,
            defaults={
                'status': item.get('status', 'PRESENT'),
                'notes': item.get('notes'),
            },
        )

    return session


@transaction.atomic
def submit_student_grades(grades_data: list[dict], classroom: Classroom | None = None) -> list[StudentGrade]:
    """
    Atomically creates or updates StudentGrade entries. If `classroom` is passed,
    verifies each student is enrolled in that classroom.
    """
    enrolled_ids = None
    if classroom is not None:
        enrolled_ids = set(
            StudentClassroom.objects.filter(classroom=classroom).values_list('student_id', flat=True)
        )

    saved_grades = []
    for item in grades_data:
        student = item['student']
        grading_task = item['grading_task']

        if enrolled_ids is not None and student.student_id not in enrolled_ids:
            raise ValidationError(
                {'grades': f"Student {student.student_id} ({student}) is not enrolled in this classroom."}
            )

        if item['score'] > grading_task.max_score:
            raise ValidationError(
                {'grades': f"Score {item['score']} exceeds max_score ({grading_task.max_score}) for '{grading_task.task_name}'."}
            )

        grade_obj, _ = StudentGrade.objects.update_or_create(
            student=student,
            grading_task=grading_task,
            defaults={
                'score': item['score'],
                'feedback': item.get('feedback'),
            },
        )
        saved_grades.append(grade_obj)

    return saved_grades
