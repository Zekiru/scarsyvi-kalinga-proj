from django.contrib import admin
from .models import (
    Classroom,
    Student,
    StudentClassroom,
    AttendanceSession,
    StudentAttendance,
    StudentGrade
)


class StudentClassroomInline(admin.TabularInline):
    model = StudentClassroom
    extra = 0


class StudentAttendanceInline(admin.TabularInline):
    model = StudentAttendance
    extra = 0


class StudentGradeInline(admin.TabularInline):
    model = StudentGrade
    extra = 0


class ClassroomAdmin(admin.ModelAdmin):
    model = Classroom
    list_display = [
        'name',
        'school_name',
        'section',
        'school_year'
    ]
    inlines = [StudentClassroomInline]


class StudentAdmin(admin.ModelAdmin):
    model = Student
    inlines = [
        StudentClassroomInline,
        StudentGradeInline
    ]


class AttendanceAdmin(admin.ModelAdmin):
    model = AttendanceSession
    list_display = [
        'classroom',
        'date'
    ]
    ordering = ['-date']
    inlines = [StudentAttendanceInline]


admin.site.register(Classroom, ClassroomAdmin)
admin.site.register(Student, StudentAdmin)
admin.site.register(AttendanceSession, AttendanceAdmin)
