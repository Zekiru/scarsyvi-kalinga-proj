from rest_framework.permissions import BasePermission, SAFE_METHODS
from apps.accounts.models import Account


def resolve_lesson_plan(obj):
    """Resolves LessonPlan from itself or any nested curriculum child model."""
    if hasattr(obj, "authors"):  # LessonPlan
        return obj
    if hasattr(obj, "lp"):  # LessonGradeLevel
        return obj.lp
    if getattr(obj, "lesson_grade_level", None) is not None:
        # LessonFlow, LessonGrading, LessonGradeMaterial
        return obj.lesson_grade_level.lp
    return None


def is_lesson_plan_editor(user, lp) -> bool:
    if not user or not user.is_authenticated:
        return False
    if user.role == Account.Role.ADMIN or user.is_superuser:
        return True
    # LessonPlan.authors is ManyToManyField to Account (through LpAuthor)
    return lp.authors.filter(pk=user.pk).exists()


class IsCurriculumEditorOrReadOnly(BasePermission):
    """
    - Any authenticated user can read (SAFE_METHODS) and create (POST) lesson plans.
    - Object-level updates/deletes on a LessonPlan or its child entities are restricted
      to its assigned authors or Admins.
    """

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        user = request.user
        if user.role == Account.Role.ADMIN or user.is_superuser:
            return True

        lp = resolve_lesson_plan(obj)
        if lp is not None:
            return lp.authors.filter(pk=user.pk).exists()

        # Master reference tables (GradeLevel, Material): allow creation/edits, restrict deletion to Admin
        return request.method != "DELETE"
