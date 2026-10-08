from django.db.models import Count, Q, FloatField, ExpressionWrapper, F, Sum, Prefetch
from django.db.models.functions import Coalesce, NullIf
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.filters import OrderingFilter
from django_filters.rest_framework import DjangoFilterBackend

from .models import Classroom, AttendanceSession, StudentGrade, Student
from .serializers import (
    ClassroomSerializer,
    AttendanceSessionSerializer,
    StudentGradeBatchSerializer,
    StudentGradeReadSerializer,
    StudentSerializer
)


class ClassroomViewSet(viewsets.ModelViewSet):
    serializer_class = ClassroomSerializer

    def get_queryset(self):
        ordering = self.request.query_params.get('student_ordering', 'last_name')

        # Build annotated Student QuerySet matching exact LessonGrading field names
        students_qs = Student.objects.annotate(
            # 1. Attendance Rate Calculation
            total_sessions=Count('attendance_records__session', distinct=True),
            present_sessions=Count(
                'attendance_records',
                filter=Q(attendance_records__status='PRESENT'),
                distinct=True
            )
        ).annotate(
            # Wrapped denominator in NullIf to prevent 0 division when no sessions exist
            attendance_rate=Coalesce(
                ExpressionWrapper(
                    (F('present_sessions') * 100.0) / NullIf(F('total_sessions'), 0),
                    output_field=FloatField()
                ),
                100.0  # Defaults to 100% attendance if no sessions logged yet
            ),

            # 2. Recorded Weighted Grades Calculation (score / max_score * grade_weight)
            # Wrapped max_score in NullIf to prevent 0 division if max_score is 0
            total_earned_points=Sum(
                ExpressionWrapper(
                    (F('grades__score') * 100.0 / NullIf(F('grades__grading_task__max_score'), 0))
                    * F('grades__grading_task__grade_weight'),
                    output_field=FloatField()
                )
            ),
            total_recorded_weights=Sum(
                ExpressionWrapper(
                    F('grades__grading_task__grade_weight'),
                    output_field=FloatField()
                )
            )
        ).annotate(
            # Grade Average: Earned Weighted Points / Recorded Task Weights
            # Wrapped total_recorded_weights in NullIf to prevent 0 division when no grades logged
            grade_avg=Coalesce(
                ExpressionWrapper(
                    F('total_earned_points') / NullIf(F('total_recorded_weights'), 0),
                    output_field=FloatField()
                ),
                100.0
            )
        ).order_by(ordering)

        return Classroom.objects.prefetch_related(
            Prefetch('students', queryset=students_qs)
        )

    @action(detail=True, methods=['get', 'post'], url_path='attendance')
    def attendance(self, request, pk=None):
        classroom = self.get_object()

        if request.method == 'GET':
            sessions = AttendanceSession.objects.filter(classroom=classroom)
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
            grades = StudentGrade.objects.filter(student__classroom=classroom)
            serializer = StudentGradeReadSerializer(grades, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)

        elif request.method == 'POST':
            serializer = StudentGradeBatchSerializer(data=request.data)
            if serializer.is_valid():
                created_grades = serializer.save()
                return Response(
                    {"message": f"Successfully processed {len(created_grades)} grade entries."}, 
                    status=status.HTTP_201_CREATED
                )
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class StudentViewSet(viewsets.ModelViewSet):
    """
    Standalone ViewSet for flat querying/filtering of students across classrooms.
    """
    serializer_class = StudentSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['classroom', 'gender']
    ordering_fields = ['last_name', 'first_name', 'attendance_rate', 'grade_avg']
    ordering = ['last_name']

    def get_queryset(self):
        queryset = Student.objects.all()

        queryset = queryset.annotate(
            total_sessions=Count('attendance_records__session', distinct=True),
            present_sessions=Count(
                'attendance_records',
                filter=Q(attendance_records__status='PRESENT'),
                distinct=True
            )
        ).annotate(
            attendance_rate=Coalesce(
                ExpressionWrapper(
                    (F('present_sessions') * 100.0) / NullIf(F('total_sessions'), 0),
                    output_field=FloatField()
                ),
                100.0
            ),
            total_earned_points=Sum(
                ExpressionWrapper(
                    (F('grades__score') * 100.0 / NullIf(F('grades__grading_task__max_score'), 0))
                    * F('grades__grading_task__grade_weight'),
                    output_field=FloatField()
                )
            ),
            total_recorded_weights=Sum(
                ExpressionWrapper(
                    F('grades__grading_task__grade_weight'),
                    output_field=FloatField()
                )
            )
        ).annotate(
            grade_avg=Coalesce(
                ExpressionWrapper(
                    F('total_earned_points') / NullIf(F('total_recorded_weights'), 0),
                    output_field=FloatField()
                ),
                100.0
            )
        )

        return queryset
