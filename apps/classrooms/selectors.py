from django.db.models import (
    Case,
    Count,
    ExpressionWrapper,
    F,
    FloatField,
    OuterRef,
    Q,
    QuerySet,
    Subquery,
    Sum,
    Value,
    When,
)
from .models import Classroom, Student, AttendanceSession, StudentGrade


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
    `attendance_average` (0-100 scale). Uses Subqueries for grade sums
    so attendance JOINs never duplicate grade rows.
    """
    qs = Student.objects.select_related('grade_level')

    grade_qs = StudentGrade.objects.filter(
        student_id=OuterRef('pk'),
        grading_task__max_score__gt=0,
    ).filter(
        Q(student__grade_level__isnull=True)
        | Q(grading_task__lesson_grade_level__gl=OuterRef('grade_level'))
    )

    if classroom is not None:
        qs = qs.filter(enrollments__classroom=classroom)
        attendance_filter = Q(attendance_records__session__classroom=classroom)
        if classroom.lesson_plan_id:
            grade_qs = grade_qs.filter(
                grading_task__lesson_grade_level__lp_id=classroom.lesson_plan_id
            )
    else:
        attendance_filter = Q(attendance_records__isnull=False)

    weighted_pct_subquery = (
        grade_qs.values('student_id')
        .annotate(
            total=Sum(
                ExpressionWrapper(
                    (F('score') * Value(100.0) / F('grading_task__max_score'))
                    * F('grading_task__grade_weight'),
                    output_field=FloatField(),
                )
            )
        )
        .values('total')[:1]
    )

    weight_sum_subquery = (
        grade_qs.values('student_id')
        .annotate(
            total=Sum(
                F('grading_task__grade_weight'),
                output_field=FloatField(),
            )
        )
        .values('total')[:1]
    )

    unweighted_pct_subquery = (
        grade_qs.values('student_id')
        .annotate(
            total=Sum(
                ExpressionWrapper(
                    F('score') * Value(100.0) / F('grading_task__max_score'),
                    output_field=FloatField(),
                )
            )
        )
        .values('total')[:1]
    )

    grade_count_subquery = (
        grade_qs.values('student_id')
        .annotate(total=Count('pk'))
        .values('total')[:1]
    )

    qs = qs.annotate(
        _weighted_pct_sum=Subquery(weighted_pct_subquery, output_field=FloatField()),
        _weight_sum=Subquery(weight_sum_subquery, output_field=FloatField()),
        _unweighted_pct_sum=Subquery(unweighted_pct_subquery, output_field=FloatField()),
        _grade_count=Subquery(grade_count_subquery, output_field=FloatField()),
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

    return qs.annotate(
        grade_average=Case(
            When(
                _weight_sum__gt=0,
                then=ExpressionWrapper(
                    F('_weighted_pct_sum') / F('_weight_sum'),
                    output_field=FloatField(),
                ),
            ),
            When(
                _grade_count__gt=0,
                then=ExpressionWrapper(
                    F('_unweighted_pct_sum') / F('_grade_count'),
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
