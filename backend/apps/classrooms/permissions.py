from rest_framework.permissions import BasePermission, SAFE_METHODS
from apps.accounts.models import Account
from .models import Classroom, AttendanceSession, StudentGrade


class IsClassroomAdviserOrAdmin(BasePermission):
    """
    - Any authenticated user can read (SAFE_METHODS).
    - Creating classrooms is open to authenticated teachers/authors/admins.
    - Updating/deleting a classroom or recording enrollment/attendance/grades
      is restricted to the classroom's `adviser` or an `ADMIN`.
    """
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        user = request.user
        if user.role == Account.Role.ADMIN or user.is_superuser:
            return True

        if isinstance(obj, Classroom):
            return obj.adviser_id == user.id
        if isinstance(obj, AttendanceSession):
            return obj.classroom.adviser_id == user.id
        if isinstance(obj, StudentGrade):
            return obj.student.classrooms.filter(adviser_id=user.id).exists()
        if hasattr(obj, 'classroom'):
            return obj.classroom.adviser_id == user.id
        if hasattr(obj, 'session'):
            return obj.session.classroom.adviser_id == user.id

        return True
