import 'package:material_ui/material_ui.dart';
import '../../data/curriculum_models.dart';

/// Structured Daily Lesson Plan Overview displaying LessonPlan metadata,
/// I. Intentions, L. Learning Experience Context, and W. Ways Forward
/// mapped directly from `/api/v1/curriculum/lesson-grade-levels/`.
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.plan});

  final LessonPlan plan;

  String _formatExtraKey(String key) {
    return key
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final gradesLabel = plan.gradeLevels.isEmpty
        ? 'Not specified'
        : plan.gradeLevels
            .map((g) => g.gradeLevelName)
            .where((n) => n.isNotEmpty)
            .join(' & ');

    final metadataCells = <(String, String)>[
      ('Learning Area', plan.subject.isNotEmpty ? plan.subject : '—'),
      ('Grade Levels', gradesLabel),
      ('Primary Language', plan.primaryLanguage.isNotEmpty ? plan.primaryLanguage : '—'),
      ('Suggested Demographic', plan.suggestedDemographic.isNotEmpty ? plan.suggestedDemographic : '—'),
      if (plan.schoolName.isNotEmpty) ('School', plan.schoolName),
      if (plan.teachingDate.isNotEmpty) ('Teaching Date', plan.teachingDate),
      if (plan.quarterTerm.isNotEmpty) ('Quarter / Term', plan.quarterTerm),
      if (plan.timeSessions.isNotEmpty) ('Time / Sessions', plan.timeSessions),
      ('Forks', '${plan.forkCount}${plan.forkedFromId != null ? ' (Forked from #${plan.forkedFromId})' : ''}'),
      ('Visibility', plan.isPublic ? 'Public' : 'Private'),
    ];

    for (final entry in plan.extraFields.entries) {
      if (entry.value is! List && entry.value is! Map) {
        metadataCells.add((_formatExtraKey(entry.key), entry.value.toString()));
      }
    }

    final hasIntentions = plan.sharedSubTheme.isNotEmpty ||
        plan.description.isNotEmpty ||
        plan.gradeLevels.any((g) =>
            g.contentStandard.isNotEmpty ||
            g.performanceStandard.isNotEmpty ||
            g.learningCompetencies.isNotEmpty ||
            g.learningObjectives.isNotEmpty);

    final hasContext = plan.learnerContext.isNotEmpty ||
        plan.gradeLevels.any((g) => g.learnerContext.isNotEmpty);

    final hasWaysForward = plan.reflectionQuestions.isNotEmpty ||
        plan.notesForNextSession.isNotEmpty ||
        plan.gradeLevels.any((g) =>
            g.reflectionQuestions.isNotEmpty ||
            g.remediation.isNotEmpty ||
            g.enrichment.isNotEmpty) ||
        plan.authorEntries.isNotEmpty ||
        plan.authorName.isNotEmpty ||
        plan.checkerName.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Lesson Plan Header Grid
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: colors.primaryContainer,
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: colors.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'DAILY LESSON PLAN — ${gradesLabel.toUpperCase()}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    if (plan.isApproved)
                      const Chip(
                        label: Text('Approved'),
                        avatar: Icon(Icons.verified, size: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    final itemWidth = isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: metadataCells
                          .map(
                            (cell) => SizedBox(
                              width: itemWidth,
                              child: _MetadataCell(label: cell.$1, value: cell.$2),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
              if (plan.multigradeModel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                    border: Border(top: BorderSide(color: colors.outlineVariant)),
                  ),
                  child: _MetadataCell(
                    label: 'Multigrade Model',
                    value: plan.multigradeModel,
                  ),
                ),
            ],
          ),
        ),

        // I. INTENTIONS
        if (hasIntentions) ...[
          const SizedBox(height: 12),
          _SectionCard(
            code: 'I',
            title: 'INTENTIONS',
            children: [
              if (plan.sharedSubTheme.isNotEmpty) ...[
                _MetadataCell(label: 'Shared Sub-theme', value: plan.sharedSubTheme),
                const SizedBox(height: 12),
              ],
              if (plan.description.isNotEmpty &&
                  plan.description != plan.suggestedDemographic) ...[
                _MetadataCell(label: 'Overview / Description', value: plan.description),
                const SizedBox(height: 12),
              ],
              if (plan.gradeLevels.isNotEmpty)
                _GradeComparisonMatrix(
                  gradeLevels: plan.gradeLevels,
                  rows: [
                    _MatrixRowSpec(
                      label: 'Content Standard',
                      extractor: (g) => g.contentStandard,
                    ),
                    _MatrixRowSpec(
                      label: 'Performance Standard',
                      extractor: (g) => g.performanceStandard,
                    ),
                    _MatrixRowSpec(
                      label: 'Competencies & Codes',
                      extractor: (g) => g.learningCompetencies,
                    ),
                    _MatrixRowSpec(
                      label: 'Learning Objectives',
                      extractor: (g) => g.learningObjectives,
                    ),
                  ],
                ),
            ],
          ),
        ],

        // L. LEARNING EXPERIENCE CONTEXT
        if (hasContext) ...[
          const SizedBox(height: 12),
          _SectionCard(
            code: 'L',
            title: 'LEARNING EXPERIENCE CONTEXT',
            children: [
              if (plan.learnerContext.isNotEmpty) ...[
                _MetadataCell(label: 'Shared Learner Context', value: plan.learnerContext),
                const SizedBox(height: 12),
              ],
              if (plan.gradeLevels.any((g) => g.learnerContext.isNotEmpty))
                _GradeComparisonMatrix(
                  gradeLevels: plan.gradeLevels,
                  rows: [
                    _MatrixRowSpec(
                      label: 'Learner Context',
                      extractor: (g) => g.learnerContext,
                    ),
                  ],
                ),
            ],
          ),
        ],

        // W. WAYS FORWARD & SIGNATORIES
        if (hasWaysForward) ...[
          const SizedBox(height: 12),
          _SectionCard(
            code: 'W',
            title: 'WAYS FORWARD & SIGNATORIES',
            children: [
              if (plan.reflectionQuestions.isNotEmpty) ...[
                _MetadataCell(
                  label: 'Shared Reflection Questions',
                  value: plan.reflectionQuestions,
                ),
                const SizedBox(height: 12),
              ],
              if (plan.gradeLevels.any((g) =>
                  g.reflectionQuestions.isNotEmpty ||
                  g.remediation.isNotEmpty ||
                  g.enrichment.isNotEmpty)) ...[
                _GradeComparisonMatrix(
                  gradeLevels: plan.gradeLevels,
                  rows: [
                    _MatrixRowSpec(
                      label: 'Reflection Questions',
                      extractor: (g) => g.reflectionQuestions,
                    ),
                    _MatrixRowSpec(
                      label: 'Remediation',
                      extractor: (g) => g.remediation,
                    ),
                    _MatrixRowSpec(
                      label: 'Enrichment',
                      extractor: (g) => g.enrichment,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (plan.notesForNextSession.isNotEmpty) ...[
                _MetadataCell(
                  label: 'Notes for Next Session / Follow-Up',
                  value: plan.notesForNextSession,
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  if (plan.authorEntries.isNotEmpty)
                    ...plan.authorEntries.map(
                      (a) => _MetadataCell(
                        label: 'Prepared by (${a.authorRole})',
                        value: a.displayLabel,
                      ),
                    )
                  else if (plan.authorName.isNotEmpty)
                    _MetadataCell(
                      label: 'Prepared by',
                      value: '@${plan.authorName}',
                    ),
                  if (plan.checkerName.isNotEmpty)
                    _MetadataCell(
                      label: 'Checked by',
                      value: plan.checkerName,
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.code,
    required this.title,
    required this.children,
  });

  final String code;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: colors.secondaryContainer,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: colors.onSecondaryContainer,
                  foregroundColor: colors.secondaryContainer,
                  child: Text(
                    code,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixRowSpec {
  const _MatrixRowSpec({required this.label, required this.extractor});

  final String label;
  final String Function(LessonGradeLevel) extractor;
}

class _GradeComparisonMatrix extends StatelessWidget {
  const _GradeComparisonMatrix({
    required this.gradeLevels,
    required this.rows,
  });

  final List<LessonGradeLevel> gradeLevels;
  final List<_MatrixRowSpec> rows;

  @override
  Widget build(BuildContext context) {
    final activeRows = rows
        .where((r) => gradeLevels.any((g) => r.extractor(g).isNotEmpty))
        .toList();

    if (activeRows.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        dataRowMaxHeight: double.infinity,
        columns: [
          const DataColumn(label: Text('Component')),
          ...gradeLevels.map(
            (g) => DataColumn(
              label: Text(
                (g.gradeLevelName.isNotEmpty
                        ? g.gradeLevelName
                        : 'Grade ${g.gradeLevelId}')
                    .toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        rows: activeRows.map((spec) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  spec.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ...gradeLevels.map((g) {
                final val = spec.extractor(g);
                return DataCell(
                  SizedBox(
                    width: 260,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(val.isNotEmpty ? val : '—'),
                    ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MetadataCell extends StatelessWidget {
  const _MetadataCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
