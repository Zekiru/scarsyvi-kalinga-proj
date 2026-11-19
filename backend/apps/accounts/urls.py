from django.urls import path, include
from rest_framework.routers import DefaultRouter, APIRootView
from rest_framework.reverse import reverse
from .views import RegisterView, LoginView, LogoutView, MeView, AccountViewSet


class AccountsRootView(APIRootView):
    """Displays both ViewSet routes and custom auth APIViews at /api/v1/accounts/."""
    def get(self, request, *args, **kwargs):
        response = super().get(request, *args, **kwargs)
        response.data.update({
            'register': reverse('v1:account-register', request=request, format=kwargs.get('format')),
            'login': reverse('v1:account-login', request=request, format=kwargs.get('format')),
            'logout': reverse('v1:account-logout', request=request, format=kwargs.get('format')),
            'me': reverse('v1:account-me', request=request, format=kwargs.get('format')),
        })
        return response


class AccountsRouter(DefaultRouter):
    APIRootView = AccountsRootView


router = AccountsRouter()
router.register(r'users', AccountViewSet, basename='account-users')

urlpatterns = [
    path('register/', RegisterView.as_view(), name='account-register'),
    path('login/', LoginView.as_view(), name='account-login'),
    path('logout/', LogoutView.as_view(), name='account-logout'),
    path('me/', MeView.as_view(), name='account-me'),
    path('', include(router.urls)),
]
