from django.urls import path, include
from rest_framework.routers import DefaultRouter, APIRootView
from .views import (
    LessonPlanForumViewSet,
    ForumThreadViewSet,
    ForumPostViewSet,
)


class ForumsRootView(APIRootView):
    """Browsable API root for forums endpoints."""
    pass


class ForumsRouter(DefaultRouter):
    APIRootView = ForumsRootView


router = ForumsRouter()
router.register(r'forums', LessonPlanForumViewSet, basename='lesson-plan-forum')
router.register(r'threads', ForumThreadViewSet, basename='forum-thread')
router.register(r'posts', ForumPostViewSet, basename='forum-post')

urlpatterns = [
    path('', include(router.urls)),
]
