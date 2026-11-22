import 'package:material_ui/material_ui.dart';
import '../../data/curriculum_models.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.plan});

  final LessonPlan plan;

  @override
  Widget build(BuildContext context) {
    final gradesText = plan.gradeLevels
        .map(
          (g) => g.gradeLevelName.isNotEmpty
              ? g.gradeLevelName
              : 'Grade ${g.gradeLevelId}',
        )
        .join(', ');

    final metadataRows = <_MetaItem>[
      if (plan.subject.isNotEmpty) _MetaItem('Learning Area', plan.subject),
      if (plan.primaryLanguage.isNotEmpty)
        _MetaItem('Primary Language', plan.primaryLanguage),
      if (plan.suggestedDemographic.isNotEmpty)
        _MetaItem('Suggested Demographic', plan.suggestedDemographic),
      if (gradesText.isNotEmpty) _MetaItem('Target Grade Levels', gradesText),
      if (plan.schoolName.isNotEmpty) _MetaItem('School', plan.schoolName),
      if (plan.teachingDate.isNotEmpty) _MetaItem('Date', plan.teachingDate),
      if (plan.quarterTerm.isNotEmpty)
        _MetaItem('Quarter / Term', plan.quarterTerm),
      if (plan.timeSessions.isNotEmpty) _MetaItem('Time', plan.timeSessions),
      if (plan.authorName.isNotEmpty)
        _MetaItem('Primary Author', plan.authorName),
      if (plan.checkerName.isNotEmpty)
        _MetaItem('Checked By', plan.checkerName),
      _MetaItem(
        'Visibility',
        plan.isPublic ? 'Public (Resource Center)' : 'Private',
      ),
      if (plan.forkedFromId != null)
        _MetaItem('Forked From', 'Lesson Plan #${plan.forkedFromId}'),
      if (plan.forkCount > 0)
        _MetaItem('Fork Count', '${plan.forkCount} forks'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lesson Plan Metadata',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20),
                ...metadataRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 170,
                          child: Text(
                            row.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                        Expanded(child: Text(row.value)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (plan.authorEntries.isNotEmpty ||
            plan.checkerEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Authors & Reviewers',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...plan.authorEntries.map(
                        (a) => Chip(
                          avatar: const Icon(Icons.person_outline, size: 16),
                          label: Text(a.displayLabel),
                        ),
                      ),
                      ...plan.checkerEntries.map(
                        (c) => Chip(
                          avatar: const Icon(
                            Icons.rate_review_outlined,
                            size: 16,
                          ),
                          label: Text(c.displayLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (plan.learningModelDescription.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TextSectionCard(
            title: 'Learning Model Description',
            body: plan.learningModelDescription,
          ),
        ],
        if (plan.intentionsDescription.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TextSectionCard(
            title: 'Intentions Description',
            body: plan.intentionsDescription,
          ),
        ],
        if (plan.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TextSectionCard(
            title: 'Notes',
            body: plan.notes,
          ),
        ],
        if (plan.extraFields.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Additional Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 20),
                  ...plan.extraFields.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key.replaceAll('_', ' ').toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(e.value.toString()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaItem {
  const _MetaItem(this.label, this.value);
  final String label;
  final String value;
}

class _TextSectionCard extends StatelessWidget {
  const _TextSectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
