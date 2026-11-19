from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import RegisterView, LoginView, LogoutView, MeView, AccountViewSet

router = DefaultRouter()
router.register(r'users', AccountViewSet, basename='account-users')

urlpatterns = [
    path('register/', RegisterView.as_view(), name='account-register'),
    path('login/', LoginView.as_view(), name='account-login'),
    path('logout/', LogoutView.as_view(), name='account-logout'),
    path('me/', MeView.as_view(), name='account-me'),
    path('', include(router.urls)),
]
