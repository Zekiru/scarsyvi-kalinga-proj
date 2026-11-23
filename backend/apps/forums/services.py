from django.db import transaction
from rest_framework.exceptions import PermissionDenied, ValidationError
from apps.accounts.models import Account
from apps.curriculum.models import LessonPlan
from .models import LessonPlanForum, ForumThread, ForumPost
from .permissions import is_forum_moderator


@transaction.atomic
def get_or_create_forum_for_lesson_plan(lesson_plan: LessonPlan) -> tuple[LessonPlanForum, bool]:
    """Lazily initializes or retrieves the dedicated forum for a LessonPlan."""
    return LessonPlanForum.objects.get_or_create(lesson_plan=lesson_plan)


@transaction.atomic
def create_forum_thread(author: Account, validated_data: dict) -> ForumThread:
    forum: LessonPlanForum = validated_data['forum']
    if forum.is_locked and not is_forum_moderator(author, forum.lesson_plan):
        raise PermissionDenied("This lesson plan forum is locked; new threads cannot be created.")

    return ForumThread.objects.create(
        forum=forum,
        author=author,
        title=validated_data['title'],
        body=validated_data['body'],
    )


@transaction.atomic
def create_forum_post(author: Account, validated_data: dict) -> ForumPost:
    thread: ForumThread = validated_data['thread']
    parent_post: ForumPost | None = validated_data.get('parent_post')

    if thread.forum.is_locked and not is_forum_moderator(author, thread.forum.lesson_plan):
        raise PermissionDenied("This lesson plan forum is locked; new replies cannot be posted.")

    if thread.is_locked and not is_forum_moderator(author, thread.forum.lesson_plan):
        raise PermissionDenied("This discussion thread is locked.")

    if thread.is_hidden and not is_forum_moderator(author, thread.forum.lesson_plan):
        raise PermissionDenied("Cannot reply to a hidden thread.")

    if parent_post is not None and parent_post.thread_id != thread.thread_id:
        raise ValidationError({'parent_post': "Parent post must belong to the same thread."})

    return ForumPost.objects.create(
        thread=thread,
        author=author,
        parent_post=parent_post,
        content=validated_data['content'],
    )


@transaction.atomic
def update_thread_moderation(
    thread: ForumThread,
    *,
    is_pinned: bool | None = None,
    is_locked: bool | None = None,
    is_hidden: bool | None = None,
) -> ForumThread:
    update_fields = ['updated_at']
    if is_pinned is not None:
        thread.is_pinned = is_pinned
        update_fields.append('is_pinned')
    if is_locked is not None:
        thread.is_locked = is_locked
        update_fields.append('is_locked')
    if is_hidden is not None:
        thread.is_hidden = is_hidden
        update_fields.append('is_hidden')

    thread.save(update_fields=update_fields)
    return thread
