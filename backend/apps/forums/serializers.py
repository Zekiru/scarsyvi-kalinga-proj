from rest_framework import serializers
from apps.accounts.serializers import AccountSummarySerializer
from apps.curriculum.models import LessonPlan
from .models import LessonPlanForum, ForumThread, ForumPost


# ==========================================
# FORUM SERIALIZERS
# ==========================================

class LessonPlanForumSerializer(serializers.ModelSerializer):
    lesson_plan_title = serializers.CharField(source='lesson_plan.lp_title', read_only=True)
    thread_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = LessonPlanForum
        fields = (
            'forum_id',
            'lesson_plan',
            'lesson_plan_title',
            'is_locked',
            'thread_count',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('forum_id', 'created_at', 'updated_at')


class ForumByLessonPlanInputSerializer(serializers.Serializer):
    lesson_plan_id = serializers.PrimaryKeyRelatedField(
        queryset=LessonPlan.objects.all(),
        source='lesson_plan',
    )


# ==========================================
# POST SERIALIZERS
# ==========================================

class ForumPostSerializer(serializers.ModelSerializer):
    author = AccountSummarySerializer(read_only=True)
    parent_author_username = serializers.SerializerMethodField()

    class Meta:
        model = ForumPost
        fields = (
            'post_id',
            'thread',
            'author',
            'parent_post',
            'parent_author_username',
            'content',
            'is_hidden',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('post_id', 'author', 'is_hidden', 'created_at', 'updated_at')

    def get_parent_author_username(self, obj):
        if obj.parent_post and obj.parent_post.author:
            return obj.parent_post.author.username
        return None


class ForumPostUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ForumPost
        fields = ('content',)


# ==========================================
# THREAD SERIALIZERS
# ==========================================

class ForumThreadListSerializer(serializers.ModelSerializer):
    author = AccountSummarySerializer(read_only=True)
    lesson_plan_id = serializers.IntegerField(source='forum.lesson_plan_id', read_only=True)
    lesson_plan_title = serializers.CharField(source='forum.lesson_plan.lp_title', read_only=True)
    post_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = ForumThread
        fields = (
            'thread_id',
            'forum',
            'lesson_plan_id',
            'lesson_plan_title',
            'author',
            'title',
            'body',
            'is_pinned',
            'is_locked',
            'is_hidden',
            'post_count',
            'created_at',
            'updated_at',
        )
        read_only_fields = (
            'thread_id',
            'author',
            'is_pinned',
            'is_locked',
            'is_hidden',
            'created_at',
            'updated_at',
        )


class ForumThreadDetailSerializer(ForumThreadListSerializer):
    posts = ForumPostSerializer(many=True, read_only=True)

    class Meta(ForumThreadListSerializer.Meta):
        fields = ForumThreadListSerializer.Meta.fields + ('posts',)


class ForumThreadWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = ForumThread
        fields = ('thread_id', 'forum', 'title', 'body')


class ForumThreadUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ForumThread
        fields = ('title', 'body')


class ThreadModerationInputSerializer(serializers.Serializer):
    is_pinned = serializers.BooleanField(required=False)
    is_locked = serializers.BooleanField(required=False)
    is_hidden = serializers.BooleanField(required=False)
