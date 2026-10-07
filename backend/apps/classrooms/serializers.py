from rest_framework import serializers
from django.db import transaction
from apps.curriculum.models import GradeLevel, LessonPlan, LessonGrading
from .models import Classroom, Student, AttendanceSession, StudentAttendance, StudentGrade


class GradeLevelSerializer(serializers.ModelSerializer):
    """Standalone serializer for Grade Level details."""
    class Meta:
        model = GradeLevel
        fields = '__all__'


class LessonPlanReadSerializer(serializers.ModelSerializer):
    """Minimal read-only serializer for linked lesson plans."""
    class Meta:
        model = LessonPlan
        fields = [
            'lp_id', 'lp_title', 'learning_area', 
            'primary_language', 'suggested_demographic'
        ]


class StudentSerializer(serializers.ModelSerializer):
    """Nested student record within a classroom with optional aggregate metrics."""
    gl_id = serializers.IntegerField(source='grade_level_id')
    
    # Read-only float fields populated by QuerySet annotations
    attendance_rate = serializers.FloatField(read_only=True, default=0.0)
    grade_avg = serializers.FloatField(read_only=True, default=0.0)

    class Meta:
        model = Student
        fields = [
            'student_id', 
            'gl_id', 
            'first_name', 
            'last_name', 
            'gender', 
            'lrn', 
            'attendance_rate', 
            'grade_avg'
        ]


class ClassroomSerializer(serializers.ModelSerializer):
    """Full nested read/write serializer for Classrooms."""
    grade_level_ids = serializers.ListField(
        child=serializers.IntegerField(), 
        write_only=True
    )
    lesson_plan_id = serializers.IntegerField(
        write_only=True, 
        required=False, 
        allow_null=True
    )
    
    # Nested Write/Read Field for Students
    students = StudentSerializer(many=True, required=False)

    # Read-only Expansion details
    grade_levels = GradeLevelSerializer(many=True, read_only=True)
    lesson_plan = LessonPlanReadSerializer(read_only=True)

    class Meta:
        model = Classroom
        fields = [
            'classroom_id', 'name', 'school_name', 'section', 'school_year',
            'is_active', 'adviser', 'lesson_plan_id', 'grade_level_ids',
            'lesson_plan', 'grade_levels', 'students'
        ]

    def validate_grade_level_ids(self, value):
        if not value:
            raise serializers.ValidationError("At least one grade level must be assigned to a classroom.")
        return value

    @transaction.atomic
    def create(self, validated_data):
        grade_level_ids = validated_data.pop('grade_level_ids', [])
        lesson_plan_id = validated_data.pop('lesson_plan_id', None)
        students_data = validated_data.pop('students', [])

        if lesson_plan_id:
            validated_data['lesson_plan_id'] = lesson_plan_id

        classroom = Classroom.objects.create(**validated_data)
        classroom.grade_levels.set(grade_level_ids)

        self._save_students(classroom, students_data)

        return classroom

    @transaction.atomic
    def update(self, instance, validated_data):
        grade_level_ids = validated_data.pop('grade_level_ids', None)
        lesson_plan_id = validated_data.pop('lesson_plan_id', None)
        students_data = validated_data.pop('students', None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if lesson_plan_id is not None:
            instance.lesson_plan_id = lesson_plan_id

        instance.save()

        if grade_level_ids is not None:
            instance.grade_levels.set(grade_level_ids)

        if students_data is not None:
            instance.students.all().delete()
            self._save_students(instance, students_data)

        return instance

    def _save_students(self, classroom, students_data):
        for student_item in students_data:
            gl_id = student_item.pop('grade_level_id')
            Student.objects.create(
                classroom=classroom,
                grade_level_id=gl_id,
                **student_item
            )


# =====================================================================
# Attendance and Grading Serializers
# =====================================================================

class StudentAttendanceSerializer(serializers.ModelSerializer):
    """Serializer for individual student attendance entries."""
    student_id = serializers.IntegerField(source='student.student_id')

    class Meta:
        model = StudentAttendance
        fields = ['student_id', 'status', 'notes']


class AttendanceSessionSerializer(serializers.ModelSerializer):
    """Batch serializer for daily classroom attendance logging (supports updates)."""
    records = StudentAttendanceSerializer(many=True)

    class Meta:
        model = AttendanceSession
        fields = ['id', 'date', 'remarks', 'records']

    @transaction.atomic
    def create(self, validated_data):
        records_data = validated_data.pop('records', [])
        classroom = self.context.get('classroom')
        session_date = validated_data.get('date')

        # Upsert the AttendanceSession for this classroom and date
        session, _ = AttendanceSession.objects.update_or_create(
            classroom=classroom,
            date=session_date,
            defaults={
                'remarks': validated_data.get('remarks', '')
            }
        )

        # Upsert individual student attendance records for this session
        for record_data in records_data:
            student_dict = record_data.pop('student')
            student_id = student_dict['student_id']

            StudentAttendance.objects.update_or_create(
                session=session,
                student_id=student_id,
                defaults={
                    'status': record_data.get('status', 'PRESENT'),
                    'notes': record_data.get('notes', '')
                }
            )

        return session


class SingleGradeItemSerializer(serializers.Serializer):
    """Write schema for scoring an individual student against a LessonGrading task."""
    student_id = serializers.IntegerField()
    grading_task_id = serializers.IntegerField()
    score = serializers.DecimalField(max_digits=5, decimal_places=2)
    feedback = serializers.CharField(required=False, allow_blank=True, default="")


class StudentGradeBatchSerializer(serializers.Serializer):
    """Batch serializer for submitting multiple student grades at once."""
    grades = SingleGradeItemSerializer(many=True)

    @transaction.atomic
    def create(self, validated_data):
        grades_data = validated_data.get('grades', [])
        created_grades = []

        for item in grades_data:
            grade_obj, _ = StudentGrade.objects.update_or_create(
                student_id=item['student_id'],
                grading_task_id=item['grading_task_id'],
                defaults={
                    'score': item['score'],
                    'feedback': item.get('feedback', '')
                }
            )
            created_grades.append(grade_obj)

        return created_grades


class StudentGradeReadSerializer(serializers.ModelSerializer):
    """Read serializer for returning student grades."""
    student_id = serializers.IntegerField(source='student.student_id')
    student_name = serializers.CharField(source='student.first_name', read_only=True)
    grading_task_title = serializers.CharField(source='grading_task.task_name', read_only=True)

    class Meta:
        model = StudentGrade
        fields = ['id', 'student_id', 'student_name', 'grading_task_id', 'grading_task_title', 'score', 'feedback', 'submitted_at']
