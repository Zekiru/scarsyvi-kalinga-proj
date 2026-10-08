#!/usr/bin/env bash
set -o errexit

pip install -r requirements.txt

python manage.py collectstatic --no-input
python manage.py migrate

# Create superuser automatically if environment variables exist
if [ "$DJANGO_SUPERUSER_USERNAME" ]; then
  python manage.py createsuperuser --no-input || true
fi

# Automatically seed Grades 1 to 6 using correct model field names
python manage.py shell -c "
from apps.classrooms.models import GradeLevel  # Adjust import if defined elsewhere

grades = ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6']

for grade_name in grades:
    GradeLevel.objects.get_or_create(grade_level_name=grade_name)

print('Successfully verified and seeded Grades 1-6!')
"
