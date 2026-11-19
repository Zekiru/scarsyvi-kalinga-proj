from django.db import models
from django.conf import settings
from apps.curriculum.models import LessonPlan


class LessonPlanForum(models.Model):
    """
    A dedicated forum workspace attached to a specific LessonPlan.
    Using OneToOneField allows on-demand creation ('get_or_create') for any LessonPlan
    without modifying existing LessonPlan creation serializers.
    """
    forum_id = models.AutoField(primary_key=True)
    lesson_plan = models.OneToOneField(
        LessonPlan,
        on_delete=models.CASCADE,
        related_name='forum'
    )
    is_locked = models.BooleanField(
        default=False,
        help_text="Moderators/Admins can lock the forum to prevent new threads or replies."
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'lesson_plan_forum'

    def __str__(self):
        return f"Forum: {self.lesson_plan.lp_title}"


class ForumThread(models.Model):
    """A specific discussion topic or collaboration proposal within a LessonPlanForum."""
    thread_id = models.AutoField(primary_key=True)
    forum = models.ForeignKey(
        LessonPlanForum,
        on_delete=models.CASCADE,
        related_name='threads'
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='forum_threads'
    )
    title = models.CharField(max_length=255)
    body = models.TextField()

    # Moderation flags
    is_pinned = models.BooleanField(default=False)
    is_locked = models.BooleanField(default=False)
    is_hidden = models.BooleanField(
        default=False,
        help_text="Soft-hide flag for moderators removing inappropriate content."
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'forum_thread'
        ordering = ['-is_pinned', '-created_at']

    def __str__(self):
        return f"[{self.forum.lesson_plan.lp_id}] {self.title}"


class ForumPost(models.Model):
    """Replies/comments within a ForumThread, supporting nested replies."""
    post_id = models.AutoField(primary_key=True)
    thread = models.ForeignKey(
        ForumThread,
        on_delete=models.CASCADE,
        related_name='posts'
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='forum_posts'
    )
    parent_post = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='replies',
        help_text="Optional reference if replying directly to another comment."
    )
    content = models.TextField()

    # Moderation flag
    is_hidden = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'forum_post'
        ordering = ['created_at']

    def __str__(self):
        author_name = self.author.username if self.author else "Deleted User"
        return f"Post #{self.post_id} by {author_name}"
