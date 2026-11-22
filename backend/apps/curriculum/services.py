from django.db import transaction
from .models import (
    LessonPlan,
    LpAuthor,
    LpChecker,
    LessonGradeLevel,
    LessonGradeMaterial,
    LessonFlow,
    LessonGrading,
)


@transaction.atomic
def create_lesson_plan(*, author, validated_data: dict) -> LessonPlan:
    grade_levels = validated_data.pop("grade_levels", [])
    lp = LessonPlan.objects.create(**validated_data)

    if author and getattr(author, "is_authenticated", False):
        LpAuthor.objects.get_or_create(
            lp=lp,
            account=author,
            defaults={"author_role": "Primary Author"},
        )

    for gl in grade_levels:
        LessonGradeLevel.objects.get_or_create(lp=lp, gl=gl)

    return lp


@transaction.atomic
def fork_lesson_plan(
    *,
    original_lp: LessonPlan,
    new_author,
    custom_title: str | None = None,
) -> LessonPlan:
    cloned_lp = LessonPlan.objects.create(
        lp_title=custom_title or f"{original_lp.lp_title} (Fork)",
        learning_area=original_lp.learning_area,
        primary_language=original_lp.primary_language,
        suggested_demographic=original_lp.suggested_demographic,
        learning_model_description=original_lp.learning_model_description,
        intentions_description=original_lp.intentions_description,
        notes=original_lp.notes,
        forked_from=original_lp,
    )

    if new_author and getattr(new_author, "is_authenticated", False):
        LpAuthor.objects.get_or_create(
            lp=cloned_lp,
            account=new_author,
            defaults={"author_role": "Primary Author"},
        )

    for lgl in original_lp.lessongradelevel_set.all():
        cloned_lgl = LessonGradeLevel.objects.create(
            lp=cloned_lp,
            gl=lgl.gl,
            i_content_standard=lgl.i_content_standard,
            i_performance_standard=lgl.i_performance_standard,
            i_competencies_codes=lgl.i_competencies_codes,
            i_objectives=lgl.i_objectives,
            l_context=lgl.l_context,
            w_reflection_questions=lgl.w_reflection_questions,
            re_remediation=lgl.re_remediation,
            re_enrichment=lgl.re_enrichment,
        )
        for flow in lgl.flows.all():
            LessonFlow.objects.create(
                lesson_grade_level=cloned_lgl,
                time_minutes=flow.time_minutes,
                stage=flow.stage,
                description=flow.description,
            )
        for grading in lgl.grading_tasks.all():
            LessonGrading.objects.create(
                lesson_grade_level=cloned_lgl,
                task_name=grading.task_name,
                task_description=grading.task_description,
                grade_weight=grading.grade_weight,
                max_score=grading.max_score,
            )
        for lgm in lgl.lessongradematerial_set.all():
            LessonGradeMaterial.objects.create(
                lesson_grade_level=cloned_lgl,
                material=lgm.material,
                usage_instructions=lgm.usage_instructions,
            )

    return cloned_lp


def assign_lesson_plan_checker(
    *,
    lp: LessonPlan,
    checker,
    checker_role: str = "Reviewer",
) -> LpChecker:
    link, _ = LpChecker.objects.update_or_create(
        lp=lp,
        account=checker,
        defaults={"checker_role": checker_role},
    )
    return link
