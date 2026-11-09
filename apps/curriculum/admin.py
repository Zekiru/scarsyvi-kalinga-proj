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
    LessonGrading
)


class LessonGradeLevelInline(admin.TabularInline):
    model = LessonGradeLevel
    extra = 0


class LpAuthorInline(admin.TabularInline):
    model = LpAuthor
    extra = 0


class LpCheckerInline(admin.TabularInline):
    model = LpChecker
    extra = 0


class LessonFlowInline(admin.TabularInline):
    model = LessonFlow
    extra = 0


class LessonGradingInline(admin.TabularInline):
    model = LessonGrading
    extra = 0


class LessonGradeMaterialInline(admin.TabularInline):
    model = LessonGradeMaterial
    extra = 0


class MaterialAdmin(admin.ModelAdmin):
    model = Material


class GradeLevelAdmin(admin.ModelAdmin):
    model = GradeLevel


class LessonPlanAdmin(admin.ModelAdmin):
    model = LessonPlan
    inlines = [
        LessonGradeLevelInline,
        LpAuthorInline,
        LpCheckerInline
    ]


class LessonGradeLevelAdmin(admin.ModelAdmin):
    model = LessonGradeLevel
    inlines = [
        LessonFlowInline,
        LessonGradingInline,
        LessonGradeMaterialInline
    ]


admin.site.register(GradeLevel, GradeLevelAdmin)
admin.site.register(LessonPlan, LessonPlanAdmin)
admin.site.register(LessonGradeLevel, LessonGradeLevelAdmin)
admin.site.register(Material, MaterialAdmin)
