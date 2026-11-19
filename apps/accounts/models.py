from django.db import models
from django.contrib.auth.models import AbstractUser


class Account(AbstractUser):
    """Custom User model for teachers, authors, checkers, moderators, and administrators."""

    class Role(models.TextChoices):
        TEACHER = 'TEACHER', 'Teacher'
        AUTHOR = 'AUTHOR', 'Content Author'
        CHECKER = 'CHECKER', 'Quality Checker'
        MODERATOR = 'MODERATOR', 'Moderator'
        ADMIN = 'ADMIN', 'Administrator'

    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.TEACHER
    )

    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"

    @property
    def is_moderator_or_admin(self):
        return self.role in {self.Role.MODERATOR, self.Role.ADMIN} or self.is_superuser
        