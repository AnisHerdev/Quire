import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/database_provider.dart';
import '../models/database_model.dart';
import '../widgets/move_file_dialog.dart';

class FileListScreen extends ConsumerStatefulWidget {
  final String folderId; // Represents semesterId

  const FileListScreen({super.key, required this.folderId});

  @override
  ConsumerState<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends ConsumerState<FileListScreen> {
  final Set<String> _selectedFiles = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String fileId) {
    setState(() {
      if (_selectedFiles.contains(fileId)) {
        _selectedFiles.remove(fileId);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(fileId);
      }
    });
  }

  void _showMoveDialog(List<String> fileIds) async {
    final undoFunc = await showModalBottomSheet<Future<void> Function()?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoveFileDialog(fileIds: fileIds),
    );

    if (undoFunc != null && mounted) {
      setState(() {
        _selectedFiles.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved ${fileIds.length} file(s)'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await undoFunc();
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subject'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Physics'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(databaseProvider.notifier).addSubject(controller.text, widget.folderId);
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final database = ref.watch(databaseProvider);
    final semesterName = database.semesters[widget.folderId]?.name ?? 'Semester View';

    // Get subjects for this semester
    final subjects = database.subjects.entries
        .where((e) => e.value.semesterId == widget.folderId)
        .toList();

    // Get files for this semester (that might not have a specific subject yet)
    final files = database.files.values
        .where((f) => f.semesterId == widget.folderId && f.subjectId.isEmpty)
        .toList();

    // Total items to display (subjects act as folders, files as items)
    final totalItems = subjects.length + files.length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedFiles.clear();
                  });
                },
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
        title: Text(
          _isSelectionMode ? '${_selectedFiles.length} Selected' : semesterName,
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.primary,
          ),
        ),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
              onPressed: () {},
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Row(
              children: [
                Icon(Icons.home, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('Home', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 16, color: colorScheme.outlineVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(semesterName, style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            if (totalItems == 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    "This semester is empty. Tap + to add a Subject.",
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
                  ),
                ),
              )
            else
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalItems,
                itemBuilder: (context, index) {
                  if (index < subjects.length) {
                    final entry = subjects[index];
                    return _buildSubjectCard(context: context, subject: entry.value, subjectId: entry.key);
                  } else {
                    final fileEntry = files[index - subjects.length];
                    // Find the key for the file to use as fileId
                    final fileId = database.files.entries
                        .firstWhere((e) => e.value == fileEntry)
                        .key;
                    return _buildFileCard(context: context, file: fileEntry, fileId: fileId);
                  }
                },
              ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
        onPressed: _showAddSubjectDialog,
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.create_new_folder, size: 28),
      ),
      bottomNavigationBar: _isSelectionMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showMoveDialog(_selectedFiles.toList());
                  },
                  icon: const Icon(Icons.drive_file_move),
                  label: const Text('Move Selected'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSubjectCard({
    required BuildContext context,
    required SubjectModel subject,
    required String subjectId,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: () {
        context.push('/subject/$subjectId');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.surfaceVariant),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primaryContainer.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book, color: colorScheme.primaryContainer, size: 20),
                ),
                Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
            const Spacer(),
            Text(
              subject.name,
              style: textTheme.labelLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text("Subject Folder", style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard({
    required BuildContext context,
    required QuireFileModel file,
    required String fileId,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final isSelected = _selectedFiles.contains(fileId);

    // Determine icons and colors based on mimeType
    IconData icon;
    Color iconColor;
    
    if (file.mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (file.mimeType.contains('presentation') || file.mimeType.contains('powerpoint')) {
      icon = Icons.slideshow;
      iconColor = Colors.orange;
    } else if (file.mimeType.contains('document') || file.mimeType.contains('wordprocessingml')) {
      icon = Icons.description;
      iconColor = Colors.blue;
    } else if (file.mimeType.contains('text')) {
      icon = Icons.text_snippet;
      iconColor = Colors.green;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    final date = DateTime.fromMillisecondsSinceEpoch(file.addedAt);
    final String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return InkWell(
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _toggleSelection(fileId);
        });
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(fileId);
        } else {
          context.push('/pdf-viewer/$fileId');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primaryContainer.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (!_isSelectionMode)
                  IconButton(
                    icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _showMoveDialog([fileId]);
                    },
                  )
                else
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? colorScheme.primary : colorScheme.outline,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              file.name,
              style: textTheme.labelLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(dateStr, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
