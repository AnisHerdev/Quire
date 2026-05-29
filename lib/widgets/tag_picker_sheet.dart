import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../utils/subject_detector.dart';

class TagPickerResult {
  final List<String> tags;
  final String? folderId;

  const TagPickerResult({required this.tags, this.folderId});
}

Future<TagPickerResult?> showTagPickerSheet({
  required BuildContext context,
  required String filename,
}) {
  return showModalBottomSheet<TagPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TagPickerSheet(filename: filename),
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  final String filename;

  const _TagPickerSheet({required this.filename});

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  final Set<String> _selectedTags = {};
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();


  @override
  void initState() {
    super.initState();
    final suggestions = SubjectDetector.detect(widget.filename);
    if (suggestions.isNotEmpty) {
      _selectedTags.add(suggestions.first);
      _folderController.text = suggestions.first;
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addCustomTag() {
    final tag = _tagController.text.trim().toUpperCase();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _submit() {
    final folderName = _folderController.text.trim();
    String? folderId;

    if (folderName.isNotEmpty) {
      final db = ref.read(databaseProvider);
      final existing = db.folders.values.where(
        (f) => f.name.toLowerCase() == folderName.toLowerCase(),
      );
      if (existing.isNotEmpty) {
        folderId = existing.first.id;
      }
    }

    Navigator.pop(context, TagPickerResult(
      tags: _selectedTags.toList(),
      folderId: folderId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final database = ref.watch(databaseProvider);

    final suggestions = SubjectDetector.detect(widget.filename);
    final recentTags = database.allTags
        .where((t) => !suggestions.contains(t))
        .take(10)
        .toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tag & Organize', style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (suggestions.isNotEmpty) ...[
                Text('Suggested', style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: suggestions.map((tag) => _buildTagChip(tag, isSuggested: true)).toList(),
                ),
                const SizedBox(height: 16),
              ],

              if (recentTags.isNotEmpty) ...[
                Text('Recent tags', style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: recentTags.map((tag) => _buildTagChip(tag)).toList(),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        hintText: 'Type a tag...',
                        hintStyle: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.outline,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addCustomTag,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),

              if (_selectedTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Selected', style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.secondary,
                )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedTags.map((tag) => Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _toggleTag(tag),
                    backgroundColor: colorScheme.secondaryContainer,
                  )).toList(),
                ),
              ],

              const SizedBox(height: 20),
              TextField(
                controller: _folderController,
                decoration: InputDecoration(
                  labelText: 'Save to folder',
                  hintText: 'Folder name (auto-created if needed)',
                  prefixIcon: Icon(Icons.folder, color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedTags.isEmpty ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Save & Organize',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, {bool isSuggested = false}) {
    final selected = _selectedTags.contains(tag);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _toggleTag(tag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : (isSuggested
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : colorScheme.surfaceContainerLow),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSuggested ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
