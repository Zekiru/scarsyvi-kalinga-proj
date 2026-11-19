from django.db import transaction
from rest_framework.authtoken.models import Token
from .models import Account


@transaction.atomic
def register_account_with_token(serializer) -> tuple[Account, str]:
    """Creates the Account and generates its initial DRF Token in one transaction."""
    user = serializer.save()
    token, _ = Token.objects.get_or_create(user=user)
    return user, token.key


def get_or_create_user_token(user: Account) -> str:
    token, _ = Token.objects.get_or_create(user=user)
    return token.key


def revoke_user_token(user: Account) -> None:
    Token.objects.filter(user=user).delete()


def update_account_role(target_user: Account, new_role: str) -> Account:
    """Allows Admins to promote/demote users (e.g., TEACHER -> AUTHOR, CHECKER, or MODERATOR)."""
    target_user.role = new_role
    target_user.save(update_fields=['role'])
    return target_user
