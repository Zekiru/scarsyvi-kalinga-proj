import 'package:flutter/material.dart';

import '../models/lesson_plan_model.dart';
import '../models/lesson_grade_level_model.dart';
import '../models/lesson_flow_model.dart';
import '../models/lesson_grading_model.dart';
import '../models/lesson_grade_material_model.dart';

class LessonPlanDetailScreen extends StatelessWidget {
  final LessonPlanModel lessonPlan;

  const LessonPlanDetailScreen({super.key, required this.lessonPlan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lessonPlan.lpTitle),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Primary Lesson Plan Metadata Card ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lessonPlan.lpTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.book_outlined, size: 18),
                          label: Text(lessonPlan.learningArea),
                          backgroundColor: Colors.indigo.shade50,
                        ),
                        Chip(
                          avatar: const Icon(Icons.language, size: 18),
                          label: Text(lessonPlan.primaryLanguage),
                          backgroundColor: Colors.blue.shade50,
                        ),
                        if (lessonPlan.suggestedDemographic != null &&
                            lessonPlan.suggestedDemographic!.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.groups_outlined, size: 18),
                            label: Text(lessonPlan.suggestedDemographic!),
                            backgroundColor: Colors.teal.shade50,
                          ),
                      ],
                    ),
                    if (lessonPlan.learningModelDescription != null &&
                        lessonPlan.learningModelDescription!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildMetaText(
                        context,
                        'Learning Model Strategy',
                        lessonPlan.learningModelDescription!,
                      ),
                    ],
                    if (lessonPlan.intentionsDescription != null &&
                        lessonPlan.intentionsDescription!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildMetaText(
                        context,
                        'Learning Intentions',
                        lessonPlan.intentionsDescription!,
                      ),
                    ],
                    if (lessonPlan.notes != null && lessonPlan.notes!.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildMetaText(
                        context,
                        'General Notes',
                        lessonPlan.notes!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Grade Levels Section ---
            Text(
              'Grade Level Breakdown (${lessonPlan.gradeLevels.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            if (lessonPlan.gradeLevels.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No grade level configurations attached to this lesson plan.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lessonPlan.gradeLevels.length,
                itemBuilder: (context, index) {
                  final gradeLevel = lessonPlan.gradeLevels[index];
                  return _GradeLevelDetailCard(gradeLevel: gradeLevel);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaText(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          content,
          style: TextStyle(color: Colors.grey.shade800, height: 1.3),
        ),
      ],
    );
  }
}

class _GradeLevelDetailCard extends StatelessWidget {
  final LessonGradeLevelModel gradeLevel;

  const _GradeLevelDetailCard({required this.gradeLevel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          child: Text(
            'GL',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text(
          gradeLevel.gradeLevelName ?? 'Grade Level ID: ${gradeLevel.glId}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: gradeLevel.iObjectives != null
            ? Text(
                'Objectives: ${gradeLevel.iObjectives}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),

                // 1. Standards & Objectives
                if (_hasStandards()) ...[
                  _sectionHeader(Icons.analytics_outlined, 'Standards & Competencies'),
                  if (gradeLevel.iContentStandard != null)
                    _detailText('Content Standard', gradeLevel.iContentStandard!),
                  if (gradeLevel.iPerformanceStandard != null)
                    _detailText('Performance Standard', gradeLevel.iPerformanceStandard!),
                  if (gradeLevel.iCompetenciesCodes != null)
                    _detailText('Competencies Codes', gradeLevel.iCompetenciesCodes!),
                  if (gradeLevel.iObjectives != null)
                    _detailText('Objectives', gradeLevel.iObjectives!),
                  if (gradeLevel.lContext != null)
                    _detailText('Learning Context', gradeLevel.lContext!),
                  const SizedBox(height: 12),
                ],

                // 2. Lesson Flow Steps
                _sectionHeader(Icons.route_outlined, 'Lesson Flow Steps (${gradeLevel.flows.length})'),
                if (gradeLevel.flows.isEmpty)
                  const Text('No flow steps specified.', style: TextStyle(color: Colors.grey))
                else
                  ...gradeLevel.flows.map((flow) => _buildFlowTile(flow)),
                const SizedBox(height: 12),

                // 3. Learning Materials
                _sectionHeader(
                  Icons.folder_open_outlined,
                  'Learning Materials (${gradeLevel.materialsDetail.length})',
                ),
                if (gradeLevel.materialsDetail.isEmpty)
                  const Text('No materials attached.', style: TextStyle(color: Colors.grey))
                else
                  ...gradeLevel.materialsDetail.map((mat) => _buildMaterialTile(mat)),
                const SizedBox(height: 12),

                // 4. Grading Tasks & Assessments
                _sectionHeader(
                  Icons.assignment_turned_in_outlined,
                  'Assessment & Grading Tasks (${gradeLevel.gradingTasks.length})',
                ),
                if (gradeLevel.gradingTasks.isEmpty)
                  const Text('No grading tasks specified.', style: TextStyle(color: Colors.grey))
                else
                  ...gradeLevel.gradingTasks.map((task) => _buildGradingTile(task)),
                const SizedBox(height: 12),

                // 5. Remediation & Reflection
                if (_hasReflectionOrRemediation()) ...[
                  _sectionHeader(Icons.psychology_outlined, 'Reflection & Remediation'),
                  if (gradeLevel.wReflectionQuestions != null)
                    _detailText('Reflection Questions', gradeLevel.wReflectionQuestions!),
                  if (gradeLevel.reRemediation != null)
                    _detailText('Remediation Strategy', gradeLevel.reRemediation!),
                  if (gradeLevel.reEnrichment != null)
                    _detailText('Enrichment Strategy', gradeLevel.reEnrichment!),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasStandards() {
    return gradeLevel.iContentStandard != null ||
        gradeLevel.iPerformanceStandard != null ||
        gradeLevel.iCompetenciesCodes != null ||
        gradeLevel.iObjectives != null ||
        gradeLevel.lContext != null;
  }

  bool _hasReflectionOrRemediation() {
    return gradeLevel.wReflectionQuestions != null ||
        gradeLevel.reRemediation != null ||
        gradeLevel.reEnrichment != null;
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _detailText(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowTile(LessonFlowModel flow) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.indigo.shade100,
            child: Text(
              '${flow.timeMinutes}m',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flow.stage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  flow.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialTile(LessonGradeMaterialModel detail) {
    final mat = detail.material;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade50.withAlpha(120),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.teal),
        title: Text(mat.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${mat.fileType.toUpperCase()} • ${mat.fileSizeKb} KB'),
            if (detail.usageInstructions != null)
              Text(
                'Instructions: ${detail.usageInstructions}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
        trailing: Icon(
          mat.isOfflineCached ? Icons.offline_pin : Icons.cloud_download_outlined,
          color: mat.isOfflineCached ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildGradingTile(LessonGradingModel task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_outlined, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (task.taskDescription != null)
                  Text(
                    task.taskDescription!,
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('${task.maxScore} pts'),
                backgroundColor: Colors.amber.shade200,
              ),
              Text(
                'Weight: ${task.gradeWeight}%',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
