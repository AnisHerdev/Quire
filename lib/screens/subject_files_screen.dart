import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/database_provider.dart';
import '../models/database_model.dart';
import '../widgets/move_file_dialog.dart';

class SubjectFilesScreen extends ConsumerStatefulWidget {
  final String subjectId;

  const SubjectFilesScreen({super.key, required this.subjectId});

  @override
  ConsumerState<SubjectFilesScreen> createState() => _SubjectFilesScreenState();
}

class _SubjectFilesScreenState extends ConsumerState<SubjectFilesScreen> {
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

  void _showDeleteConfirmation(List<String> fileIds) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    final database = ref.read(databaseProvider);
    final isSingle = fileIds.length == 1;
    final title = isSingle ? (database.files[fileIds.first]?.name ?? 'this file') : '${fileIds.length} files';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_outline, color: colorScheme.error, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delete $title?', style: textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text('This will permanently delete this from your Google Drive.', 
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _executeDelete(fileIds);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Delete Permanently', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Cancel', style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeDelete(List<String> fileIds) async {
    try {
      await ref.read(databaseProvider.notifier).deleteFiles(fileIds);
      if (mounted) {
        setState(() {
          _selectedFiles.clear();
          _isSelectionMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('Bad state: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            action: errorMsg.contains('internet connection') 
                ? SnackBarAction(
                    label: 'Retry', 
                    textColor: Theme.of(context).colorScheme.onError,
                    onPressed: () => _executeDelete(fileIds)
                  )
                : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final database = ref.watch(databaseProvider);
    final subject = database.subjects[widget.subjectId];
    final semesterName = subject != null ? database.semesters[subject.semesterId]?.name ?? '' : '';
    final subjectName = subject?.name ?? 'Subject View';

    final filesEntry = database.files.entries
        .where((e) => e.value.subjectId == widget.subjectId)
        .toList();

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
          _isSelectionMode ? '${_selectedFiles.length} Selected' : subjectName,
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
      body: Column(
        children: [
          // Breadcrumbs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              children: [
                Icon(Icons.home, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('Home', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 16, color: colorScheme.outlineVariant),
                const SizedBox(width: 8),
                Text(semesterName, style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 16, color: colorScheme.outlineVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(subjectName, style: textTheme.labelLarge?.copyWith(color: colorScheme.primary), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: filesEntry.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: colorScheme.outline.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            "This subject is empty.",
                            style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filesEntry.length,
                    itemBuilder: (context, index) {
                      final entry = filesEntry[index];
                      return _buildFileCard(context, entry.value, entry.key);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: null,
      floatingActionButtonLocation: _isSelectionMode 
          ? FloatingActionButtonLocation.centerFloat 
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: _isSelectionMode 
          ? _buildSelectionPill(context, colorScheme, textTheme)
          : null,
    );
  }

  Widget _buildSelectionPill(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_selectedFiles.length}',
              style: textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Selected',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 24,
            color: colorScheme.onPrimary.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.drive_file_move),
            color: colorScheme.onPrimary,
            tooltip: 'Move',
            onPressed: () {
              _showMoveDialog(_selectedFiles.toList());
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: colorScheme.onPrimary,
            tooltip: 'Delete',
            onPressed: () {
              _showDeleteConfirmation(_selectedFiles.toList());
            },
          ),
          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 24,
            color: colorScheme.onPrimary.withValues(alpha: 0.3),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: colorScheme.onPrimary,
            tooltip: 'Clear',
            onPressed: () {
              setState(() {
                _isSelectionMode = false;
                _selectedFiles.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, QuireFileModel file, String fileId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final isSelected = _selectedFiles.contains(fileId);

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
              color: colorScheme.primaryContainer.withValues(alpha: 0.04),
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
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (!_isSelectionMode)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant, size: 20),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'move') {
                        _showMoveDialog([fileId]);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation([fileId]);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'move',
                        child: Row(
                          children: [
                            Icon(Icons.drive_file_move, color: colorScheme.onSurface),
                            const SizedBox(width: 12),
                            const Text('Move to...'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: colorScheme.error),
                            const SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
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
            Text(dateStr, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
