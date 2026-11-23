from django.db.models import Prefetch
from .models import (
    GradeLevel,
    Material,
    LessonPlan,
    LpAuthor,
    LpChecker,
    LessonGradeLevel,
)


def get_grade_level_queryset():
    return GradeLevel.objects.all().order_by("gl_id")


def get_material_queryset():
    return Material.objects.all().order_by("-material_id")


def get_lesson_plan_queryset():
    return LessonPlan.objects.prefetch_related(
        "grade_levels",
        Prefetch(
            "lpauthor_set",
            queryset=LpAuthor.objects.select_related("account").order_by("id"),
        ),
        Prefetch(
            "lpchecker_set",
            queryset=LpChecker.objects.select_related("account").order_by("id"),
        ),
        Prefetch(
            "lessongradelevel_set",
            queryset=LessonGradeLevel.objects.select_related("gl").prefetch_related(
                "flows",
                "grading_tasks",
                "lessongradematerial_set__material",
            ),
        ),
    )
