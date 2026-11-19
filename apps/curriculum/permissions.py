from rest_framework.permissions import BasePermission, SAFE_METHODS
from apps.accounts.models import Account


class IsCurriculumEditorOrReadOnly(BasePermission):
    """
    - Any authenticated user can read (SAFE_METHODS).
    - Creating/modifying curriculum records requires AUTHOR or ADMIN role.
    - Object-level updates/deletes on a LessonPlan are restricted to its assigned authors or Admins.
    """
    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return bool(request.user and request.user.is_authenticated)

        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (user.role in {Account.Role.AUTHOR, Account.Role.ADMIN} or user.is_superuser)
        )

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        user = request.user
        if user.role == Account.Role.ADMIN or user.is_superuser:
            return True

        # Check ownership on LessonPlan or nested LessonGradeLevel
        lp = getattr(obj, 'lp', obj)
        if hasattr(lp, 'authors'):
            return lp.authors.filter(pk=user.pk).exists()
        return True
