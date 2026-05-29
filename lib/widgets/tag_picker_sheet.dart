import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../models/database_model.dart';
import '../utils/filename_tag_matcher.dart';
import '../utils/subject_detector.dart';

class TagPickerResult {
  final List<String> folderTags;
  final String? folderName;
  final bool replaceDuplicate;
  final String? customName;

  const TagPickerResult({
    this.folderTags = const [],
    this.folderName,
    this.replaceDuplicate = false,
    this.customName,
  });
}

Future<TagPickerResult?> showTagPickerSheet({
  required BuildContext context,
  required String filename,
  bool isDuplicate = false,
}) {
  return showModalBottomSheet<TagPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _TagPickerSheet(filename: filename, isDuplicate: isDuplicate),
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  final String filename;
  final bool isDuplicate;

  const _TagPickerSheet({required this.filename, this.isDuplicate = false});

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late final TextEditingController _nameController;
  final TextEditingController _newFolderController = TextEditingController();
  final Set<String> _detectedTags = {};
  String? _selectedFolderId;
  bool _replaceDuplicate = false;
  bool _showNewFolderField = false;
  bool _folderInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.filename);
    final suggestions = SubjectDetector.detect(widget.filename);
    if (suggestions.isNotEmpty) {
      _detectedTags.add(suggestions.first);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newFolderController.dispose();
    super.dispose();
  }

  void _initFolderSelection() {
    if (_folderInitialized) return;
    _folderInitialized = true;

    if (mounted) {
      final database = ref.read(databaseProvider);
      final filenameUC = widget.filename.toUpperCase();

      // First try: SubjectDetected tag matches a folder name exactly
      final suggestions = SubjectDetector.detect(widget.filename);
      if (suggestions.isNotEmpty) {
        final tag = suggestions.first;
        final match = database.folders.values.where(
          (f) => f.name.toUpperCase() == tag,
        );
        if (match.isNotEmpty) {
          setState(() => _selectedFolderId = match.first.id);
          return;
        }
      }

      // Second try: filename matches any folder's associatedTags
      for (final folder in database.folders.values) {
        for (final tag in folder.associatedTags) {
          if (FilenameTagMatcher.matches(filenameUC, tag)) {
            setState(() {
              _selectedFolderId = folder.id;
              _detectedTags.add(tag);
            });
            return;
          }
        }
      }
    }
  }

  void _submit() {
    var customName = _nameController.text.trim();
    if (customName.isEmpty) customName = 'Untitled Document';
    if (!customName.toLowerCase().endsWith('.pdf')) customName += '.pdf';

    String? folderName;
    List<String> folderTags = [];
    if (_selectedFolderId == null) {
      folderName = '';
    } else if (_selectedFolderId == '__new__') {
      folderName = _newFolderController.text.trim();
      if (folderName.isEmpty) folderName = 'New Folder';
      folderTags = _detectedTags.toList();
    } else {
      final folder = ref.read(databaseProvider).folders[_selectedFolderId];
      folderName = folder?.name;
    }

    Navigator.pop(
      context,
      TagPickerResult(
        folderTags: folderTags,
        folderName: folderName,
        replaceDuplicate: _replaceDuplicate,
        customName: customName,
      ),
    );
  }

  String _saveButtonLabel() {
    if (_selectedFolderId == null) return 'Save to Inbox';
    if (_selectedFolderId == '__new__') {
      final name = _newFolderController.text.trim();
      return name.isNotEmpty ? 'Save to $name' : 'Save to New Folder';
    }
    final folder = ref.read(databaseProvider).folders[_selectedFolderId];
    if (folder != null) return 'Save to ${folder.name}';
    return 'Save';
  }

  List<Widget> _buildFolderTiles(
    Map<String, FolderModel> folders,
    String? parentId,
    int depth,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final childFolders =
        folders.entries.where((e) => e.value.parentId == parentId).toList()
          ..sort((a, b) => a.value.order.compareTo(b.value.order));

    List<Widget> tiles = [];
    for (final child in childFolders) {
      final isSelected = _selectedFolderId == child.key;
      tiles.add(
        ListTile(
          contentPadding: EdgeInsets.only(
            left: 24.0 + (depth * 24.0),
            right: 24,
          ),
          dense: true,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.folder,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 20,
          ),
          title: Text(
            child.value.name,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: child.value.associatedTags.isNotEmpty
              ? Text(
                  child.value.associatedTags.join(', '),
                  style: textTheme.bodySmall,
                )
              : null,
          onTap: () {
            setState(() {
              _selectedFolderId = child.key;
              _showNewFolderField = false;
            });
            Navigator.pop(context);
          },
        ),
      );
      tiles.addAll(_buildFolderTiles(folders, child.key, depth + 1));
    }
    return tiles;
  }

  void _showFolderPickerSheet() {
    final database = ref.read(databaseProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final folderTiles = _buildFolderTiles(database.folders, null, 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose Folder',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  _selectedFolderId == null ? Icons.check_circle : Icons.inbox,
                  color: _selectedFolderId == null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'Inbox',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: _selectedFolderId == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedFolderId = null;
                    _showNewFolderField = false;
                  });
                  Navigator.pop(ctx);
                },
              ),
              if (folderTiles.isNotEmpty) const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(children: folderTiles),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  _selectedFolderId == '__new__'
                      ? Icons.check_circle
                      : Icons.create_new_folder,
                  color: _selectedFolderId == '__new__'
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'New Folder...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: _selectedFolderId == '__new__'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedFolderId = '__new__';
                    _showNewFolderField = true;
                  });
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final database = ref.watch(databaseProvider);

    _initFolderSelection();

    String folderDisplayName = 'Inbox';
    if (_selectedFolderId == '__new__') {
      folderDisplayName = _newFolderController.text.trim();
      if (folderDisplayName.isEmpty) folderDisplayName = 'New Folder...';
    } else if (_selectedFolderId != null) {
      final folder = database.folders[_selectedFolderId];
      if (folder != null) folderDisplayName = folder.name;
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Save to Quire',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Document Name',
                  hintText: 'e.g., Biology Chapter 4',
                  prefixIcon: Icon(
                    Icons.description,
                    color: colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),

              if (widget.isDuplicate) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A file with this name already exists.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Replace existing file',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  value: _replaceDuplicate,
                  onChanged: (v) =>
                      setState(() => _replaceDuplicate = v ?? false),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              Text(
                'Save to folder',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showFolderPickerSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedFolderId == null ? Icons.inbox : Icons.folder,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          folderDisplayName,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showNewFolderField) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _newFolderController,
                  decoration: InputDecoration(
                    hintText: 'Enter folder name',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _replaceDuplicate
                        ? 'Replace & ${_saveButtonLabel()}'
                        : _saveButtonLabel(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
