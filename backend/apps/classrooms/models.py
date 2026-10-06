from django.db import models
from django.conf import settings
from apps.curriculum.models import LessonPlan, GradeLevel, LessonGrading


class Student(models.Model):
    """Student master profiles."""
    student_id = models.AutoField(primary_key=True)
    student_fname = models.CharField(max_length=100)
    student_lname = models.CharField(max_length=100)
    student_mi = models.CharField(max_length=5, blank=True, null=True)
    gl = models.ForeignKey(GradeLevel, on_delete=models.PROTECT, related_name='students')

    class Meta:
        db_table = 'student'

    def __str__(self):
        return f"{self.student_lname}, {self.student_fname} ({self.gl.grade_level_name})"


class Class(models.Model):
    """Active multi-grade classroom session taught by a teacher."""
    class_id = models.AutoField(primary_key=True)
    lp = models.ForeignKey(LessonPlan, on_delete=models.SET_NULL, null=True, related_name='classes')
    teacher = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='taught_classes')
    class_name = models.CharField(max_length=255)
    school_location = models.CharField(max_length=255)
    term = models.CharField(max_length=50)
    start_date = models.DateField()
    end_date = models.DateField()
    session_time = models.CharField(max_length=100)

    students = models.ManyToManyField(
        Student,
        through='StudentClass',
        related_name='enrolled_classes'
    )

    class Meta:
        db_table = 'class'
        verbose_name_plural = 'Classes'

    def __str__(self):
        return f"{self.class_name} - {self.school_location}"


class StudentClass(models.Model):
    """Junction table for Student Enrollment & Attendance records."""
    student_class_id = models.AutoField(primary_key=True)
    clazz = models.ForeignKey(Class, on_delete=models.CASCADE)
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    days_absent = models.IntegerField(default=0)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        db_table = 'student_class'
        unique_together = (('clazz', 'student'),)

    def __str__(self):
        return f"{self.student} in {self.clazz.class_name}"


class StudentGrading(models.Model):
    """Assessment grades linked directly to student classroom enrollment."""
    sg_id = models.AutoField(primary_key=True)
    lg = models.ForeignKey(LessonGrading, on_delete=models.CASCADE, related_name='student_scores')
    student_class = models.ForeignKey(StudentClass, on_delete=models.CASCADE, related_name='grades')
    total_score = models.DecimalField(max_digits=5, decimal_places=2)

    class Meta:
        db_table = 'student_grading'
        unique_together = (('lg', 'student_class'),)

    def __str__(self):
        return f"Score: {self.total_score} - {self.student_class.student} ({self.lg.task_name})"
