from django.db import migrations

GRADE_NAMES = [f"Grade {n}" for n in range(1, 7)]


def seed_grade_levels(apps, schema_editor):
    # Use the historical model, not a direct import, so this stays valid
    # even if the model changes later.
    GradeLevel = apps.get_model("curriculum", "GradeLevel")
    for name in GRADE_NAMES:
        GradeLevel.objects.get_or_create(grade_level_name=name)


class Migration(migrations.Migration):

    dependencies = [
        ("curriculum", "0001_initial"),
    ]

    operations = [
        # noop on reverse so rolling back never deletes grade levels
        # (deleting them would cascade-delete students).
        migrations.RunPython(seed_grade_levels, migrations.RunPython.noop),
    ]
