from rest_framework import serializers
from django.db import transaction
from apps.curriculum.models import GradeLevel, LessonPlan, LessonGrading
from .models import (
    Classroom, Student, StudentClassroom,
    AttendanceSession, StudentAttendance, StudentGrade,
)


def _validate_enrolled(classroom, student_ids, field_name):
    """Ensure every student id is enrolled in `classroom`."""
    if classroom is None or not student_ids:
        return
    enrolled = set(
        StudentClassroom.objects
        .filter(classroom=classroom, student_id__in=student_ids)
        .values_list('student_id', flat=True)
    )
    missing = sorted(set(student_ids) - enrolled)
    if missing:
        raise serializers.ValidationError(
            {field_name: f"Students not enrolled in this classroom: {missing}"}
        )


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
    """
    Standalone student serializer (used by StudentViewSet).
    attendance_rate / grade_avg come from QuerySet annotations.
    Pass `classroom_ids` on write to set which classrooms the student is enrolled in.
    """
    student_id = serializers.IntegerField(read_only=True)
    gl_id = serializers.IntegerField(source='grade_level_id')
    classroom_ids = serializers.ListField(
        child=serializers.IntegerField(), write_only=True, required=False
    )

    attendance_rate = serializers.FloatField(read_only=True, default=0.0)
    grade_avg = serializers.FloatField(read_only=True, default=0.0)

    class Meta:
        model = Student
        fields = [
            'student_id', 'gl_id', 'first_name', 'last_name', 'gender', 'lrn',
            'classroom_ids', 'attendance_rate', 'grade_avg',
        ]

    def validate_gl_id(self, value):
        if not GradeLevel.objects.filter(pk=value).exists():
            raise serializers.ValidationError("Grade level does not exist.")
        return value

    def validate_classroom_ids(self, value):
        found = set(Classroom.objects.filter(pk__in=value).values_list('pk', flat=True))
        missing = sorted(set(value) - found)
        if missing:
            raise serializers.ValidationError(f"Classrooms do not exist: {missing}")
        return value

    @transaction.atomic
    def create(self, validated_data):
        classroom_ids = validated_data.pop('classroom_ids', [])
        student = Student.objects.create(**validated_data)
        StudentClassroom.objects.bulk_create(
            [StudentClassroom(classroom_id=cid, student=student) for cid in set(classroom_ids)]
        )
        return student

    @transaction.atomic
    def update(self, instance, validated_data):
        classroom_ids = validated_data.pop('classroom_ids', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if classroom_ids is not None:
            wanted = set(classroom_ids)
            instance.enrollments.exclude(classroom_id__in=wanted).delete()
            have = set(instance.enrollments.values_list('classroom_id', flat=True))
            StudentClassroom.objects.bulk_create(
                [StudentClassroom(classroom_id=cid, student=instance) for cid in wanted - have]
            )
        return instance


class RosterEntrySerializer(serializers.Serializer):
    """
    One student inside a classroom roster. Reads from a StudentClassroom
    (enrollment) instance; writes plain student data.
    - student_id given  -> update that existing student and enroll them
    - student_id absent -> create a new student and enroll them
    """
    student_id = serializers.IntegerField(required=False, allow_null=True)
    gl_id = serializers.IntegerField()
    first_name = serializers.CharField(max_length=100)
    last_name = serializers.CharField(max_length=100)
    gender = serializers.ChoiceField(choices=Student.GENDER_CHOICES)
    lrn = serializers.CharField(max_length=12, required=False, allow_null=True, allow_blank=True)

    attendance_rate = serializers.FloatField(read_only=True)
    grade_avg = serializers.FloatField(read_only=True)

    def validate_gl_id(self, value):
        if not GradeLevel.objects.filter(pk=value).exists():
            raise serializers.ValidationError("Grade level does not exist.")
        return value

    def to_representation(self, enrollment):
        student = enrollment.student
        return {
            'student_id': student.student_id,
            'gl_id': student.grade_level_id,
            'first_name': student.first_name,
            'last_name': student.last_name,
            'gender': student.gender,
            'lrn': student.lrn,
            # Annotated per classroom by the view; fall back to 100 if not annotated
            'attendance_rate': getattr(enrollment, 'attendance_rate', 100.0),
            'grade_avg': getattr(enrollment, 'grade_avg', 100.0),
        }


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

    # Roster comes from the enrollment (StudentClassroom) rows
    students = RosterEntrySerializer(many=True, required=False, source='enrollments')

    # Read-only expansion details
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
        roster = validated_data.pop('enrollments', [])

        classroom = Classroom.objects.create(**validated_data)
        classroom.grade_levels.set(grade_level_ids)

        self._sync_roster(classroom, roster)
        return classroom

    @transaction.atomic
    def update(self, instance, validated_data):
        grade_level_ids = validated_data.pop('grade_level_ids', None)
        roster = validated_data.pop('enrollments', None)

        # lesson_plan_id is a plain attribute; sending null clears it
        if 'lesson_plan_id' in validated_data:
            instance.lesson_plan_id = validated_data.pop('lesson_plan_id')

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if grade_level_ids is not None:
            instance.grade_levels.set(grade_level_ids)

        if roster is not None:
            kept_ids = self._sync_roster(instance, roster)
            # Un-enroll students missing from the payload. The Student rows
            # themselves are kept (they may belong to other classrooms).
            StudentClassroom.objects.filter(classroom=instance).exclude(
                student_id__in=kept_ids
            ).delete()

        return instance

    def _sync_roster(self, classroom, roster):
        """Create/update students and make sure each is enrolled. Returns the ids kept."""
        kept_ids = set()

        for entry in roster:
            entry = dict(entry)
            student_id = entry.pop('student_id', None)
            gl_id = entry.pop('gl_id')

            if student_id:
                try:
                    student = Student.objects.get(pk=student_id)
                except Student.DoesNotExist:
                    raise serializers.ValidationError(
                        {'students': f"Student {student_id} does not exist."}
                    )
                student.grade_level_id = gl_id
                for attr, value in entry.items():
                    setattr(student, attr, value)
                student.save()
            else:
                student = Student.objects.create(grade_level_id=gl_id, **entry)

            StudentClassroom.objects.get_or_create(classroom=classroom, student=student)
            kept_ids.add(student.pk)

        return kept_ids


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

    def validate_records(self, value):
        classroom = self.context.get('classroom')
        ids = [r['student']['student_id'] for r in value]
        if len(ids) != len(set(ids)):
            raise serializers.ValidationError("Duplicate students in attendance records.")
        _validate_enrolled(classroom, ids, 'records')
        return value

    @transaction.atomic
    def create(self, validated_data):
        records_data = validated_data.pop('records', [])
        classroom = self.context.get('classroom')
        session_date = validated_data.get('date')

        # Upsert the AttendanceSession for this classroom and date
        session, _ = AttendanceSession.objects.update_or_create(
            classroom=classroom,
            date=session_date,
            defaults={'remarks': validated_data.get('remarks', '')}
        )

        # Upsert individual student attendance records for this session
        for record_data in records_data:
            student_id = record_data['student']['student_id']
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

    def validate_grades(self, value):
        classroom = self.context.get('classroom')

        _validate_enrolled(classroom, [g['student_id'] for g in value], 'grades')

        task_ids = {g['grading_task_id'] for g in value}
        found = set(LessonGrading.objects.filter(pk__in=task_ids).values_list('pk', flat=True))
        missing = sorted(task_ids - found)
        if missing:
            raise serializers.ValidationError(f"Grading tasks do not exist: {missing}")
        return value

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
    student_id = serializers.IntegerField(source='student.student_id', read_only=True)
    student_name = serializers.SerializerMethodField()
    grading_task_title = serializers.CharField(source='grading_task.task_name', read_only=True)

    class Meta:
        model = StudentGrade
        fields = ['id', 'student_id', 'student_name', 'grading_task_id', 'grading_task_title', 'score', 'feedback', 'submitted_at']

    def get_student_name(self, obj):
        return f"{obj.student.first_name} {obj.student.last_name}"
