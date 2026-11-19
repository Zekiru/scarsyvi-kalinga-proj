from rest_framework.permissions import BasePermission, SAFE_METHODS
from apps.accounts.models import Account
from .models import LessonPlanForum, ForumThread, ForumPost


def is_forum_moderator(user, lesson_plan=None) -> bool:
    """
    Returns True if user is an ADMIN, CHECKER, superuser,
    or an assigned author of the linked LessonPlan.
    """
    if not user or not user.is_authenticated:
        return False
    if user.role in {Account.Role.ADMIN, Account.Role.CHECKER} or user.is_superuser:
        return True
    if lesson_plan is not None and lesson_plan.authors.filter(pk=user.pk).exists():
        return True
    return False


class IsAuthorOrForumModerator(BasePermission):
    """
    - Any authenticated user can read (SAFE_METHODS) and create threads/posts.
    - Updating/deleting a ForumThread or ForumPost is restricted to its author
      or a forum moderator.
    - Locking a LessonPlanForum is restricted to forum moderators.
    """
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        user = request.user
        if isinstance(obj, LessonPlanForum):
            return is_forum_moderator(user, obj.lesson_plan)

        if isinstance(obj, ForumThread):
            if obj.author_id == user.id:
                return True
            return is_forum_moderator(user, obj.forum.lesson_plan)

        if isinstance(obj, ForumPost):
            if obj.author_id == user.id:
                return True
            return is_forum_moderator(user, obj.thread.forum.lesson_plan)

        return False


class IsForumModeratorPermission(BasePermission):
    """Object-level permission strictly for moderation actions (pin, lock, hide)."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        if isinstance(obj, LessonPlanForum):
            return is_forum_moderator(request.user, obj.lesson_plan)
        if isinstance(obj, ForumThread):
            return is_forum_moderator(request.user, obj.forum.lesson_plan)
        if isinstance(obj, ForumPost):
            return is_forum_moderator(request.user, obj.thread.forum.lesson_plan)
        return False
