from rest_framework import viewsets, permissions
from .models import Classroom
from .serializers import ClassroomSerializer


class ClassroomViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows Classrooms to be viewed or edited along with nested students.
    """
    queryset = Classroom.objects.all().prefetch_related('students', 'grade_levels').select_related('lesson_plan', 'adviser')
    serializer_class = ClassroomSerializer
    permission_classes = [permissions.AllowAny]  # Adjust as needed for authentication
    