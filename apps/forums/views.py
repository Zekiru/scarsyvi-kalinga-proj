from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .permissions import IsAuthorOrForumModerator, IsForumModeratorPermission
from .selectors import (
    get_forum_queryset,
    get_thread_queryset,
    get_post_queryset,
)
from .serializers import (
    LessonPlanForumSerializer,
    ForumByLessonPlanInputSerializer,
    ForumThreadListSerializer,
    ForumThreadDetailSerializer,
    ForumThreadWriteSerializer,
    ForumThreadUpdateSerializer,
    ThreadModerationInputSerializer,
    ForumPostSerializer,
    ForumPostUpdateSerializer,
)
from .services import (
    get_or_create_forum_for_lesson_plan,
    create_forum_thread,
    create_forum_post,
    update_thread_moderation,
)


class LessonPlanForumViewSet(viewsets.ModelViewSet):
    queryset = get_forum_queryset()
    serializer_class = LessonPlanForumSerializer
    permission_classes = [IsAuthenticated, IsAuthorOrForumModerator]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['lesson_plan', 'is_locked']
    search_fields = ['lesson_plan__lp_title']
    ordering_fields = ['forum_id', 'created_at', 'updated_at']
    ordering = ['-updated_at']

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        forum, created = get_or_create_forum_for_lesson_plan(
            lesson_plan=serializer.validated_data['lesson_plan']
        )
        if 'is_locked' in serializer.validated_data:
            self.check_object_permissions(request, forum)
            forum.is_locked = serializer.validated_data['is_locked']
            forum.save(update_fields=['is_locked', 'updated_at'])

        refreshed = self.get_queryset().get(pk=forum.pk)
        output = self.get_serializer(refreshed)
        return Response(output.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated], url_path='by-lesson-plan')
    def by_lesson_plan(self, request):
        """
        Idempotent helper: gets or creates the LessonPlanForum for a given `lesson_plan_id`.
        """
        serializer = ForumByLessonPlanInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        forum, created = get_or_create_forum_for_lesson_plan(
            lesson_plan=serializer.validated_data['lesson_plan']
        )
        refreshed = self.get_queryset().get(pk=forum.pk)
        output = self.get_serializer(refreshed)
        return Response(output.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    @action(detail=True, methods=['post'], permission_classes=[IsForumModeratorPermission], url_path='toggle-lock')
    def toggle_lock(self, request, pk=None):
        forum = self.get_object()
        forum.is_locked = not forum.is_locked
        forum.save(update_fields=['is_locked', 'updated_at'])
        refreshed = self.get_queryset().get(pk=forum.pk)
        return Response(self.get_serializer(refreshed).data, status=status.HTTP_200_OK)


class ForumThreadViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, IsAuthorOrForumModerator]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['forum', 'forum__lesson_plan', 'author', 'is_pinned', 'is_locked', 'is_hidden']
    search_fields = ['title', 'body', 'author__username']
    ordering_fields = ['thread_id', 'is_pinned', 'created_at', 'updated_at']
    ordering = ['-is_pinned', '-created_at']

    def get_queryset(self):
        return get_thread_queryset(self.request.user)

    def get_serializer_class(self):
        if self.action == 'list':
            return ForumThreadListSerializer
        if self.action == 'create':
            return ForumThreadWriteSerializer
        if self.action in {'update', 'partial_update'}:
            return ForumThreadUpdateSerializer
        return ForumThreadDetailSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        thread = create_forum_thread(author=request.user, validated_data=serializer.validated_data)
        refreshed = self.get_queryset().get(pk=thread.pk)
        output = ForumThreadDetailSerializer(refreshed, context={'request': request})
        return Response(output.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], permission_classes=[IsForumModeratorPermission], url_path='moderate')
    def moderate(self, request, pk=None):
        """Allows forum moderators to pin, lock, or soft-hide a thread."""
        thread = self.get_object()
        serializer = ThreadModerationInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        update_thread_moderation(thread, **serializer.validated_data)
        refreshed = self.get_queryset().get(pk=thread.pk)
        return Response(ForumThreadDetailSerializer(refreshed, context={'request': request}).data)


class ForumPostViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, IsAuthorOrForumModerator]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['thread', 'author', 'parent_post', 'is_hidden']
    search_fields = ['content', 'author__username']
    ordering_fields = ['post_id', 'created_at']
    ordering = ['created_at']

    def get_queryset(self):
        return get_post_queryset(self.request.user)

    def get_serializer_class(self):
        if self.action in {'update', 'partial_update'}:
            return ForumPostUpdateSerializer
        return ForumPostSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        post = create_forum_post(author=request.user, validated_data=serializer.validated_data)
        refreshed = self.get_queryset().get(pk=post.pk)
        return Response(ForumPostSerializer(refreshed, context={'request': request}).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], permission_classes=[IsForumModeratorPermission], url_path='toggle-hide')
    def toggle_hide(self, request, pk=None):
        """Soft-hides or restores a post for forum moderation."""
        post = self.get_object()
        post.is_hidden = not post.is_hidden
        post.save(update_fields=['is_hidden', 'updated_at'])
        return Response(ForumPostSerializer(post, context={'request': request}).data)
