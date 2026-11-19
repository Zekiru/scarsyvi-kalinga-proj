from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Account


@admin.register(Account)
class AccountAdmin(UserAdmin):
    list_display = ('username', 'email', 'first_name', 'last_name', 'role', 'is_staff')
    list_filter = ('role', 'is_staff', 'is_superuser', 'is_active')

    # Add 'role' to the existing UserAdmin edit page fieldsets
    fieldsets = UserAdmin.fieldsets + (
        ('Application Role', {'fields': ('role',)}),
    )

    # Add 'role' to the UserAdmin "Add User" page fieldsets
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Application Role', {'fields': ('role',)}),
    )
