from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import Account


class AccountSummarySerializer(serializers.ModelSerializer):
    """Lightweight read-only representation embedded in curriculum, classrooms, and forums."""
    role_display = serializers.CharField(source='get_role_display', read_only=True)

    class Meta:
        model = Account
        fields = ('id', 'username', 'first_name', 'last_name', 'role', 'role_display')
        read_only_fields = fields


class AccountSerializer(serializers.ModelSerializer):
    """Full profile serializer for /api/accounts/me/ and Admin user management."""
    role_display = serializers.CharField(source='get_role_display', read_only=True)

    class Meta:
        model = Account
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'role', 'role_display')
        read_only_fields = ('id', 'username', 'role', 'role_display')


class RegisterSerializer(serializers.ModelSerializer):
    """Public registration serializer. Defaults role to TEACHER to prevent privilege escalation."""
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = Account
        fields = ('username', 'email', 'first_name', 'last_name', 'password', 'password_confirm')

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({'password_confirm': 'Passwords do not match.'})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        return Account.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            password=validated_data['password'],
            role=Account.Role.TEACHER,
        )


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        user = authenticate(
            request=self.context.get('request'),
            username=attrs.get('username'),
            password=attrs.get('password'),
        )
        if not user:
            raise serializers.ValidationError('Invalid username or password.', code='authorization')
        if not user.is_active:
            raise serializers.ValidationError('This account is disabled.', code='authorization')
        attrs['user'] = user
        return attrs
