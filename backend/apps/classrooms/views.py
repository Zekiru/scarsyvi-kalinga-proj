from django.db.models import F
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.accounts.models import Account
from .models import StudentGrade
from .permissions import IsClassroomAdviserOrAdmin
from .selectors import (
    get_classroom_queryset,
    get_student_queryset,
    get_attendance_session_queryset,
)
from .serializers import (
    ClassroomListSerializer,
    ClassroomDetailSerializer,
    ClassroomWriteSerializer,
    StudentSerializer,
    EnrollStudentsInputSerializer,
    AttendanceSessionSerializer,
    BatchAttendanceInputSerializer,
    StudentGradeSerializer,
    BatchGradeSubmitSerializer,
)
from .services import (
    create_classroom,
    enroll_students_in_classroom,
    record_attendance_session,
    submit_student_grades,
)


class ClassroomViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, IsClassroomAdviserOrAdmin]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['school_year', 'is_active', 'adviser', 'grade_levels']
    search_fields = ['name', 'school_name', 'section']
    ordering_fields = ['classroom_id', 'name', 'school_year', 'created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        return get_classroom_queryset().distinct()

    def get_serializer_class(self):
        if self.action == 'list':
            return ClassroomListSerializer
        if self.action in {'create', 'update', 'partial_update'}:
            return ClassroomWriteSerializer
        return ClassroomDetailSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        classroom = create_classroom(creator=request.user, validated_data=serializer.validated_data)
        output = ClassroomDetailSerializer(classroom, context={'request': request})
        return Response(output.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['get'], url_path='students')
    def students(self, request, pk=None):
        """
        Lists students enrolled in this classroom, annotated with `grade_average`
        and `attendance_average`.
        Supports sorting via `?ordering=`:
          - `grade_average` / `-grade_average`
          - `attendance_average` / `-attendance_average`
          - `last_name` / `-last_name`
          - `first_name` / `-first_name`
          - `student_id` / `-student_id`
        """
        classroom = self.get_object()
        qs = get_student_queryset(classroom=classroom)

        grade_level = request.query_params.get('grade_level')
        if grade_level:
            qs = qs.filter(grade_level_id=grade_level)

        search = request.query_params.get('search')
        if search:
            qs = qs.filter(first_name__icontains=search) | qs.filter(last_name__icontains=search)

        ordering_param = request.query_params.get('ordering', 'last_name')
        allowed_orderings = {
            'grade_average': F('grade_average').asc(nulls_last=True),
            '-grade_average': F('grade_average').desc(nulls_last=True),
            'attendance_average': F('attendance_average').asc(nulls_last=True),
            '-attendance_average': F('attendance_average').desc(nulls_last=True),
            'last_name': F('last_name').asc(),
            '-last_name': F('last_name').desc(),
            'first_name': F('first_name').asc(),
            '-first_name': F('first_name').desc(),
            'student_id': F('student_id').asc(),
            '-student_id': F('student_id').desc(),
        }

        if ordering_param not in allowed_orderings:
            raise ValidationError({
                'ordering': f"Invalid ordering field '{ordering_param}'. Allowed: {', '.join(allowed_orderings.keys())}"
            })

        qs = qs.order_by(allowed_orderings[ordering_param], 'last_name', 'first_name')
        serializer = StudentSerializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], url_path='enroll-students')
    def enroll_students(self, request, pk=None):
        classroom = self.get_object()
        serializer = EnrollStudentsInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        enroll_students_in_classroom(
            classroom=classroom,
            students=serializer.validated_data['student_ids'],
        )
        qs = get_student_queryset(classroom=classroom).order_by('last_name', 'first_name')
        return Response(StudentSerializer(qs, many=True).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], url_path='record-attendance')
    def record_attendance(self, request, pk=None):
        classroom = self.get_object()
        serializer = BatchAttendanceInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        session = record_attendance_session(
            classroom=classroom,
            session_date=serializer.validated_data['date'],
            records_data=serializer.validated_data['records'],
            remarks=serializer.validated_data.get('remarks'),
        )
        return Response(AttendanceSessionSerializer(session).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], url_path='submit-grades')
    def submit_grades(self, request, pk=None):
        classroom = self.get_object()
        serializer = BatchGradeSubmitSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        saved_grades = submit_student_grades(
            grades_data=serializer.validated_data['grades'],
            classroom=classroom,
        )
        return Response(StudentGradeSerializer(saved_grades, many=True).data, status=status.HTTP_201_CREATED)


class StudentViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['grade_level', 'gender']
    search_fields = ['first_name', 'last_name', 'lrn']
    ordering_fields = ['student_id', 'last_name', 'first_name', 'grade_average', 'attendance_average']
    ordering = ['last_name', 'first_name']

    def get_queryset(self):
        return get_student_queryset()

    def get_serializer_class(self):
        return StudentSerializer


class AttendanceSessionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = get_attendance_session_queryset()
    serializer_class = AttendanceSessionSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['classroom', 'date']
    ordering_fields = ['date', 'id']


class StudentGradeViewSet(viewsets.ModelViewSet):
    queryset = StudentGrade.objects.select_related('student', 'grading_task').order_by('-submitted_at')
    serializer_class = StudentGradeSerializer
    permission_classes = [IsAuthenticated, IsClassroomAdviserOrAdmin]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['student', 'grading_task', 'grading_task__lesson_grade_level__lp']
    ordering_fields = ['score', 'submitted_at']

    def perform_create(self, serializer):
        user = self.request.user
        if user.role == Account.Role.ADMIN or user.is_superuser:
            serializer.save()
            return

        student = serializer.validated_data['student']
        if not student.classrooms.filter(adviser_id=user.id).exists():
            raise PermissionDenied(
                "Only the classroom's adviser or an admin can submit grades for this student."
            )
        serializer.save()
