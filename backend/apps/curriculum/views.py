from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.accounts.permissions import IsCheckerOrAdmin
from .filters import LessonPlanFilter
from .models import (
    LessonGradeLevel,
    LessonGradeMaterial,
    LessonFlow,
    LessonGrading,
)
from .pagination import LessonPlanPagination
from .permissions import IsCurriculumEditorOrReadOnly
from .selectors import (
    get_grade_level_queryset,
    get_material_queryset,
    get_lesson_plan_queryset,
)
from .serializers import (
    GradeLevelSerializer,
    MaterialSerializer,
    LessonPlanListSerializer,
    LessonPlanDetailSerializer,
    LessonPlanWriteSerializer,
    LessonPlanForkInputSerializer,
    AssignCheckerInputSerializer,
    LpCheckerSerializer,
    LessonGradeLevelDetailSerializer,
    LessonGradeLevelWriteSerializer,
    LessonGradeMaterialSerializer,
    LessonFlowSerializer,
    LessonGradingSerializer,
)
from .services import (
    create_lesson_plan,
    fork_lesson_plan,
    assign_lesson_plan_checker,
)


class GradeLevelViewSet(viewsets.ModelViewSet):
    queryset = get_grade_level_queryset()
    serializer_class = GradeLevelSerializer
    permission_classes = [IsAuthenticated, IsCurriculumEditorOrReadOnly]
    search_fields = ['grade_level_name']


class MaterialViewSet(viewsets.ModelViewSet):
    queryset = get_material_queryset()
    serializer_class = MaterialSerializer
    permission_classes = [IsAuthenticated, IsCurriculumEditorOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['file_type', 'is_offline_cached']
    search_fields = ['file_name', 'description']
    ordering_fields = ['file_name', 'file_size_kb', 'material_id']


class LessonPlanViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, IsCurriculumEditorOrReadOnly]
    pagination_class = LessonPlanPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = LessonPlanFilter
    search_fields = [
        'lp_title',
        'learning_area',
        'primary_language',
        'suggested_demographic',
        'lessongradelevel__i_competencies_codes',
    ]
    ordering_fields = ['lp_id', 'lp_title', 'learning_area', 'primary_language']
    ordering = ['-lp_id']

    def get_queryset(self):
        return get_lesson_plan_queryset().distinct()

    def get_serializer_class(self):
        if self.action == 'list':
            return LessonPlanListSerializer
        if self.action in {'create', 'update', 'partial_update'}:
            return LessonPlanWriteSerializer
        return LessonPlanDetailSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        lp = create_lesson_plan(author=request.user, validated_data=serializer.validated_data)
        output = LessonPlanDetailSerializer(lp, context={'request': request})
        return Response(output.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated], url_path='fork')
    def fork(self, request, pk=None):
        """Any authenticated user (e.g., Teacher or Author) can fork a lesson plan."""
        original_lp = self.get_object()
        serializer = LessonPlanForkInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        cloned_lp = fork_lesson_plan(
            original_lp=original_lp,
            new_author=request.user,
            custom_title=serializer.validated_data.get('lp_title'),
        )
        output = LessonPlanDetailSerializer(cloned_lp, context={'request': request})
        return Response(output.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], permission_classes=[IsCheckerOrAdmin], url_path='assign-checker')
    def assign_checker(self, request, pk=None):
        lp = self.get_object()
        serializer = AssignCheckerInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        link = assign_lesson_plan_checker(
            lp=lp,
            checker=serializer.validated_data['account_id'],
            checker_role=serializer.validated_data['checker_role'],
        )
        return Response(LpCheckerSerializer(link).data, status=status.HTTP_200_OK)


class LessonGradeLevelViewSet(viewsets.ModelViewSet):
    queryset = LessonGradeLevel.objects.select_related('lp', 'gl').all()
    permission_classes = [IsAuthenticated, IsCurriculumEditorOrReadOnly]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['lp', 'gl']

    def get_serializer_class(self):
        if self.action in {'create', 'update', 'partial_update'}:
            return LessonGradeLevelWriteSerializer
        return LessonGradeLevelDetailSerializer


class LessonGradeMaterialViewSet(viewsets.ModelViewSet):
    queryset = LessonGradeMaterial.objects.select_related('lesson_grade_level', 'material').all()
    serializer_class = LessonGradeMaterialSerializer
    permission_classes = [IsAuthenticated, IsCurriculumEditorOrReadOnly]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['lesson_grade_level', 'material']


class LessonFlowViewSet(viewsets.ModelViewSet):
    queryset = LessonFlow.objects.select_related('lesson_grade_level').order_by('lf_id')
    serializer_class = LessonFlowSerializer
    permission_classes = [IsAuthenticated, IsCurriculumEditorOrReadOnly]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['lesson_grade_level', 'stage']


class LessonGradingViewSet(viewsets.ModelViewSet):
    queryset = LessonGrading.objects.select_related('lesson_grade_level').order_by('lg_id')
    serializer_class = LessonGradingSerializer
    permission_classes = [IsAuthenticated, IsCurriculumEditorOrReadOnly]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['lesson_grade_level']
