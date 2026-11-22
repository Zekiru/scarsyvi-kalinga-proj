import 'package:material_ui/material_ui.dart';
import '../../data/curriculum_models.dart';

class LessonPlanCard extends StatelessWidget {
  const LessonPlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    this.roleBadge,
    this.currentUserId,
    this.currentUsername,
  });

  final LessonPlan plan;
  final VoidCallback onTap;
  final String? roleBadge;
  final int? currentUserId;
  final String? currentUsername;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authorLabel = plan.primaryAuthorDisplay(
      currentUserId: currentUserId,
      currentUsername: currentUsername,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plan.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (plan.isPendingSync)
                    const Chip(
                      avatar: Icon(Icons.sync, size: 16),
                      label: Text('Pending Sync'),
                      visualDensity: VisualDensity.compact,
                    )
                  else if (plan.isApproved)
                    Chip(
                      avatar: Icon(
                        Icons.verified,
                        size: 16,
                        color: colors.primary,
                      ),
                      label: const Text('Approved'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (authorLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Made by $authorLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (plan.subject.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.menu_book_outlined, size: 16),
                      label: Text(plan.subject),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (plan.primaryLanguage.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.translate, size: 16),
                      label: Text(plan.primaryLanguage),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (plan.forkedFromId != null)
                    const Chip(
                      avatar: Icon(Icons.fork_right, size: 16),
                      label: Text('Forked'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (roleBadge != null && roleBadge!.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.badge_outlined, size: 16),
                      label: Text(roleBadge!),
                      visualDensity: VisualDensity.compact,
                    ),
                  ...plan.gradeLevels.map(
                    (gl) => Chip(
                      label: Text(
                        gl.gradeLevelName.isNotEmpty
                            ? gl.gradeLevelName
                            : 'Grade ${gl.gradeLevelId}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (plan.suggestedDemographic.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  plan.suggestedDemographic,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
