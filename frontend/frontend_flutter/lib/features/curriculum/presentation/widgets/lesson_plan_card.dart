import 'package:material_ui/material_ui.dart';
import '../../data/curriculum_models.dart';

class LessonPlanCard extends StatelessWidget {
  const LessonPlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    this.roleBadge,
  });

  final LessonPlan plan;
  final VoidCallback onTap;
  final String? roleBadge;

  @override
  Widget build(BuildContext context) {
    final gradesSummary = plan.gradeLevels
        .map((g) => g.gradeLevelName)
        .where((n) => n.isNotEmpty)
        .join(', ');

    final metaParts = <String>[
      if (plan.subject.isNotEmpty) plan.subject,
      if (plan.primaryLanguage.isNotEmpty) plan.primaryLanguage,
      if (gradesSummary.isNotEmpty) gradesSummary,
      if (plan.authorName.isNotEmpty) 'by ${plan.authorName}',
    ];

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          plan.title.isNotEmpty
              ? plan.title
              : 'Untitled Lesson Plan #${plan.id}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metaParts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(metaParts.join(' • ')),
              ),
            if (plan.suggestedDemographic.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  plan.suggestedDemographic,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (roleBadge != null && roleBadge!.isNotEmpty)
              Chip(
                label: Text(roleBadge!),
                avatar: const Icon(Icons.rate_review_outlined, size: 16),
                visualDensity: VisualDensity.compact,
              ),
            if (plan.isPendingSync || plan.isLocalDraft)
              const Chip(
                label: Text('Queued'),
                avatar: Icon(Icons.schedule, size: 16),
              )
            else if (plan.isApproved)
              const Chip(
                label: Text('Approved'),
                avatar: Icon(Icons.verified_outlined, size: 16),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
