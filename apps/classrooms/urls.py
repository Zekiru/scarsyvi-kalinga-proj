from django.urls import path, include
from rest_framework.routers import DefaultRouter, APIRootView
from .views import (
    ClassroomViewSet,
    StudentViewSet,
    AttendanceSessionViewSet,
    StudentGradeViewSet,
)


class ClassroomsRootView(APIRootView):
    """Browsable API root for classrooms endpoints."""
    pass


class ClassroomsRouter(DefaultRouter):
    APIRootView = ClassroomsRootView


router = ClassroomsRouter()
router.register(r'classrooms', ClassroomViewSet, basename='classroom')
router.register(r'students', StudentViewSet, basename='student')
router.register(r'attendance-sessions', AttendanceSessionViewSet, basename='attendance-session')
router.register(r'student-grades', StudentGradeViewSet, basename='student-grade')

urlpatterns = [
    path('', include(router.urls)),
]
