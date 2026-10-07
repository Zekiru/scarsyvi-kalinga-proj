from rest_framework import serializers
from django.db import transaction
from apps.curriculum.models import GradeLevel, LessonPlan
from .models import Classroom, Student


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
    """Nested student record within a classroom."""
    gl_id = serializers.IntegerField(source='grade_level_id')

    class Meta:
        model = Student
        fields = ['student_id', 'gl_id', 'first_name', 'last_name', 'gender', 'lrn']


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
    
    # Nested Write Field for Students
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
