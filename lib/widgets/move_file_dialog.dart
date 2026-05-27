import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';

class MoveFileDialog extends ConsumerStatefulWidget {
  final List<String> fileIds;
  
  const MoveFileDialog({super.key, required this.fileIds});

  @override
  ConsumerState<MoveFileDialog> createState() => _MoveFileDialogState();
}

class _MoveFileDialogState extends ConsumerState<MoveFileDialog> {
  String? expandedSemesterId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final database = ref.watch(databaseProvider);
    
    final semesters = database.semesters.entries.toList()
      ..sort((a, b) => a.value.order.compareTo(b.value.order));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Move to...',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (semesters.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No semesters created yet. Go to Home to create one.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: semesters.length,
                itemBuilder: (context, index) {
                  final semesterEntry = semesters[index];
                  final semesterId = semesterEntry.key;
                  final semester = semesterEntry.value;
                  
                  final subjects = database.subjects.entries
                      .where((e) => e.value.semesterId == semesterId)
                      .toList();
                      
                  final isExpanded = expandedSemesterId == semesterId;

                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          isExpanded ? Icons.folder_open : Icons.folder,
                          color: colorScheme.primary,
                        ),
                        title: Text(semester.name, style: theme.textTheme.titleMedium),
                        trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                        onTap: () {
                          setState(() {
                            expandedSemesterId = isExpanded ? null : semesterId;
                          });
                        },
                      ),
                      if (isExpanded)
                        if (subjects.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 72, top: 8, bottom: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No subjects. Create one first.',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                              ),
                            ),
                          )
                        else
                          ...subjects.map((subjectEntry) {
                            return ListTile(
                              contentPadding: const EdgeInsets.only(left: 72, right: 24),
                              leading: Icon(Icons.menu_book, size: 20, color: colorScheme.secondary),
                              title: Text(subjectEntry.value.name, style: theme.textTheme.bodyMedium),
                              onTap: () async {
                                final undoFunc = await ref.read(databaseProvider.notifier).moveFiles(
                                  widget.fileIds,
                                  semesterId,
                                  subjectEntry.key,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context, undoFunc);
                                }
                              },
                            );
                          }),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
