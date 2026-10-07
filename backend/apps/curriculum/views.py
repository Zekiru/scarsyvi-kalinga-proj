from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import LessonPlan, Material
from .serializers import (
    LessonPlanDetailSerializer, 
    LessonPlanWriteSerializer, 
    MaterialSerializer
)


class LessonPlanViewSet(viewsets.ModelViewSet):
    """
    API endpoint for retrieving, creating, and updating multi-grade lesson plans.
    """
    queryset = LessonPlan.objects.prefetch_related(
        'lessongradelevel_set__flows',
        'lessongradelevel_set__grading_tasks',
        'lessongradelevel_set__lessongradematerial_set__material',
        'lessongradelevel_set__gl'
    ).all()

    def get_serializer_class(self):
        """
        Dynamically route serializers:
        - Use LessonPlanWriteSerializer for POST (create), PUT (update), and PATCH (partial_update).
        - Use LessonPlanDetailSerializer for GET (list, retrieve).
        """
        if self.action in ['create', 'update', 'partial_update']:
            return LessonPlanWriteSerializer
        return LessonPlanDetailSerializer

    @action(detail=False, methods=['post'], url_path='bulk-sync')
    def bulk_sync(self, request):
        """
        Endpoint for processing offline sync queues from Flutter devices.
        Accepts batched updates/creations sent when connectivity resumes.
        """
        sync_payloads = request.data.get('transactions', [])
        # Process queued offline records here...
        return Response({'status': 'synced', 'count': len(sync_payloads)}, status=status.HTTP_200_OK)


class MaterialViewSet(viewsets.ReadOnlyModelViewSet):
    """API endpoint to query downloadable teaching materials."""
    queryset = Material.objects.all()
    serializer_class = MaterialSerializer
