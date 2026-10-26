import django_filters
from django.db.models import (
    Count, Q, FloatField, IntegerField, ExpressionWrapper, Sum, Prefetch,
    OuterRef, Subquery,
)
from django.db.models.functions import Coalesce, NullIf, Cast
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.filters import OrderingFilter
from django_filters.rest_framework import DjangoFilterBackend

from .models import (
    Classroom, Student, StudentClassroom,
    AttendanceSession, StudentAttendance, StudentGrade,
)
from .serializers import (
    ClassroomSerializer,
    AttendanceSessionSerializer,
    StudentGradeBatchSerializer,
    StudentGradeReadSerializer,
    StudentSerializer,
)


# ---------------------------------------------------------------------
# Shared annotation helpers
# ---------------------------------------------------------------------

def _scalar_subquery(qs, aggregate, output_field):
    """Aggregate `qs` per student and return it as a single-value subquery."""
    return Subquery(
        qs.order_by().values('student').annotate(agg=aggregate).values('agg'),
        output_field=output_field,
    )


def performance_annotations(student_ref, classroom=None):
    """
    Build `attendance_rate` and `grade_avg` annotations for a student.

    student_ref : OuterRef pointing at the student pk of the queryset being annotated.
    classroom   : OuterRef / id to scope attendance to one classroom, or None for all.

    Subqueries are used (instead of joining attendance and grades together) so the
    two one-to-many joins can't multiply each other's rows and skew the sums.

    Attendance is classroom-scoped because a student can be enrolled in several
    classrooms, each with its own sessions. Grades are per student/grading task.
    """
    # --- Attendance rate -------------------------------------------------
    attendance = StudentAttendance.objects.filter(student=student_ref)
    if classroom is not None:
        attendance = attendance.filter(session__classroom=classroom)

    total_sessions = Coalesce(
        _scalar_subquery(attendance, Count('pk'), IntegerField()), 0
    )
    present_sessions = Coalesce(
        _scalar_subquery(attendance.filter(status='PRESENT'), Count('pk'), IntegerField()), 0
    )
    attendance_rate = Coalesce(
        ExpressionWrapper(
            Cast(present_sessions, FloatField()) * 100.0
            / NullIf(Cast(total_sessions, FloatField()), 0.0),
            output_field=FloatField(),
        ),
        100.0,  # 100% if no sessions have been logged yet
    )

    # --- Weighted grade average -----------------------------------------
    # (score / max_score * 100) * grade_weight, summed, divided by the sum of
    # weights of the tasks that actually have a recorded grade.
    grades = StudentGrade.objects.filter(student=student_ref)
    scored = Q(grading_task__max_score__gt=0)

    weighted_points = ExpressionWrapper(
        Cast('score', FloatField()) * 100.0
        / NullIf(Cast('grading_task__max_score', FloatField()), 0.0)
        * Cast('grading_task__grade_weight', FloatField()),
        output_field=FloatField(),
    )
    earned_points = _scalar_subquery(
        grades, Sum(weighted_points, filter=scored), FloatField()
    )
    recorded_weights = _scalar_subquery(
        grades,
        Sum(Cast('grading_task__grade_weight', FloatField()), filter=scored),
        FloatField(),
    )
    grade_avg = Coalesce(
        ExpressionWrapper(
            earned_points / NullIf(recorded_weights, 0.0),
            output_field=FloatField(),
        ),
        100.0,  # 100 if nothing has been graded yet
    )

    return {'attendance_rate': attendance_rate, 'grade_avg': grade_avg}


# Allowed values for ?student_ordering= on the classroom endpoints
ROSTER_ORDERING = {
    'last_name': 'student__last_name',
    'first_name': 'student__first_name',
    'attendance_rate': 'attendance_rate',
    'grade_avg': 'grade_avg',
}


def roster_ordering(param):
    desc = param.startswith('-')
    field = ROSTER_ORDERING.get(param.lstrip('-'), 'student__last_name')
    return [('-' if desc else '') + field, 'student__first_name']


# ---------------------------------------------------------------------
# Classrooms
# ---------------------------------------------------------------------

class ClassroomViewSet(viewsets.ModelViewSet):
    serializer_class = ClassroomSerializer

    def get_queryset(self):
        ordering = roster_ordering(
            self.request.query_params.get('student_ordering', 'last_name')
        )

        # Roster = this classroom's enrollments, annotated with stats scoped to
        # THIS classroom (attendance from its sessions only).
        enrollments_qs = (
            StudentClassroom.objects
            .select_related('student')
            .annotate(**performance_annotations(OuterRef('student'), OuterRef('classroom')))
            .order_by(*ordering)
        )

        return (
            Classroom.objects
            .select_related('lesson_plan')
            .prefetch_related('grade_levels', Prefetch('enrollments', queryset=enrollments_qs))
        )

    # Re-fetch after writes so the response includes the annotated roster stats.
    def perform_create(self, serializer):
        instance = serializer.save()
        serializer.instance = self.get_queryset().get(pk=instance.pk)

    def perform_update(self, serializer):
        instance = serializer.save()
        serializer.instance = self.get_queryset().get(pk=instance.pk)

    @action(detail=True, methods=['get', 'post'], url_path='attendance')
    def attendance(self, request, pk=None):
        classroom = self.get_object()

        if request.method == 'GET':
            sessions = (
                AttendanceSession.objects
                .filter(classroom=classroom)
                .prefetch_related('records__student')
                .order_by('-date')
            )
            serializer = AttendanceSessionSerializer(sessions, many=True)
            return Response(serializer.data)

        serializer = AttendanceSessionSerializer(
            data=request.data,
            context={'classroom': classroom}
        )
        if serializer.is_valid():
            session = serializer.save()
            return Response(
                {"message": f"Attendance logged successfully (Session ID: {session.id})"},
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['get', 'post'], url_path='grades')
    def grades(self, request, pk=None):
        classroom = self.get_object()

        if request.method == 'GET':
            grades = (
                StudentGrade.objects
                .filter(student__enrollments__classroom=classroom)
                .select_related('student', 'grading_task')
            )
            serializer = StudentGradeReadSerializer(grades, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)

        serializer = StudentGradeBatchSerializer(
            data=request.data,
            context={'classroom': classroom}
        )
        if serializer.is_valid():
            created_grades = serializer.save()
            return Response(
                {"message": f"Successfully processed {len(created_grades)} grade entries."},
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ---------------------------------------------------------------------
# Students
# ---------------------------------------------------------------------

class StudentFilter(django_filters.FilterSet):
    # Students are linked to classrooms via StudentClassroom, so filter through it.
    classroom = django_filters.NumberFilter(field_name='enrollments__classroom')

    class Meta:
        model = Student
        fields = ['classroom', 'gender', 'grade_level']


class StudentViewSet(viewsets.ModelViewSet):
    """
    Standalone ViewSet for flat querying/filtering of students across classrooms.
    With ?classroom=<id>, attendance_rate is scoped to that classroom's sessions;
    without it, attendance is calculated across all of the student's classrooms.
    """
    serializer_class = StudentSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_class = StudentFilter
    ordering_fields = ['last_name', 'first_name', 'attendance_rate', 'grade_avg']
    ordering = ['last_name']

    def get_queryset(self):
        classroom_id = self.request.query_params.get('classroom')
        try:
            classroom_id = int(classroom_id) if classroom_id else None
        except ValueError:
            classroom_id = None  # the filter backend will report the bad value

        return Student.objects.annotate(
            **performance_annotations(OuterRef('pk'), classroom_id)
        )
