from django.db.models import (
    Case,
    Count,
    ExpressionWrapper,
    F,
    FloatField,
    Q,
    QuerySet,
    Sum,
    Value,
    When,
)
from .models import Classroom, Student, AttendanceSession


def get_classroom_queryset() -> QuerySet[Classroom]:
    return (
        Classroom.objects
        .select_related('adviser', 'lesson_plan')
        .prefetch_related('grade_levels', 'students__grade_level')
        .order_by('-created_at')
    )


def get_student_queryset(classroom: Classroom | None = None) -> QuerySet[Student]:
    """
    Returns Students annotated with `grade_average` (0-100 scale) and
    `attendance_average` (0-100 scale). When `classroom` is provided,
    attendance records are scoped to that classroom's sessions and grades
    are scoped to tasks belonging to that classroom's active lesson plan
    (if assigned), falling back to all student grades otherwise.
    """
    qs = Student.objects.select_related('grade_level')

    if classroom is not None:
        qs = qs.filter(enrollments__classroom=classroom)
        attendance_filter = Q(attendance_records__session__classroom=classroom)
        if classroom.lesson_plan_id:
            grade_filter = Q(
                grades__grading_task__lesson_grade_level__lp_id=classroom.lesson_plan_id
            )
        else:
            grade_filter = Q(grades__isnull=False)
    else:
        attendance_filter = Q(attendance_records__isnull=False)
        grade_filter = Q(grades__isnull=False)

    valid_grade_filter = grade_filter & Q(grades__grading_task__max_score__gt=0)

    # Step 1: Annotate intermediate aggregates onto the queryset
    qs = qs.annotate(
        _weighted_pct_sum=Sum(
            ExpressionWrapper(
                (F('grades__score') / F('grades__grading_task__max_score'))
                * Value(100.0)
                * F('grades__grading_task__grade_weight'),
                output_field=FloatField(),
            ),
            filter=valid_grade_filter,
        ),
        _weight_sum=Sum(
            F('grades__grading_task__grade_weight'),
            filter=valid_grade_filter,
        ),
        _attended_count=Count(
            'attendance_records',
            filter=attendance_filter & Q(attendance_records__status__in=['PRESENT', 'LATE']),
            distinct=True,
        ),
        _total_attendance_count=Count(
            'attendance_records',
            filter=attendance_filter,
            distinct=True,
        ),
    )

    # Step 2: Compute final averages referencing the Step 1 annotation aliases
    return qs.annotate(
        grade_average=Case(
            When(
                _weight_sum__gt=0,
                then=ExpressionWrapper(
                    F('_weighted_pct_sum') / F('_weight_sum'),
                    output_field=FloatField(),
                ),
            ),
            default=Value(None),
            output_field=FloatField(),
        ),
        attendance_average=Case(
            When(
                _total_attendance_count__gt=0,
                then=ExpressionWrapper(
                    (F('_attended_count') * Value(100.0)) / F('_total_attendance_count'),
                    output_field=FloatField(),
                ),
            ),
            default=Value(None),
            output_field=FloatField(),
        ),
    ).distinct()


def get_attendance_session_queryset() -> QuerySet[AttendanceSession]:
    return (
        AttendanceSession.objects
        .select_related('classroom')
        .prefetch_related('records__student__grade_level')
        .order_by('-date')
    )
