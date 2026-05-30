import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/database_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sharing_service.dart';
import '../models/database_model.dart';
import '../utils/mime_utils.dart';
import '../widgets/expandable_fab.dart';
import '../widgets/tag_picker_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();

  bool _isEditMode = false;
  Set<String> _selectedItems = {};

  Future<List<SharedMediaFile>> _copySharedFilesToImportCache(
    List<SharedMediaFile> files,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final importDir = Directory('${dir.path}/share_imports');
    if (!await importDir.exists()) {
      await importDir.create(recursive: true);
    }

    final copiedFiles = <SharedMediaFile>[];
    for (var i = 0; i < files.length; i++) {
      final sharedFile = files[i];
      final sourceFile = File(sharedFile.path);
      if (!await sourceFile.exists()) continue;

      final originalName = sharedFile.path.split(Platform.pathSeparator).last;
      final extension = originalName.contains('.')
          ? originalName.substring(originalName.lastIndexOf('.'))
          : '';
      final importPath =
          '${importDir.path}/${DateTime.now().microsecondsSinceEpoch}_$i$extension';
      await sourceFile.copy(importPath);

      copiedFiles.add(
        SharedMediaFile(
          path: importPath,
          type: sharedFile.type,
          thumbnail: sharedFile.thumbnail,
          duration: sharedFile.duration,
          mimeType: sharedFile.mimeType,
          message: sharedFile.message,
        ),
      );
    }

    return copiedFiles;
  }

  Future<bool> _hasExistingFileForName(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/pdf_cache');
    final database = ref.read(databaseProvider);

    for (final entry in database.files.entries) {
      if (entry.value.name.toLowerCase() != name.toLowerCase()) continue;
      if (entry.value.driveId != null) return true;

      final ext = extensionForMimeType(entry.value.mimeType);
      final cachedFile = File('${cacheDir.path}/${entry.key}$ext');
      if (await cachedFile.exists()) return true;
    }

    return false;
  }

  Future<void> _deleteImportCopies(List<SharedMediaFile> files) async {
    for (final file in files) {
      try {
        final localFile = File(file.path);
        if (await localFile.exists()) {
          await localFile.delete();
        }
      } catch (_) {}
    }
  }

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
        if (_selectedItems.isEmpty) _isEditMode = false;
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItems.clear();
      _isEditMode = false;
    });
  }

  void _showDeleteMultipleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folders'),
        content: const Text(
          'What would you like to do with the files inside these folders?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              for (var id in _selectedItems) {
                ref
                    .read(databaseProvider.notifier)
                    .deleteFolder(id, keepFiles: true);
              }
              Navigator.pop(context);
              _clearSelection();
            },
            child: const Text('Keep Contents (Move to Inbox)'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              for (var id in _selectedItems) {
                ref
                    .read(databaseProvider.notifier)
                    .deleteFolder(id, keepFiles: false);
              }
              Navigator.pop(context);
              _clearSelection();
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Initialize the database (loads cache instantly, then syncs to cloud)
      ref.read(databaseProvider.notifier).init();

      // Initialize OS share sheet listener
      ref.read(sharingServiceProvider).init((files) async {
        if (!mounted || files.isEmpty) return;

        final stableFiles = await _copySharedFilesToImportCache(files);
        if (stableFiles.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not access the shared file. Please try sharing it again.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        List<String>? customNames;
        List<String>? tags;
        String? folderName;
        bool replaceDuplicate = false;

        if (stableFiles.length == 1) {
          String initialName = files.first.path
              .split(Platform.pathSeparator)
              .last;
          if (initialName.contains('share_') ||
              initialName.contains(RegExp(r'[0-9]{10}'))) {
            initialName = 'Document.pdf';
          }

          final isDuplicate = await _hasExistingFileForName(initialName);
          if (!mounted) {
            await _deleteImportCopies(stableFiles);
            return;
          }

          final tagResult = await showTagPickerSheet(
            context: context,
            filename: initialName,
            isDuplicate: isDuplicate,
          );
          if (tagResult == null) {
            await _deleteImportCopies(stableFiles);
            return;
          }
          if (!mounted) {
            await _deleteImportCopies(stableFiles);
            return;
          }

          final customName = tagResult.customName ?? initialName;
          customNames = List.filled(stableFiles.length, customName);
          tags = tagResult.folderTags;
          folderName = tagResult.folderName;
          replaceDuplicate = tagResult.replaceDuplicate;

          final folderLabel =
              (folderName != null && folderName.isNotEmpty) ? folderName : 'Inbox';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saving "$customName" to $folderLabel...'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          customNames = files.map((f) =>
            f.path.split(Platform.pathSeparator).last,
          ).toList();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saving to Inbox...'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        try {
          await ref
              .read(databaseProvider.notifier)
              .processSharedFiles(
                stableFiles,
                customNames: customNames,
                tags: tags,
                folderName: folderName,
                replaceDuplicate: replaceDuplicate,
              );
        } catch (e) {
          if (mounted) {
            final msg = (e is StateError && e.message.contains('authenticated'))
                ? 'Please sign in to Quire first to save shared files.'
                : 'Failed to save: ${e.toString()}';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          await _deleteImportCopies(stableFiles);
        }
      });
    });
  }

  void _showAddFolderDialog() {
    final nameController = TextEditingController();
    final tagController = TextEditingController();
    final selectedTags = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Folder Name',
                  hintText: 'e.g. Workspace',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'Add tag...',
                        isDense: true,
                      ),
                      onSubmitted: (value) {
                        final tag = value.trim().toUpperCase();
                        if (tag.isNotEmpty && !selectedTags.contains(tag)) {
                          setDialogState(() {
                            selectedTags.add(tag);
                            tagController.clear();
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final tag = tagController.text.trim().toUpperCase();
                      if (tag.isNotEmpty && !selectedTags.contains(tag)) {
                        setDialogState(() {
                          selectedTags.add(tag);
                          tagController.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                ],
              ),
              if (selectedTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: selectedTags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 11),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () =>
                              setDialogState(() => selectedTags.remove(tag)),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ref
                      .read(databaseProvider.notifier)
                      .addFolder(
                        nameController.text,
                        null,
                        associatedTags: selectedTags.toList(),
                      );
                }
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFiles() async {
    final authState = ref.read(authProvider);
    if (authState.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add files')),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
        allowMultiple: true,
      );

      if (result != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing ${result.files.length} file(s)...'),
          ),
        );

        final paths = <String>[];
        final names = <String>[];

        for (var pickedFile in result.files) {
          if (pickedFile.path != null) {
            paths.add(pickedFile.path!);
            names.add(pickedFile.name);
          }
        }

        if (paths.isNotEmpty) {
          await ref
              .read(databaseProvider.notifier)
              .addPickedFiles(paths, names, null);
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  void _showFolderOptions(
    BuildContext context,
    String folderId,
    FolderModel folder,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: colorScheme.primary),
              title: Text(
                'Rename Folder',
                style: TextStyle(color: colorScheme.primary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameFolderDialog(folderId, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.label, color: colorScheme.primary),
              title: Text(
                'Edit Tags',
                style: TextStyle(color: colorScheme.primary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showEditFolderTagsDialog(folderId, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: colorScheme.error),
              title: Text(
                'Delete Folder',
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteFolderDialog(folderId, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameFolderDialog(String folderId, FolderModel folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref
                    .read(databaseProvider.notifier)
                    .renameFolder(folderId, newName);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditFolderTagsDialog(String folderId, FolderModel folder) {
    final tagController = TextEditingController();
    final selectedTags = List<String>.from(folder.associatedTags);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Tags for ${folder.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Add Tag',
                        hintText: 'Enter tag...',
                        isDense: true,
                      ),
                      onSubmitted: (value) {
                        final tag = value.trim().toUpperCase();
                        if (tag.isNotEmpty && !selectedTags.contains(tag)) {
                          setDialogState(() {
                            selectedTags.add(tag);
                            tagController.clear();
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final tag = tagController.text.trim().toUpperCase();
                      if (tag.isNotEmpty && !selectedTags.contains(tag)) {
                        setDialogState(() {
                          selectedTags.add(tag);
                          tagController.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                ],
              ),
              if (selectedTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: selectedTags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 11),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () =>
                              setDialogState(() => selectedTags.remove(tag)),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final updatedFolders = Map<String, FolderModel>.from(
                  ref.read(databaseProvider).folders,
                );
                updatedFolders[folderId] = folder.copyWith(
                  associatedTags: selectedTags,
                );
                ref
                    .read(databaseProvider.notifier)
                    .updateFolderState(updatedFolders);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteFolderDialog(String folderId, FolderModel folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text(
          'What would you like to do with the files inside this folder?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(databaseProvider.notifier)
                  .deleteFolder(folderId, keepFiles: true);
              Navigator.pop(context);
            },
            child: const Text('Keep Files (Move to Inbox)'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref
                  .read(databaseProvider.notifier)
                  .deleteFolder(folderId, keepFiles: false);
              Navigator.pop(context);
            },
            child: const Text('Delete Folder & Files'),
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

    final authState = ref.watch(authProvider);
    final database = ref.watch(databaseProvider);

    final rootFolders =
        database.folders.values.where((f) => f.parentId == null).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final inboxCount = database.files.values
        .where((f) => f.folderId == null)
        .length;

    return PopScope(
      canPop: !_isEditMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isEditMode) {
          _clearSelection();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: _isEditMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
                title: Text('${_selectedItems.length} Selected'),
                actions: [
                  if (_selectedItems.length == 1)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        final folder = database.folders[_selectedItems.first];
                        if (folder != null) {
                          _showRenameFolderDialog(_selectedItems.first, folder);
                          _clearSelection();
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      if (_selectedItems.length == 1) {
                        final folder = database.folders[_selectedItems.first];
                        if (folder != null) {
                          _showDeleteFolderDialog(_selectedItems.first, folder);
                        }
                      } else {
                        _showDeleteMultipleDialog();
                      }
                    },
                  ),
                ],
              )
            : AppBar(
                title: Text(
                  authState.user?.displayName ?? 'Quire',
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                actions: [
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: authState.user?.photoUrl.isNotEmpty == true
                        ? NetworkImage(authState.user!.photoUrl)
                        : null,
                    child: authState.user?.photoUrl.isEmpty == true
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 16),
                ],
              ),
        body: Stack(
          children: [
            if (ref.watch(syncInProgressProvider))
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.surfaceVariant),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primaryContainer.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      onTap: () {
                        context.push('/search');
                      },
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Search your notes, texts, or authors...',
                        hintStyle: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.outlineVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: colorScheme.outline,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Inbox Section (Only visible if there are unorganized files)
                  if (inboxCount > 0) ...[
                    _buildInboxCard(context, inboxCount),
                    const SizedBox(height: 32),
                  ],

                  // Section Header
                  Text('Your Folders', style: textTheme.headlineMedium),
                  const SizedBox(height: 24),

                  // Dynamic Content Area
                  if (rootFolders.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          "No folders found. Tap + to create one.",
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ),
                    )
                  else if (!_isEditMode)
                    GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rootFolders.length,
                      itemBuilder: (context, index) {
                        final folder = rootFolders[index];
                        return _buildFolderCard(
                          key: ValueKey(folder.id),
                          context: context,
                          folder: folder,
                          index: index,
                        );
                      },
                    )
                  else
                    ReorderableGridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rootFolders.length,
                      onReorder: (oldIndex, newIndex) {
                        final folder = rootFolders.removeAt(oldIndex);
                        rootFolders.insert(newIndex, folder);
                        ref
                            .read(databaseProvider.notifier)
                            .reorderFolders(
                              rootFolders.map((f) => f.id).toList(),
                            );
                      },
                      itemBuilder: (context, index) {
                        final folder = rootFolders[index];
                        return _buildFolderCard(
                          key: ValueKey(folder.id),
                          context: context,
                          folder: folder,
                          index: index,
                        );
                      },
                    ),
                ],
              ),
            ),
            ExpandableFab(
              key: _fabKey,
              distance: 64.0,
              children: [
                ActionButton(
                  onPressed: () {
                    _fabKey.currentState?.close();
                    _showAddFolderDialog();
                  },
                  icon: const Icon(Icons.create_new_folder),
                  label: 'Add Folder',
                ),
                ActionButton(
                  onPressed: () {
                    _fabKey.currentState?.close();
                    _pickAndUploadFiles();
                  },
                  icon: const Icon(Icons.upload_file),
                  label: 'Upload File',
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      ),
    );
  }

  Widget _buildFolderCard({
    Key? key,
    required BuildContext context,
    required FolderModel folder,
    int? index,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isSelected = _selectedItems.contains(folder.id);

    return InkWell(
      key: key,
      onTap: () {
        if (_isEditMode) {
          _toggleSelection(folder.id);
        } else {
          context.push(
            '/folder/${folder.id}',
            extra: 1,
          ); // Depth is 1 for children of root folders
        }
      },
      onLongPress: _isEditMode
          ? null
          : () {
              setState(() {
                _isEditMode = true;
                _selectedItems.add(folder.id);
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: colorScheme.primaryContainer.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.folder_special,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                  ),
                ),
                if (_isEditMode)
                  index != null
                      ? ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            Icons.drag_indicator,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Icon(
                          Icons.drag_indicator,
                          color: colorScheme.onSurfaceVariant,
                        )
                else
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        _showFolderOptions(context, folder.id, folder),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      folder.syncStatus == 'synced'
                          ? Icons.cloud_done
                          : Icons.cloud_upload,
                      size: 12,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      folder.syncStatus == 'synced' ? 'Synced' : 'Pending',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxCard(BuildContext context, int count) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: () {
        context.push('/inbox');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.secondary),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.download, color: colorScheme.onSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Needs Organization',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Shared from external apps',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count.toString(),
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onError,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
