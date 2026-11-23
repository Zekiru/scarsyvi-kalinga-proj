from django.contrib import admin
from .models import (
    Classroom,
    Student,
    StudentClassroom,
    AttendanceSession,
    StudentAttendance,
    StudentGrade,
)


# ==========================================
# INLINES
# ==========================================

class StudentClassroomInline(admin.TabularInline):
    model = StudentClassroom
    extra = 0
    fields = ('__str__', 'student')
    readonly_fields = ('__str__',)


class StudentAttendanceInline(admin.TabularInline):
    model = StudentAttendance
    extra = 0
    fields = ('student', 'status', 'notes')


class StudentGradeInline(admin.TabularInline):
    model = StudentGrade
    extra = 0
    fields = ('grading_task', 'score', 'feedback', 'submitted_at')
    readonly_fields = ('submitted_at',)


# ==========================================
# CORE & ASSOCIATIVE MODEL ADMINS
# ==========================================

@admin.register(Classroom)
class ClassroomAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'school_name', 'section', 'adviser', 'lesson_plan', 'is_active')
    list_filter = ('school_year', 'is_active', 'grade_levels')
    search_fields = ('name', 'school_name', 'adviser__username')
    filter_horizontal = ('grade_levels',)
    inlines = [StudentClassroomInline]


@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'lrn', 'gender', 'grade_level')
    list_filter = ('grade_level', 'gender')
    search_fields = ('first_name', 'last_name', 'lrn')
    inlines = [StudentGradeInline]


@admin.register(StudentClassroom)
class StudentClassroomAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'classroom', 'student')
    list_filter = ('classroom__school_year', 'classroom')
    search_fields = ('classroom__name', 'student__first_name', 'student__last_name', 'student__lrn')


@admin.register(AttendanceSession)
class AttendanceSessionAdmin(admin.ModelAdmin):
    list_display = ('classroom', 'date', 'remarks')
    list_filter = ('date', 'classroom')
    search_fields = ('classroom__name', 'remarks')
    inlines = [StudentAttendanceInline]


@admin.register(StudentAttendance)
class StudentAttendanceAdmin(admin.ModelAdmin):
    list_display = ('session', 'student', 'status', 'notes')
    list_filter = ('status', 'session__date', 'session__classroom')
    search_fields = ('student__first_name', 'student__last_name', 'session__classroom__name')


@admin.register(StudentGrade)
class StudentGradeAdmin(admin.ModelAdmin):
    list_display = ('student', 'grading_task', 'score', 'submitted_at')
    list_filter = ('grading_task__lesson_grade_level__gl',)
    search_fields = ('student__first_name', 'student__last_name', 'grading_task__task_name')
    readonly_fields = ('submitted_at',)
