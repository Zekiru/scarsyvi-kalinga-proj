from django.db.models import Count, Prefetch, Q, QuerySet
from apps.accounts.models import Account
from .models import LessonPlanForum, ForumThread, ForumPost


def _is_global_moderator(user: Account) -> bool:
    return bool(
        user
        and user.is_authenticated
        and (user.role in {Account.Role.ADMIN, Account.Role.CHECKER} or user.is_superuser)
    )


def get_forum_queryset() -> QuerySet[LessonPlanForum]:
    return (
        LessonPlanForum.objects
        .select_related('lesson_plan')
        .annotate(
            thread_count=Count('threads', filter=Q(threads__is_hidden=False), distinct=True)
        )
        .order_by('-updated_at')
    )


def get_thread_queryset(user: Account) -> QuerySet[ForumThread]:
    posts_qs = ForumPost.objects.select_related('author', 'parent_post__author').order_by('created_at')
    if not _is_global_moderator(user):
        posts_qs = posts_qs.filter(is_hidden=False)

    qs = (
        ForumThread.objects
        .select_related('forum__lesson_plan', 'author')
        .prefetch_related(Prefetch('posts', queryset=posts_qs))
        .annotate(
            post_count=Count('posts', filter=Q(posts__is_hidden=False), distinct=True)
        )
        .order_by('-is_pinned', '-created_at')
    )

    if not _is_global_moderator(user):
        qs = qs.filter(
            Q(is_hidden=False)
            | Q(author=user)
            | Q(forum__lesson_plan__authors=user)
        ).distinct()

    return qs


def get_post_queryset(user: Account) -> QuerySet[ForumPost]:
    qs = (
        ForumPost.objects
        .select_related('thread__forum__lesson_plan', 'author', 'parent_post__author')
        .order_by('created_at')
    )

    if not _is_global_moderator(user):
        qs = qs.filter(
            Q(is_hidden=False, thread__is_hidden=False)
            | Q(author=user)
            | Q(thread__forum__lesson_plan__authors=user)
        ).distinct()

    return qs
