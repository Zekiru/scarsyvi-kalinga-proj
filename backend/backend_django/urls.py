"""
URL configuration for backend_django project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.contrib import admin
from django.urls import path, include, URLResolver
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


class ApiV1RootView(APIView):
    """
    Dynamically displays clickable URLs for every route mounted in api_v1_patterns.
    """
    permission_classes = [AllowAny]

    def get(self, request, format=None):
        base_url = request.build_absolute_uri()
        endpoints = {}

        for pattern in api_v1_patterns:
            route = str(pattern.pattern)
            if not route:
                continue  # Skip the root '' path itself

            key = route.rstrip('/')
            if isinstance(pattern, URLResolver):
                endpoints[key] = f"{base_url}{route}"
            else:
                endpoints[key] = f"{base_url}{route}"

        return Response(endpoints)


api_v1_patterns = [
    path('', ApiV1RootView.as_view(), name='api-root'),
    path('accounts/', include('apps.accounts.urls')),
    path('curriculum/', include('apps.curriculum.urls')),
    path('classrooms/', include('apps.classrooms.urls')),
    path('forums/', include('apps.forums.urls')),
]

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api-auth/', include('rest_framework.urls')),
    path('api/v1/', include((api_v1_patterns, 'v1'), namespace='v1')),
]
