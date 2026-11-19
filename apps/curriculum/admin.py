from django.contrib import admin
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


# ==========================================
# INLINES
# ==========================================

class LpAuthorInline(admin.TabularInline):
    model = LpAuthor
    extra = 1
    fields = ('account', 'author_role')


class LpCheckerInline(admin.TabularInline):
    model = LpChecker
    extra = 1
    fields = ('account', 'checker_role')


class LessonGradeLevelInline(admin.TabularInline):
    model = LessonGradeLevel
    extra = 0
    fields = ('__str__', 'gl', 'i_competencies_codes')
    readonly_fields = ('__str__',)
    show_change_link = True


class LessonGradeMaterialInline(admin.TabularInline):
    model = LessonGradeMaterial
    extra = 0
    fields = ('material', 'usage_instructions')


class LessonFlowInline(admin.TabularInline):
    model = LessonFlow
    extra = 0
    fields = ('stage', 'time_minutes', 'description')


class LessonGradingInline(admin.TabularInline):
    model = LessonGrading
    extra = 0
    fields = ('__str__', 'task_name', 'grade_weight', 'max_score')
    readonly_fields = ('__str__',)


# ==========================================
# CORE & ASSOCIATIVE MODEL ADMINS
# ==========================================

@admin.register(GradeLevel)
class GradeLevelAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'gl_id')
    search_fields = ('grade_level_name',)


@admin.register(Material)
class MaterialAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'file_type', 'file_size_kb', 'is_offline_cached')
    list_filter = ('file_type', 'is_offline_cached')
    search_fields = ('file_name', 'description')


@admin.register(LessonPlan)
class LessonPlanAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'learning_area', 'primary_language', 'forked_from')
    list_filter = ('learning_area', 'primary_language')
    search_fields = ('lp_title', 'learning_area')
    inlines = [LpAuthorInline, LpCheckerInline, LessonGradeLevelInline]


@admin.register(LpAuthor)
class LpAuthorAdmin(admin.ModelAdmin):
    list_display = ('lp', 'account', 'author_role')
    list_filter = ('author_role',)
    search_fields = ('lp__lp_title', 'account__username')


@admin.register(LpChecker)
class LpCheckerAdmin(admin.ModelAdmin):
    list_display = ('lp', 'account', 'checker_role')
    list_filter = ('checker_role',)
    search_fields = ('lp__lp_title', 'account__username')


@admin.register(LessonGradeLevel)
class LessonGradeLevelAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'lp', 'gl')
    list_filter = ('gl',)
    search_fields = ('lp__lp_title', 'gl__grade_level_name', 'i_competencies_codes')
    inlines = [LessonGradeMaterialInline, LessonFlowInline, LessonGradingInline]


@admin.register(LessonGradeMaterial)
class LessonGradeMaterialAdmin(admin.ModelAdmin):
    list_display = ('lesson_grade_level', 'material', 'usage_instructions')
    list_filter = ('lesson_grade_level__gl',)
    search_fields = ('lesson_grade_level__lp__lp_title', 'material__file_name')


@admin.register(LessonFlow)
class LessonFlowAdmin(admin.ModelAdmin):
    list_display = ('lf_id', 'lesson_grade_level', 'stage', 'time_minutes')
    list_filter = ('lesson_grade_level__gl', 'stage')
    search_fields = ('lesson_grade_level__lp__lp_title', 'stage', 'description')


@admin.register(LessonGrading)
class LessonGradingAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'lesson_grade_level', 'grade_weight', 'max_score')
    list_filter = ('lesson_grade_level__gl',)
    search_fields = ('task_name', 'lesson_grade_level__lp__lp_title')
