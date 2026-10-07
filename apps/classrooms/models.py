from django.db import models
from django.contrib.auth import get_user_model
from apps.curriculum.models import GradeLevel, LessonPlan

User = get_user_model()


class Classroom(models.Model):
    classroom_id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=255, help_text="e.g., Grade 1 & 2 Multigrade Class")
    school_name = models.CharField(max_length=255)
    section = models.CharField(max_length=100, blank=True, null=True)
    school_year = models.CharField(max_length=20, help_text="e.g., 2026-2027")
    is_active = models.BooleanField(default=True)
    
    # Relationships
    adviser = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="classrooms")
    grade_levels = models.ManyToManyField(GradeLevel, related_name="classrooms")
    lesson_plan = models.ForeignKey(
        LessonPlan, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name="classrooms"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.name} ({self.school_year})"


class Student(models.Model):
    GENDER_CHOICES = [
        ('M', 'Male'),
        ('F', 'Female'),
    ]

    student_id = models.AutoField(primary_key=True)
    classroom = models.ForeignKey(Classroom, on_delete=models.CASCADE, related_name="students")
    grade_level = models.ForeignKey(GradeLevel, on_delete=models.CASCADE, related_name="students")
    
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES)
    lrn = models.CharField(max_length=12, blank=True, null=True, help_text="Learner Reference Number")

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.grade_level.grade_level_name})"


class AttendanceSession(models.Model):
    classroom = models.ForeignKey(Classroom, on_delete=models.CASCADE, related_name='attendance_sessions')
    date = models.DateField()
    remarks = models.TextField(blank=True, null=True)

    class Meta:
        unique_together = ('classroom', 'date')

class StudentAttendance(models.Model):
    STATUS_CHOICES = [
        ('PRESENT', 'Present'),
        ('ABSENT', 'Absent'),
        ('LATE', 'Late'),
        ('EXCUSED', 'Excused'),
    ]
    session = models.ForeignKey(AttendanceSession, on_delete=models.CASCADE, related_name='records')
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='attendance_records')
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='PRESENT')
    notes = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        unique_together = ('session', 'student')


class StudentGrade(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='grades')
    # Points to the specific grading task defined in the lesson plan
    grading_task = models.ForeignKey('curriculum.LessonGrading', on_delete=models.CASCADE, related_name='student_grades')
    score = models.DecimalField(max_digits=5, decimal_places=2)  # e.g., 8.50 / 10.00
    submitted_at = models.DateTimeField(auto_now_add=True)
    feedback = models.TextField(blank=True, null=True)

    class Meta:
        unique_together = ('student', 'grading_task')
