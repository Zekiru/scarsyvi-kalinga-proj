#!/usr/bin/env bash
set -o errexit

pip install -r requirements.txt

python manage.py collectstatic --no-input
python manage.py migrate

# Create superuser automatically if environment variables exist
if [ "$DJANGO_SUPERUSER_USERNAME" ]; then
  python manage.py createsuperuser --no-input || true
fi

# Automatically seed Grades 1 to 6 into the database
python manage.py shell -c "
from apps.classrooms.models import GradeLevel  # Adjust import to match your actual model path

grades = [
    (1, 'Grade 1'),
    (2, 'Grade 2'),
    (3, 'Grade 3'),
    (4, 'Grade 4'),
    (5, 'Grade 5'),
    (6, 'Grade 6'),
]

for level, name in grades:
    GradeLevel.objects.get_or_create(level=level, defaults={'name': name})

print('Successfully seeded/verified Grades 1-6!')
"
