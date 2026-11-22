from rest_framework import serializers
from apps.accounts.models import Account
from apps.accounts.serializers import AccountSummarySerializer
from .models import (
    GradeLevel,
    Material,
    LessonPlan,
    LpAuthor,
    LpChecker,
    LessonGradeLevel,
    LessonGradeMaterial,
    LessonFlow,
    LessonGrading,
)


class GradeLevelSerializer(serializers.ModelSerializer):
    class Meta:
        model = GradeLevel
        fields = ('gl_id', 'grade_level_name')


class MaterialSerializer(serializers.ModelSerializer):
    class Meta:
        model = Material
        fields = (
            'material_id',
            'file_name',
            'file_url',
            'file_type',
            'file_size_kb',
            'description',
            'is_offline_cached',
        )


class LpAuthorSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(source='pk', read_only=True)
    account_id = serializers.IntegerField(source='account.pk', read_only=True)
    account = AccountSummarySerializer(read_only=True)

    class Meta:
        model = LpAuthor
        fields = ('id', 'account_id', 'account', 'author_role')


class LpCheckerSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(source='pk', read_only=True)
    account_id = serializers.IntegerField(source='account.pk', read_only=True)
    account = AccountSummarySerializer(read_only=True)

    class Meta:
        model = LpChecker
        fields = ('id', 'account_id', 'account', 'checker_role')


class LessonGradeMaterialSerializer(serializers.ModelSerializer):
    material = MaterialSerializer(read_only=True)
    material_id = serializers.PrimaryKeyRelatedField(
        queryset=Material.objects.all(), source='material', write_only=True
    )

    class Meta:
        model = LessonGradeMaterial
        fields = ('id', 'lesson_grade_level', 'material', 'material_id', 'usage_instructions')


class LessonFlowSerializer(serializers.ModelSerializer):
    class Meta:
        model = LessonFlow
        fields = ('lf_id', 'lesson_grade_level', 'time_minutes', 'stage', 'description')


class LessonGradingSerializer(serializers.ModelSerializer):
    class Meta:
        model = LessonGrading
        fields = ('lg_id', 'lesson_grade_level', 'task_name', 'task_description', 'grade_weight', 'max_score')


class LessonGradeLevelDetailSerializer(serializers.ModelSerializer):
    grade_level = GradeLevelSerializer(source='gl', read_only=True)
    materials = LessonGradeMaterialSerializer(source='lessongradematerial_set', many=True, read_only=True)
    flows = LessonFlowSerializer(many=True, read_only=True)
    grading_tasks = LessonGradingSerializer(many=True, read_only=True)

    class Meta:
        model = LessonGradeLevel
        fields = (
            'id',
            'lp',
            'gl',
            'grade_level',
            'i_content_standard',
            'i_performance_standard',
            'i_competencies_codes',
            'i_objectives',
            'l_context',
            'w_reflection_questions',
            're_remediation',
            're_enrichment',
            'materials',
            'flows',
            'grading_tasks',
        )


class LessonGradeLevelWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = LessonGradeLevel
        fields = (
            'id',
            'lp',
            'gl',
            'i_content_standard',
            'i_performance_standard',
            'i_competencies_codes',
            'i_objectives',
            'l_context',
            'w_reflection_questions',
            're_remediation',
            're_enrichment',
        )


class LessonPlanListSerializer(serializers.ModelSerializer):
    grade_levels = GradeLevelSerializer(many=True, read_only=True)
    authors = serializers.SerializerMethodField()
    fork_count = serializers.IntegerField(source='forks.count', read_only=True)

    class Meta:
        model = LessonPlan
        fields = (
            'lp_id',
            'lp_title',
            'learning_area',
            'primary_language',
            'suggested_demographic',
            'forked_from',
            'fork_count',
            'grade_levels',
            'authors',
        )

    def get_authors(self, obj):
        qs = LpAuthor.objects.filter(lp=obj).select_related('account').order_by('pk')
        return LpAuthorSerializer(qs, many=True).data


class LessonPlanDetailSerializer(LessonPlanListSerializer):
    checkers = serializers.SerializerMethodField()
    differentiated_plans = LessonGradeLevelDetailSerializer(
        source='lessongradelevel_set', many=True, read_only=True
    )

    class Meta(LessonPlanListSerializer.Meta):
        fields = LessonPlanListSerializer.Meta.fields + (
            'learning_model_description',
            'intentions_description',
            'notes',
            'checkers',
            'differentiated_plans',
        )

    def get_checkers(self, obj):
        qs = LpChecker.objects.filter(lp=obj).select_related('account').order_by('pk')
        return LpCheckerSerializer(qs, many=True).data


class LessonPlanWriteSerializer(serializers.ModelSerializer):
    grade_levels = serializers.PrimaryKeyRelatedField(
        queryset=GradeLevel.objects.all(), many=True, required=False
    )

    class Meta:
        model = LessonPlan
        fields = (
            'lp_id',
            'lp_title',
            'learning_area',
            'primary_language',
            'suggested_demographic',
            'learning_model_description',
            'intentions_description',
            'notes',
            'grade_levels',
        )


class LessonPlanForkInputSerializer(serializers.Serializer):
    lp_title = serializers.CharField(max_length=255, required=False, allow_blank=False)


class AssignCheckerInputSerializer(serializers.Serializer):
    account_id = serializers.PrimaryKeyRelatedField(queryset=Account.objects.filter(is_active=True))
    checker_role = serializers.CharField(max_length=100, required=False, default="Reviewer")
