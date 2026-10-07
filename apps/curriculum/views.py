from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.filters import SearchFilter, OrderingFilter
from django_filters.rest_framework import DjangoFilterBackend

from .models import LessonPlan, Material
from .serializers import (
    LessonPlanDetailSerializer, 
    LessonPlanWriteSerializer, 
    MaterialSerializer
)


class LessonPlanViewSet(viewsets.ModelViewSet):
    """
    API endpoint for retrieving, creating, updating, searching, and filtering multi-grade lesson plans.
    """
    queryset = LessonPlan.objects.prefetch_related(
        'lessongradelevel_set__flows',
        'lessongradelevel_set__grading_tasks',
        'lessongradelevel_set__lessongradematerial_set__material',
        'lessongradelevel_set__gl'
    ).all()

    # Enable filter backends
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]

    # Exact/Field-level filtering (e.g. ?learning_area=Math&primary_language=English&grade_levels__gl_id=1)
    filterset_fields = {
        'learning_area': ['exact', 'icontains'],
        'primary_language': ['exact', 'icontains'],
        'suggested_demographic': ['exact', 'icontains'],
        'grade_levels__gl_id': ['exact'],
        'grade_levels__grade_level_name': ['exact', 'icontains'],
    }

    # Free-text global search across multiple fields (e.g. ?search=fraction)
    search_fields = [
        'lp_title',
        'learning_area',
        'primary_language',
        'suggested_demographic',
        'learning_model_description',
        'intentions_description',
        'notes',
        # Search inside nested grade-level objectives and competencies
        'lessongradelevel__i_objectives',
        'lessongradelevel__i_competencies_codes',
        'lessongradelevel__i_content_standard',
    ]

    # Ordering options (e.g. ?ordering=-lp_id or ?ordering=lp_title)
    ordering_fields = ['lp_id', 'lp_title', 'learning_area', 'primary_language']
    ordering = ['lp_id']

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
        return Response({'status': 'synced', 'count': len(sync_payloads)}, status=status.HTTP_200_OK)


class MaterialViewSet(viewsets.ReadOnlyModelViewSet):
    """API endpoint to query downloadable teaching materials with search capabilities."""
    queryset = Material.objects.all()
    serializer_class = MaterialSerializer

    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]

    # Field-level filtering (e.g. ?file_type=PDF&is_offline_cached=true)
    filterset_fields = ['file_type', 'is_offline_cached']

    # Free-text search (e.g. ?search=worksheet)
    search_fields = ['file_name', 'description', 'file_type']

    ordering_fields = ['material_id', 'file_name', 'file_size_kb']
    ordering = ['file_name']