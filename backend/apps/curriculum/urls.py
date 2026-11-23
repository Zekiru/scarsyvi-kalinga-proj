from django.urls import path, include
from rest_framework.routers import DefaultRouter, APIRootView
from .views import (
    GradeLevelViewSet,
    MaterialViewSet,
    LessonPlanViewSet,
    LessonGradeLevelViewSet,
    LessonGradeMaterialViewSet,
    LessonFlowViewSet,
    LessonGradingViewSet,
)


class CurriculumRootView(APIRootView):
    """Browsable API root for curriculum endpoints."""
    pass


class CurriculumRouter(DefaultRouter):
    APIRootView = CurriculumRootView


router = CurriculumRouter()
router.register(r'grade-levels', GradeLevelViewSet, basename='grade-level')
router.register(r'materials', MaterialViewSet, basename='material')
router.register(r'lesson-plans', LessonPlanViewSet, basename='lesson-plan')
router.register(r'lesson-grade-levels', LessonGradeLevelViewSet, basename='lesson-grade-level')
router.register(r'lesson-grade-materials', LessonGradeMaterialViewSet, basename='lesson-grade-material')
router.register(r'lesson-flows', LessonFlowViewSet, basename='lesson-flow')
router.register(r'lesson-gradings', LessonGradingViewSet, basename='lesson-grading')

urlpatterns = [
    path('', include(router.urls)),
]
