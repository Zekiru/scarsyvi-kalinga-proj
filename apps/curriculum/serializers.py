from django.db import transaction
from rest_framework import serializers
from .models import (
    LessonPlan, GradeLevel, Material, 
    LessonGradeLevel, LessonGradeMaterial, LessonFlow, LessonGrading
)

# ==========================================
# 1. READ SERIALIZERS (GET requests)
# ==========================================


class MaterialSerializer(serializers.ModelSerializer):
    """Serializer for central learning materials repository."""
    class Meta:
        model = Material
        fields = [
            'material_id', 'file_name', 'file_url', 'file_type', 
            'file_size_kb', 'description', 'is_offline_cached'
        ]


class LessonFlowSerializer(serializers.ModelSerializer):
    """Read serializer for grade-specific lesson flow steps."""
    class Meta:
        model = LessonFlow
        fields = ['lf_id', 'time_minutes', 'stage', 'description']


class LessonGradingSerializer(serializers.ModelSerializer):
    """Read serializer for grade-specific assessment criteria."""
    class Meta:
        model = LessonGrading
        fields = ['lg_id', 'task_name', 'task_description', 'grade_weight', 'max_score']


class LessonGradeMaterialSerializer(serializers.ModelSerializer):
    """Read serializer bridging materials to grade levels with instructions."""
    material = MaterialSerializer(read_only=True)

    class Meta:
        model = LessonGradeMaterial
        fields = ['material', 'usage_instructions']


class LessonGradeLevelSerializer(serializers.ModelSerializer):
    """Read serializer combining grade standards, flows, materials, and grading."""
    gl_id = serializers.IntegerField(source='gl.gl_id', read_only=True)
    grade_level_name = serializers.CharField(source='gl.grade_level_name', read_only=True)
    flows = LessonFlowSerializer(many=True, read_only=True)
    grading_tasks = LessonGradingSerializer(many=True, read_only=True)
    materials_detail = LessonGradeMaterialSerializer(
        source='lessongradematerial_set', 
        many=True, 
        read_only=True
    )

    class Meta:
        model = LessonGradeLevel
        fields = [
            'gl_id', 'grade_level_name',
            'i_content_standard', 'i_performance_standard', 'i_competencies_codes', 'i_objectives',
            'l_context', 'w_reflection_questions', 're_remediation', 're_enrichment',
            'flows', 'grading_tasks', 'materials_detail'
        ]


class LessonPlanDetailSerializer(serializers.ModelSerializer):
    """Comprehensive read-only serializer for downloading full multi-grade lessons."""
    grade_levels_detail = LessonGradeLevelSerializer(
        source='lessongradelevel_set', 
        many=True, 
        read_only=True
    )

    class Meta:
        model = LessonPlan
        fields = [
            'lp_id', 'lp_title', 'learning_area', 'primary_language',
            'suggested_demographic', 'learning_model_description',
            'intentions_description', 'notes', 'grade_levels_detail'
        ]


# ==========================================
# 2. WRITE SERIALIZERS (POST / PUT / PATCH)
# ==========================================

class LessonFlowWriteSerializer(serializers.ModelSerializer):
    """Write serializer for creating/updating lesson flow steps."""
    class Meta:
        model = LessonFlow
        fields = ['time_minutes', 'stage', 'description']


class LessonGradingWriteSerializer(serializers.ModelSerializer):
    """Write serializer for creating/updating assessment tasks."""
    class Meta:
        model = LessonGrading
        fields = ['task_name', 'task_description', 'grade_weight', 'max_score']


class LessonGradeLevelWriteSerializer(serializers.ModelSerializer):
    """Write serializer for multi-grade level blocks within a lesson."""
    gl_id = serializers.IntegerField()  # Simply declare gl_id without source
    flows = LessonFlowWriteSerializer(many=True, required=False)
    grading_tasks = LessonGradingWriteSerializer(many=True, required=False)
    material_ids = serializers.ListField(
        child=serializers.IntegerField(), 
        write_only=True, 
        required=False
    )

    class Meta:
        model = LessonGradeLevel
        fields = [
            'gl_id', 'i_content_standard', 'i_performance_standard', 
            'i_competencies_codes', 'i_objectives', 'l_context', 
            'w_reflection_questions', 're_remediation', 're_enrichment',
            'flows', 'grading_tasks', 'material_ids'
        ]


class LessonPlanWriteSerializer(serializers.ModelSerializer):
    """Handles full multi-grade lesson creation (POST) and updating (PUT/PATCH)."""
    grade_levels = LessonGradeLevelWriteSerializer(many=True)

    class Meta:
        model = LessonPlan
        fields = [
            'lp_id', 'lp_title', 'learning_area', 'primary_language',
            'suggested_demographic', 'learning_model_description',
            'intentions_description', 'notes', 'grade_levels'
        ]

    @transaction.atomic
    def create(self, validated_data):
        """Handles POST: Saves parent lesson plan and all multi-grade children."""
        grade_levels_data = validated_data.pop('grade_levels', [])
        lesson_plan = LessonPlan.objects.create(**validated_data)
        self._save_grade_levels(lesson_plan, grade_levels_data)
        return lesson_plan

    @transaction.atomic
    def update(self, instance, validated_data):
        """Handles PUT/PATCH: Updates parent and re-synchronizes multi-grade children."""
        grade_levels_data = validated_data.pop('grade_levels', None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if grade_levels_data is not None:
            instance.lessongradelevel_set.all().delete()
            self._save_grade_levels(instance, grade_levels_data)

        return instance

    def _save_grade_levels(self, lesson_plan, grade_levels_data):
        """Helper function to save nested multi-grade levels, flows, grading, and materials."""
        for gl_data in grade_levels_data:
            gl_id = gl_data.pop('gl_id')
            flows_data = gl_data.pop('flows', [])
            grading_data = gl_data.pop('grading_tasks', [])
            material_ids = gl_data.pop('material_ids', [])

            # Create LessonGradeLevel record
            lgl = LessonGradeLevel.objects.create(
                lp=lesson_plan,
                gl_id=gl_id,
                **gl_data
            )

            # Create flow steps
            for flow_item in flows_data:
                LessonFlow.objects.create(lesson_grade_level=lgl, **flow_item)

            # Create grading tasks
            for task_item in grading_data:
                LessonGrading.objects.create(lesson_grade_level=lgl, **task_item)

            # Attach materials
            for mat_id in material_ids:
                LessonGradeMaterial.objects.create(
                    lesson_grade_level=lgl,
                    material_id=mat_id
                )
