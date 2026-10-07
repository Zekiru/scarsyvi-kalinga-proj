from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Classroom, AttendanceSession, StudentGrade
from .serializers import (
    ClassroomSerializer,
    AttendanceSessionSerializer,
    StudentGradeBatchSerializer,
    StudentGradeReadSerializer
)


class ClassroomViewSet(viewsets.ModelViewSet):
    queryset = Classroom.objects.all()
    serializer_class = ClassroomSerializer

    @action(detail=True, methods=['get', 'post'], url_path='attendance')
    def attendance(self, request, pk=None):
        classroom = self.get_object()

        if request.method == 'GET':
            sessions = AttendanceSession.objects.filter(classroom=classroom)
            serializer = AttendanceSessionSerializer(sessions, many=True)
            return Response(serializer.data)

        serializer = AttendanceSessionSerializer(
            data=request.data, 
            context={'classroom': classroom}
        )
        if serializer.is_valid():
            session = serializer.save()
            return Response(
                {"message": f"Attendance logged successfully (Session ID: {session.id})"}, 
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['get', 'post'], url_path='grades')
    def grades(self, request, pk=None):
        classroom = self.get_object()

        if request.method == 'GET':
            # Retrieve grades for all students enrolled in this classroom
            grades = StudentGrade.objects.filter(student__classroom=classroom)
            serializer = StudentGradeReadSerializer(grades, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)

        elif request.method == 'POST':
            serializer = StudentGradeBatchSerializer(data=request.data)
            if serializer.is_valid():
                created_grades = serializer.save()
                return Response(
                    {"message": f"Successfully processed {len(created_grades)} grade entries."}, 
                    status=status.HTTP_201_CREATED
                )
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
