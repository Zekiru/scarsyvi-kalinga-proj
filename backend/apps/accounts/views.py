from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Account
from .permissions import IsAdminRole
from .serializers import (
    AccountSerializer,
    AccountSummarySerializer,
    RegisterSerializer,
    LoginSerializer,
)
from .services import (
    register_account_with_token,
    get_or_create_user_token,
    revoke_user_token,
    update_account_role,
)


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, token_key = register_account_with_token(serializer)
        return Response(
            {'token': token_key, 'user': AccountSerializer(user).data},
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        token_key = get_or_create_user_token(user)
        return Response(
            {'token': token_key, 'user': AccountSerializer(user).data},
            status=status.HTTP_200_OK,
        )


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        revoke_user_token(request.user)
        return Response({'detail': 'Successfully logged out.'}, status=status.HTTP_200_OK)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(AccountSerializer(request.user).data)

    def patch(self, request):
        serializer = AccountSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class AccountViewSet(viewsets.ReadOnlyModelViewSet):
    """
    - Authenticated users can list/search accounts (for assigning authors, checkers, advisers).
    - Admins can promote/demote roles via POST /api/accounts/users/{id}/set-role/.
    """
    queryset = Account.objects.filter(is_active=True).order_by('username')
    serializer_class = AccountSummarySerializer
    permission_classes = [IsAuthenticated]
    search_fields = ['username', 'first_name', 'last_name', 'email']
    filterset_fields = ['role']

    @action(detail=True, methods=['post'], permission_classes=[IsAdminRole], url_path='set-role')
    def set_role(self, request, pk=None):
        target_user = self.get_object()
        new_role = request.data.get('role')
        if new_role not in Account.Role.values:
            return Response(
                {'role': f'Invalid role. Choose from: {list(Account.Role.values)}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        updated_user = update_account_role(target_user, new_role)
        return Response(AccountSerializer(updated_user).data)
