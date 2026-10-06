from django.db import models
from django.conf import settings


class GradeLevel(models.Model):
    """Master reference for grade levels (e.g., Grade 1, Grade 2)."""
    gl_id = models.AutoField(primary_key=True)
    grade_level_name = models.CharField(max_length=50, unique=True)

    class Meta:
        db_table = 'grade_level'
        verbose_name = 'Grade Level'
        verbose_name_plural = 'Grade Levels'

    def __str__(self):
        return self.grade_level_name


class Material(models.Model):
    """Central repository for shared teaching assets (PDFs, worksheets, etc.)."""
    material_id = models.AutoField(primary_key=True)
    file_name = models.CharField(max_length=255)
    file_url = models.URLField(max_length=500)
    # Change help_string="e.g., PDF, DOCX, PNG" to help_text="e.g., PDF, DOCX, PNG"
    file_type = models.CharField(max_length=50, help_text="e.g., PDF, DOCX, PNG")
    file_size_kb = models.IntegerField()
    description = models.TextField(blank=True, null=True)
    is_offline_cached = models.BooleanField(
        default=False, 
        help_text="Priority flag for Flutter offline download engine"
    )

    class Meta:
        db_table = 'material'

    def __str__(self):
        return self.file_name


class LessonPlan(models.Model):
    """Umbrella container for multi-grade lesson plans."""
    lp_id = models.AutoField(primary_key=True)
    lp_title = models.CharField(max_length=255)
    learning_area = models.CharField(max_length=100)
    primary_language = models.CharField(max_length=50)
    suggested_demographic = models.CharField(max_length=255, blank=True, null=True)
    learning_model_description = models.TextField(blank=True, null=True)
    intentions_description = models.TextField(blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    # Relationships
    authors = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        through='LpAuthor',
        related_name='authored_lesson_plans'
    )
    checkers = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        through='LpChecker',
        related_name='checked_lesson_plans'
    )
    grade_levels = models.ManyToManyField(
        GradeLevel,
        through='LessonGradeLevel',
        related_name='lesson_plans'
    )

    class Meta:
        db_table = 'lesson_plan'

    def __str__(self):
        return f"[{self.lp_id}] {self.lp_title}"


# --- Explicit Junction / Associative Entities ---

class LpAuthor(models.Model):
    """Junction table linking Lesson Plans to Author Accounts."""
    lp = models.ForeignKey(LessonPlan, on_delete=models.CASCADE)
    account = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    author_role = models.CharField(max_length=100, default="Primary Author")

    class Meta:
        db_table = 'lp_author'
        unique_together = (('lp', 'account'),)


class LpChecker(models.Model):
    """Junction table linking Lesson Plans to Reviewer/Checker Accounts."""
    lp = models.ForeignKey(LessonPlan, on_delete=models.CASCADE)
    account = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    checker_role = models.CharField(max_length=100, default="Reviewer")

    class Meta:
        db_table = 'lp_checker'
        unique_together = (('lp', 'account'),)


class LessonGradeLevel(models.Model):
    """Associative entity bridging Lesson Plans & Grade Levels with differentiated standards."""
    lp = models.ForeignKey(LessonPlan, on_delete=models.CASCADE)
    gl = models.ForeignKey(GradeLevel, on_delete=models.CASCADE)
    
    # Grade-Specific Standards & Competencies
    i_content_standard = models.TextField(blank=True, null=True)
    i_performance_standard = models.TextField(blank=True, null=True)
    i_competencies_codes = models.TextField(blank=True, null=True)
    i_objectives = models.TextField(blank=True, null=True)
    l_context = models.TextField(blank=True, null=True)
    w_reflection_questions = models.TextField(blank=True, null=True)
    re_remediation = models.TextField(blank=True, null=True)
    re_enrichment = models.TextField(blank=True, null=True)

    materials = models.ManyToManyField(
        Material,
        through='LessonGradeMaterial',
        related_name='lesson_grade_levels'
    )

    class Meta:
        db_table = 'lesson_grade_level'
        unique_together = (('lp', 'gl'),)

    def __str__(self):
        return f"{self.lp.lp_title} - {self.gl.grade_level_name}"


class LessonGradeMaterial(models.Model):
    """Bridge table connecting specific Grade Level Lesson Plans to Materials."""
    lesson_grade_level = models.ForeignKey(LessonGradeLevel, on_delete=models.CASCADE)
    material = models.ForeignKey(Material, on_delete=models.CASCADE)
    usage_instructions = models.TextField(blank=True, null=True)

    class Meta:
        db_table = 'lesson_grade_material'
        unique_together = (('lesson_grade_level', 'material'),)


class LessonFlow(models.Model):
    """Differentiated time steps and stages for a lesson plan per grade level."""
    lf_id = models.AutoField(primary_key=True)
    lesson_grade_level = models.ForeignKey(LessonGradeLevel, on_delete=models.CASCADE, related_name='flows')
    time_minutes = models.IntegerField()
    stage = models.CharField(max_length=100) # e.g., "Introduction", "Independent Activity"
    description = models.TextField()

    class Meta:
        db_table = 'lesson_flow'


class LessonGrading(models.Model):
    """Differentiated assessment tasks and criteria for a lesson plan per grade level."""
    lg_id = models.AutoField(primary_key=True)
    lesson_grade_level = models.ForeignKey(LessonGradeLevel, on_delete=models.CASCADE, related_name='grading_tasks')
    task_name = models.CharField(max_length=255)
    task_description = models.TextField(blank=True, null=True)
    grade_weight = models.DecimalField(max_digits=5, decimal_places=2, default=1.00)
    max_score = models.IntegerField(default=100)

    class Meta:
        db_table = 'lesson_grading'

    def __str__(self):
        return f"{self.task_name} ({self.lesson_grade_level.gl.grade_level_name})"
