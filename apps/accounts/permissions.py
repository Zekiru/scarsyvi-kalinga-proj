from rest_framework.permissions import BasePermission, SAFE_METHODS
from .models import Account


class IsAdminRole(BasePermission):
    """Full access for Admins and superusers."""
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (user.role == Account.Role.ADMIN or user.is_superuser)
        )


class IsModeratorOrAdmin(BasePermission):
    """Used by forums for locking, pinning, and soft-hiding content."""
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (user.role in {Account.Role.MODERATOR, Account.Role.ADMIN} or user.is_superuser)
        )


class IsAuthorOrAdmin(BasePermission):
    """Used by curriculum for creating/editing lesson plans."""
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (user.role in {Account.Role.AUTHOR, Account.Role.ADMIN} or user.is_superuser)
        )


class IsCheckerOrAdmin(BasePermission):
    """Used by curriculum for quality-checking lesson plans."""
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (user.role in {Account.Role.CHECKER, Account.Role.ADMIN} or user.is_superuser)
        )


class IsOwnerOrModeratorOrAdmin(BasePermission):
    """
    Object-level permission for forums and classrooms:
    - Any authenticated user can read (SAFE_METHODS).
    - Object creator (author/adviser) or Moderator/Admin can edit/delete.
    """
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        user = request.user
        if user.role in {Account.Role.MODERATOR, Account.Role.ADMIN} or user.is_superuser:
            return True
        owner = getattr(obj, 'author', None) or getattr(obj, 'adviser', None)
        return owner == user
