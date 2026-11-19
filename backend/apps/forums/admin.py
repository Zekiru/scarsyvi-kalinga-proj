from django.contrib import admin
from .models import LessonPlanForum, ForumThread, ForumPost


class ForumThreadInline(admin.TabularInline):
    model = ForumThread
    extra = 0
    fields = ('__str__', 'title', 'author', 'is_pinned', 'is_locked', 'is_hidden', 'created_at')
    readonly_fields = ('__str__', 'created_at')
    show_change_link = True


class ForumPostInline(admin.TabularInline):
    model = ForumPost
    extra = 0
    fields = ('__str__', 'author', 'parent_post', 'content', 'is_hidden', 'created_at')
    readonly_fields = ('__str__', 'created_at')


@admin.register(LessonPlanForum)
class LessonPlanForumAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'is_locked', 'created_at')
    list_filter = ('is_locked',)
    search_fields = ('lesson_plan__lp_title',)
    inlines = [ForumThreadInline]


@admin.register(ForumThread)
class ForumThreadAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'author', 'is_pinned', 'is_locked', 'is_hidden', 'created_at')
    list_filter = ('is_pinned', 'is_locked', 'is_hidden')
    search_fields = ('title', 'author__username', 'forum__lesson_plan__lp_title')
    inlines = [ForumPostInline]


@admin.register(ForumPost)
class ForumPostAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'thread', 'parent_post', 'is_hidden', 'created_at')
    list_filter = ('is_hidden',)
    search_fields = ('content', 'author__username', 'thread__title')
