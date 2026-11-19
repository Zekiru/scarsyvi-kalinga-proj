from django.db import transaction
from rest_framework.exceptions import ValidationError
from apps.accounts.models import Account
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
def create_lesson_plan(author: Account, validated_data: dict) -> LessonPlan:
    """Creates a LessonPlan and links the creator as Primary Author."""
    grade_levels = validated_data.pop('grade_levels', [])
    lp = LessonPlan.objects.create(**validated_data)
    LpAuthor.objects.create(lp=lp, account=author, author_role="Primary Author")

    for gl in grade_levels:
        LessonGradeLevel.objects.get_or_create(lp=lp, gl=gl)

    return lp


@transaction.atomic
def assign_lesson_plan_checker(lp: LessonPlan, checker: Account, checker_role: str = "Reviewer") -> LpChecker:
    """Assigns or updates a reviewer/checker on a LessonPlan."""
    if checker.role not in {Account.Role.CHECKER, Account.Role.ADMIN} and not checker.is_superuser:
        raise ValidationError({'account': 'Assigned user must have the CHECKER or ADMIN role.'})

    link, _ = LpChecker.objects.update_or_create(
        lp=lp,
        account=checker,
        defaults={'checker_role': checker_role},
    )
    return link


@transaction.atomic
def fork_lesson_plan(original_lp: LessonPlan, new_author: Account, custom_title: str | None = None) -> LessonPlan:
    """
    Deep-clones a LessonPlan and its entire grade-level hierarchy
    (LessonGradeLevel, LessonGradeMaterial, LessonFlow, LessonGrading)
    into a new LessonPlan linked via `forked_from`.
    """
    cloned_lp = LessonPlan.objects.create(
        lp_title=custom_title or f"{original_lp.lp_title} (Copy)",
        learning_area=original_lp.learning_area,
        primary_language=original_lp.primary_language,
        suggested_demographic=original_lp.suggested_demographic,
        learning_model_description=original_lp.learning_model_description,
        intentions_description=original_lp.intentions_description,
        notes=original_lp.notes,
        forked_from=original_lp,
    )

    LpAuthor.objects.create(
        lp=cloned_lp,
        account=new_author,
        author_role="Primary Author",
    )

    source_grade_levels = (
        LessonGradeLevel.objects
        .filter(lp=original_lp)
        .prefetch_related('lessongradematerial_set', 'flows', 'grading_tasks')
    )

    for src_lgl in source_grade_levels:
        cloned_lgl = LessonGradeLevel.objects.create(
            lp=cloned_lp,
            gl=src_lgl.gl,
            i_content_standard=src_lgl.i_content_standard,
            i_performance_standard=src_lgl.i_performance_standard,
            i_competencies_codes=src_lgl.i_competencies_codes,
            i_objectives=src_lgl.i_objectives,
            l_context=src_lgl.l_context,
            w_reflection_questions=src_lgl.w_reflection_questions,
            re_remediation=src_lgl.re_remediation,
            re_enrichment=src_lgl.re_enrichment,
        )

        # Bulk-clone attached materials, flows, and grading tasks
        LessonGradeMaterial.objects.bulk_create([
            LessonGradeMaterial(
                lesson_grade_level=cloned_lgl,
                material=lgm.material,
                usage_instructions=lgm.usage_instructions,
            )
            for lgm in src_lgl.lessongradematerial_set.all()
        ])

        LessonFlow.objects.bulk_create([
            LessonFlow(
                lesson_grade_level=cloned_lgl,
                time_minutes=flow.time_minutes,
                stage=flow.stage,
                description=flow.description,
            )
            for flow in src_lgl.flows.all()
        ])

        LessonGrading.objects.bulk_create([
            LessonGrading(
                lesson_grade_level=cloned_lgl,
                task_name=task.task_name,
                task_description=task.task_description,
                grade_weight=task.grade_weight,
                max_score=task.max_score,
            )
            for task in src_lgl.grading_tasks.all()
        ])

    return cloned_lp
