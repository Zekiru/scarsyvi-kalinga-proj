from rest_framework import serializers
from apps.accounts.serializers import AccountSummarySerializer
from apps.curriculum.models import GradeLevel, LessonPlan, LessonGrading
from apps.curriculum.serializers import GradeLevelSerializer
from .models import (
    Classroom,
    Student,
    StudentClassroom,
    AttendanceSession,
    StudentAttendance,
    StudentGrade,
)


# ==========================================
# STUDENT & ROSTER SERIALIZERS
# ==========================================

class StudentSerializer(serializers.ModelSerializer):
    grade_level_detail = GradeLevelSerializer(source='grade_level', read_only=True)
    grade_average = serializers.SerializerMethodField()
    attendance_average = serializers.SerializerMethodField()

    class Meta:
        model = Student
        fields = (
            'student_id',
            'first_name',
            'last_name',
            'gender',
            'lrn',
            'grade_level',
            'grade_level_detail',
            'grade_average',
            'attendance_average',
        )

    def get_grade_average(self, obj):
        val = getattr(obj, 'grade_average', None)
        return round(val, 2) if val is not None else None

    def get_attendance_average(self, obj):
        val = getattr(obj, 'attendance_average', None)
        return round(val, 2) if val is not None else None


class EnrollStudentsInputSerializer(serializers.Serializer):
    student_ids = serializers.PrimaryKeyRelatedField(
        queryset=Student.objects.all(),
        many=True,
        allow_empty=False,
    )


# ==========================================
# CLASSROOM SERIALIZERS
# ==========================================

class ClassroomListSerializer(serializers.ModelSerializer):
    adviser = AccountSummarySerializer(read_only=True)
    grade_levels = GradeLevelSerializer(many=True, read_only=True)
    student_count = serializers.IntegerField(source='students.count', read_only=True)

    class Meta:
        model = Classroom
        fields = (
            'classroom_id',
            'name',
            'school_name',
            'section',
            'school_year',
            'is_active',
            'adviser',
            'grade_levels',
            'lesson_plan',
            'student_count',
            'created_at',
        )


class ClassroomDetailSerializer(ClassroomListSerializer):
    lesson_plan_title = serializers.CharField(source='lesson_plan.lp_title', read_only=True, default=None)

    class Meta(ClassroomListSerializer.Meta):
        fields = ClassroomListSerializer.Meta.fields + (
            'lesson_plan_title',
            'updated_at',
        )


class ClassroomWriteSerializer(serializers.ModelSerializer):
    grade_levels = serializers.PrimaryKeyRelatedField(
        queryset=GradeLevel.objects.all(),
        many=True,
        required=False,
    )
    lesson_plan = serializers.PrimaryKeyRelatedField(
        queryset=LessonPlan.objects.all(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = Classroom
        fields = (
            'classroom_id',
            'name',
            'school_name',
            'section',
            'school_year',
            'is_active',
            'adviser',
            'grade_levels',
            'lesson_plan',
        )


# ==========================================
# ATTENDANCE SERIALIZERS
# ==========================================

class StudentAttendanceSerializer(serializers.ModelSerializer):
    student_name = serializers.SerializerMethodField()

    class Meta:
        model = StudentAttendance
        fields = ('id', 'session', 'student', 'student_name', 'status', 'notes')

    def get_student_name(self, obj):
        return f"{obj.student.first_name} {obj.student.last_name}"


class AttendanceSessionSerializer(serializers.ModelSerializer):
    records = StudentAttendanceSerializer(many=True, read_only=True)

    class Meta:
        model = AttendanceSession
        fields = ('id', 'classroom', 'date', 'remarks', 'records')


class BatchAttendanceRecordItemSerializer(serializers.Serializer):
    student = serializers.PrimaryKeyRelatedField(queryset=Student.objects.all())
    status = serializers.ChoiceField(choices=StudentAttendance.STATUS_CHOICES, default='PRESENT')
    notes = serializers.CharField(max_length=255, required=False, allow_blank=True, allow_null=True)


class BatchAttendanceInputSerializer(serializers.Serializer):
    date = serializers.DateField()
    remarks = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    records = BatchAttendanceRecordItemSerializer(many=True, allow_empty=False)


# ==========================================
# GRADE SERIALIZERS
# ==========================================

class StudentGradeSerializer(serializers.ModelSerializer):
    student_name = serializers.SerializerMethodField()
    task_name = serializers.CharField(source='grading_task.task_name', read_only=True)
    max_score = serializers.IntegerField(source='grading_task.max_score', read_only=True)

    class Meta:
        model = StudentGrade
        fields = (
            'id',
            'student',
            'student_name',
            'grading_task',
            'task_name',
            'score',
            'max_score',
            'feedback',
            'submitted_at',
        )

    def get_student_name(self, obj):
        return f"{obj.student.first_name} {obj.student.last_name}"


class BatchGradeItemSerializer(serializers.Serializer):
    student = serializers.PrimaryKeyRelatedField(queryset=Student.objects.all())
    grading_task = serializers.PrimaryKeyRelatedField(queryset=LessonGrading.objects.all())
    score = serializers.DecimalField(max_digits=5, decimal_places=2, min_value=0)
    feedback = serializers.CharField(required=False, allow_blank=True, allow_null=True)


class BatchGradeSubmitSerializer(serializers.Serializer):
    grades = BatchGradeItemSerializer(many=True, allow_empty=False)
