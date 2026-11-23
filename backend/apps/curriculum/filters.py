import django_filters
from .models import LessonPlan


class LessonPlanFilter(django_filters.FilterSet):
    learning_area = django_filters.CharFilter(lookup_expr='iexact')
    primary_language = django_filters.CharFilter(lookup_expr='iexact')
    grade_level = django_filters.NumberFilter(field_name='grade_levels__gl_id')
    author = django_filters.NumberFilter(field_name='authors__id')
    checker = django_filters.NumberFilter(field_name='checkers__id')
    forked_from = django_filters.NumberFilter(field_name='forked_from__lp_id')
    is_fork = django_filters.BooleanFilter(field_name='forked_from', lookup_expr='isnull', exclude=True)

    class Meta:
        model = LessonPlan
        fields = [
            'learning_area',
            'primary_language',
            'grade_level',
            'author',
            'checker',
            'forked_from',
            'is_fork',
        ]
