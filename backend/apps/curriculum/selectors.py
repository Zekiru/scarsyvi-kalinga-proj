from django.db.models import QuerySet
from .models import GradeLevel, Material, LessonPlan


def get_grade_level_queryset() -> QuerySet[GradeLevel]:
    return GradeLevel.objects.all().order_by('gl_id')


def get_material_queryset() -> QuerySet[Material]:
    return Material.objects.all().order_by('file_name')


def get_lesson_plan_queryset() -> QuerySet[LessonPlan]:
    return (
        LessonPlan.objects
        .select_related('forked_from')
        .prefetch_related(
            'grade_levels',
            'lpauthor_set__account',
            'lpchecker_set__account',
            'lessongradelevel_set__gl',
            'lessongradelevel_set__lessongradematerial_set__material',
            'lessongradelevel_set__flows',
            'lessongradelevel_set__grading_tasks',
        )
        .order_by('-lp_id')
    )
