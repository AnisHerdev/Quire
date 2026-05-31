import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/database_provider.dart';
import '../models/database_model.dart';
import '../providers/drive_provider.dart';
import '../utils/mime_utils.dart';
import '../providers/auth_provider.dart';
import '../widgets/expandable_fab.dart';
import '../widgets/move_file_dialog.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/thumbnail_provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../providers/view_mode_provider.dart';
import '../providers/card_size_provider.dart';

class DirectoryScreen extends ConsumerStatefulWidget {
  final String folderId;
  final int depth;

  const DirectoryScreen({
    super.key, 
    required this.folderId,
    required this.depth,
  });

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();

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
                  ref.read(databaseProvider.notifier).addFolder(
                    nameController.text,
                    widget.folderId,
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
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        if (!mounted) return;

        final paths = <String>[];
        final names = <String>[];
        int skipped = 0;

        for (var pickedFile in result.files) {
          if (pickedFile.path != null && isSupportedExtension(pickedFile.name)) {
            paths.add(pickedFile.path!);
            names.add(pickedFile.name);
          } else {
            skipped++;
          }
        }

        if (skipped > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(skipped == 1
                  ? 'Skipped 1 unsupported file'
                  : 'Skipped $skipped unsupported files'),
            ),
          );
        }

        if (paths.isNotEmpty) {
          await ref.read(databaseProvider.notifier).addPickedFiles(paths, names, widget.folderId);
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              if (widget.depth < 3)
                ListTile(
                  leading: const Icon(Icons.create_new_folder, size: 28),
                  title: const Text('Add Folder'),
                  subtitle: const Text('Create a sub-folder'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddFolderDialog();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.upload_file, size: 28),
                title: const Text('Upload File'),
                subtitle: const Text('Add PDF documents'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadFiles();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteFolderDialog(FolderModel folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Are you sure you want to delete "${folder.name}" and all its contents? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(databaseProvider.notifier).deleteFolder(folder.id);
              Navigator.pop(context);
              context.pop(); // Go back since this folder is deleted
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFileDialog(String fileId, QuireFileModel file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _executeDelete([fileId]);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  bool _isEditMode = false;
  Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    ref.read(fileViewModeProvider.notifier).init();
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

  void _handleDeleteMultiple() {
    final database = ref.read(databaseProvider);
    final selectedFolders = _selectedItems.where((id) => database.folders.containsKey(id)).toList();
    final selectedFiles = _selectedItems.where((id) => database.files.containsKey(id)).toList();

    if (selectedFolders.isEmpty && selectedFiles.isNotEmpty) {
      _showDeleteMultipleFilesDialog(selectedFiles);
    } else if (selectedFolders.isNotEmpty) {
      _showDeleteMultipleMixedDialog(selectedFolders, selectedFiles);
    }
  }

  void _showDeleteMultipleFilesDialog(List<String> fileIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: const Text('Are you sure you want to delete these files? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              _executeDelete(fileIds);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMultipleMixedDialog(List<String> folderIds, List<String> fileIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileIds.isEmpty ? 'Delete Folders' : 'Delete Items'),
        content: Text(fileIds.isNotEmpty 
          ? 'You have selected ${fileIds.length} file(s) and ${folderIds.length} folder(s).\n\nIf you choose to un-categorize, the selected files and folder contents will be moved to your Inbox. Otherwise, they will all be deleted.'
          : 'What would you like to do with the files inside these selected folders?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final db = ref.read(databaseProvider.notifier);
              if (fileIds.isNotEmpty) db.moveFiles(fileIds, null);
              for (var id in folderIds) {
                db.deleteFolder(id, keepFiles: true);
              }
              Navigator.pop(context);
              _clearSelection();
            },
            child: Text(fileIds.isNotEmpty ? 'Un-categorize All' : 'Keep Contents (Move to Inbox)'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              final db = ref.read(databaseProvider.notifier);
              if (fileIds.isNotEmpty) {
                Navigator.pop(context);
                _executeDelete(fileIds);
              } else {
                Navigator.pop(context);
              }
              for (var id in folderIds) {
                db.deleteFolder(id, keepFiles: false);
              }
              _clearSelection();
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _executeDelete(List<String> fileIds) async {
    try {
      await ref.read(databaseProvider.notifier).deleteFiles(fileIds);
      if (mounted) {
        _clearSelection();
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('FileNotFoundOnDrive')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('File Not Found'),
              content: const Text('This file was not found on Google Drive. It may have been deleted externally. Do you want to remove the local placeholder?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(databaseProvider.notifier).deleteFiles(fileIds, forceLocalDelete: true);
                    if (mounted) _clearSelection();
                  },
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: $e')),
        );
      }
    }
  }

  void _showFolderOptions(BuildContext context, String folderId, FolderModel folder) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: colorScheme.primary),
              title: Text('Rename Folder', style: TextStyle(color: colorScheme.primary)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameFolderDialog(folderId, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.label, color: colorScheme.primary),
              title: Text('Edit Tags', style: TextStyle(color: colorScheme.primary)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditFolderTagsDialog(folderId, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: colorScheme.error),
              title: Text('Delete Folder', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteChildFolderDialog(folderId, folder);
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
                ref.read(databaseProvider.notifier).renameFolder(folderId, newName);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteChildFolderDialog(String folderId, FolderModel folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text('What would you like to do with the files inside this folder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(databaseProvider.notifier).deleteFolder(folderId, keepFiles: true);
              Navigator.pop(context);
            },
            child: const Text('Keep Files (Move to Inbox)'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              ref.read(databaseProvider.notifier).deleteFolder(folderId, keepFiles: false);
              Navigator.pop(context);
            },
            child: const Text('Delete Folder & Files'),
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
          title: Text('Tags for '),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final database = ref.watch(databaseProvider);
    
    final folder = database.folders[widget.folderId];
    if (folder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Folder not found')),
        body: const Center(child: Text('This folder may have been deleted.')),
      );
    }

    final childFolders = database.folders.values
        .where((f) => f.parentId == widget.folderId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final childFiles = database.files.entries
        .where((e) => e.value.folderId == widget.folderId)
        .toList()
      ..sort((a, b) => b.value.addedAt.compareTo(a.value.addedAt));

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
              title: Text('${_selectedItems.length} selected'),
              actions: [
                if (_selectedItems.length == 1 && database.folders.containsKey(_selectedItems.first))
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      final folderToRename = database.folders[_selectedItems.first];
                      if (folderToRename != null) {
                        _showRenameFolderDialog(_selectedItems.first, folderToRename);
                        _clearSelection();
                      }
                    },
                  ),
                if (_selectedItems.every((id) => database.files.containsKey(id)))
                  IconButton(
                    icon: const Icon(Icons.drive_file_move),
                    onPressed: () {
                      final selectedList = _selectedItems.toList();
                      _clearSelection();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => MoveFileDialog(fileIds: selectedList),
                      ).then((undoFunc) {
                        if (undoFunc != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Files moved successfully'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: undoFunc as void Function(),
                              ),
                            ),
                          );
                        }
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _handleDeleteMultiple,
                ),
              ],
            )
          : AppBar(
              backgroundColor: colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
                onPressed: () => context.pop(),
              ),
              title: Text(
                folder.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    ref.watch(fileViewModeProvider) ? Icons.view_list : Icons.grid_view,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => ref.read(fileViewModeProvider.notifier).toggle(),
                ),
                IconButton(
                  icon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                  onPressed: () => context.push('/search'),
                ),
              ],
            ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24.0),
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
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outlineVariant),
                    prefixIcon: Icon(Icons.search, color: colorScheme.outline),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (childFolders.isEmpty && childFiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64.0),
                  child: Center(
                    child: Text(
                      "This folder is empty.\nTap + to add content.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
                    ),
                  ),
                )
              else ...[
                if (childFolders.isNotEmpty) ...[
                  Text('Folders', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                  const SizedBox(height: 12),
                  if (!_isEditMode)
                    GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: ref.watch(cardSizeProvider).maxExtent,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: childFolders.length,
                      itemBuilder: (context, index) {
                        final child = childFolders[index];
                        return _buildFolderCard(
                          key: ValueKey(child.id),
                          context: context, 
                          childFolder: child,
                          index: index,
                        );
                      },
                    )
                  else
                    ReorderableGridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: ref.watch(cardSizeProvider).maxExtent,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: childFolders.length,
                      onReorder: (oldIndex, newIndex) {
                        final folder = childFolders.removeAt(oldIndex);
                        childFolders.insert(newIndex, folder);
                        ref.read(databaseProvider.notifier).reorderFolders(
                          childFolders.map((f) => f.id).toList()
                        );
                      },
                      itemBuilder: (context, index) {
                        final child = childFolders[index];
                        return _buildFolderCard(
                          key: ValueKey(child.id),
                          context: context, 
                          childFolder: child,
                          index: index,
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                ],
                
                if (childFiles.isNotEmpty) ...[
                  Text('Files', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                  const SizedBox(height: 12),
                  if (!ref.watch(fileViewModeProvider))
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: childFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final fileEntry = childFiles[index];
                        return _buildFileTile(context, fileEntry.key, fileEntry.value);
                      },
                    )
                  else
                    GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: ref.watch(cardSizeProvider).maxExtent,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: childFiles.length,
                      itemBuilder: (context, index) {
                        final fileEntry = childFiles[index];
                        return _buildFileGridCard(context, fileEntry.key, fileEntry.value);
                      },
                    ),
                ],
              ],
            ],
          ),
          ExpandableFab(
            key: _fabKey,
            distance: 64.0,
            children: [
              if (widget.depth < 3)
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
    ));
  }

  Widget _buildFolderCard({
    Key? key,
    required BuildContext context, 
    required FolderModel childFolder,
    int? index,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final isSelected = _selectedItems.contains(childFolder.id);

    return InkWell(
      key: key,
      onTap: () {
        if (_isEditMode) {
          _toggleSelection(childFolder.id);
        } else {
          context.push('/folder/${childFolder.id}', extra: widget.depth + 1);
        }
      },
      onLongPress: _isEditMode ? null : () {
        setState(() {
          _isEditMode = true;
          _selectedItems.add(childFolder.id);
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
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
                    color: isSelected ? colorScheme.primary : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.folder, 
                    color: isSelected ? colorScheme.onPrimary : colorScheme.primary
                  ),
                ),
                if (_isEditMode)
                  index != null 
                    ? ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_indicator, color: colorScheme.onSurfaceVariant),
                      )
                    : Icon(Icons.drag_indicator, color: colorScheme.onSurfaceVariant)
                else
                  IconButton(
                    icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showFolderOptions(context, childFolder.id, childFolder),
                  ),
              ],
            ),
            Text(
              childFolder.name,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFileExternally(QuireFileModel file, String fileId) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = extensionForMimeType(file.mimeType);
    final filePath = '${dir.path}/pdf_cache/$fileId$ext';
    final localFile = File(filePath);

    if (!await localFile.exists()) {
      if (file.driveId == null || file.driveId!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not available offline. Please sync first.')),
          );
        }
        return;
      }
      final driveService = ref.read(driveServiceProvider);
      final bytes = await driveService.downloadFile(file.driveId!);
      await localFile.writeAsBytes(bytes);
    }

    try {
      final result = await OpenFilex.open(filePath, type: file.mimeType);
      if (result != null && result.type == 'error' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  Widget _buildFileTile(BuildContext context, String fileId, QuireFileModel file) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final isSelected = _selectedItems.contains(fileId);

    return InkWell(
      onLongPress: () {
        if (!_isEditMode) {
          setState(() {
            _isEditMode = true;
            _selectedItems.add(fileId);
          });
        }
      },
      onTap: () async {
        if (_isEditMode) {
          _toggleSelection(fileId);
        } else {
          if (file.mimeType == 'application/pdf') {
            context.push('/pdf-viewer/$fileId');
          } else {
            await _openFileExternally(file, fileId);
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? Icons.check : 
                (file.mimeType.contains('word') || file.mimeType.contains('document') ? Icons.description :
                 file.mimeType.contains('powerpoint') || file.mimeType.contains('presentation') ? Icons.slideshow :
                 Icons.picture_as_pdf), 
                color: isSelected ? colorScheme.onPrimary : 
                (file.mimeType.contains('word') || file.mimeType.contains('document') ? Colors.blue :
                 file.mimeType.contains('powerpoint') || file.mimeType.contains('presentation') ? Colors.orange :
                 colorScheme.secondary)
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        file.lastSyncError != null
                            ? (file.lastSyncError!.contains('401') ? Icons.hourglass_empty : Icons.error_outline)
                            : file.syncStatus == 'synced' ? Icons.cloud_done : Icons.cloud_upload,
                        size: 14,
                        color: file.lastSyncError != null
                            ? (file.lastSyncError!.contains('401') ? colorScheme.onSurfaceVariant : colorScheme.error)
                            : colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Tooltip(
                          message: file.lastSyncError ?? '',
                          child: Text(
                            file.lastSyncError != null
                                ? (file.lastSyncError!.contains('401') ? 'Waiting for Drive...' : 'Sync error')
                                : file.syncStatus == 'synced' ? 'Synced' : 'Pending',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: file.lastSyncError != null
                                  ? (file.lastSyncError!.contains('401') ? colorScheme.onSurfaceVariant : colorScheme.error)
                                  : colorScheme.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_isEditMode)
              IconButton(
                icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.open_in_new, color: colorScheme.primary),
                            title: Text('Open externally', style: TextStyle(color: colorScheme.primary)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await _openFileExternally(file, fileId);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.drive_file_move, color: colorScheme.primary),
                            title: Text('Move File', style: TextStyle(color: colorScheme.primary)),
                            onTap: () {
                              Navigator.pop(ctx);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => MoveFileDialog(fileIds: [fileId]),
                              ).then((undoFunc) {
                                if (undoFunc != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('File moved successfully'),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: undoFunc as void Function(),
                                      ),
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete, color: colorScheme.error),
                            title: Text('Delete File', style: TextStyle(color: colorScheme.error)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showDeleteFileDialog(fileId, file);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileGridCard(BuildContext context, String fileId, QuireFileModel file) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedItems.contains(fileId);

    IconData fallbackIcon;
    Color iconColor;
    
    if (file.mimeType.contains('pdf')) {
      fallbackIcon = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (file.mimeType.contains('presentation') || file.mimeType.contains('powerpoint')) {
      fallbackIcon = Icons.slideshow;
      iconColor = Colors.orange;
    } else if (file.mimeType.contains('document') || file.mimeType.contains('wordprocessingml')) {
      fallbackIcon = Icons.description;
      iconColor = Colors.blue;
    } else if (file.mimeType.contains('text')) {
      fallbackIcon = Icons.text_snippet;
      iconColor = Colors.green;
    } else {
      fallbackIcon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    return InkWell(
      onLongPress: () {
        if (!_isEditMode) {
          setState(() {
            _isEditMode = true;
            _selectedItems.add(fileId);
          });
        }
      },
      onTap: () async {
        if (_isEditMode) {
          _toggleSelection(fileId);
        } else {
          if (file.mimeType == 'application/pdf') {
            context.push('/pdf-viewer/$fileId');
          } else {
            await _openFileExternally(file, fileId);
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: file.driveId != null
                  ? Consumer(
                      builder: (context, ref, _) {
                        final thumbAsync = ref.watch(thumbnailProvider(file.driveId!));
                        return thumbAsync.when(
                          data: (bytes) {
                            if (bytes != null) {
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(bytes, fit: BoxFit.cover),
                                  if (isSelected)
                                    Container(
                                      color: colorScheme.primary.withOpacity(0.3),
                                      child: Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 32),
                                    ),
                                ],
                              );
                            }
                            return _buildFallbackThumbnail(colorScheme, fallbackIcon, iconColor, isSelected);
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => _buildFallbackThumbnail(colorScheme, fallbackIcon, iconColor, isSelected),
                        );
                      }
                    )
                  : _buildFallbackThumbnail(colorScheme, fallbackIcon, iconColor, isSelected),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          file.name,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isEditMode)
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: Icon(Icons.open_in_new, color: colorScheme.primary),
                                      title: Text('Open externally', style: TextStyle(color: colorScheme.primary)),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await _openFileExternally(file, fileId);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.drive_file_move),
                                      title: const Text('Move to...'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (context) => MoveFileDialog(fileIds: [fileId]),
                                        ).then((undoFunc) {
                                          if (undoFunc != null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text('File moved successfully'),
                                                action: SnackBarAction(label: 'Undo', onPressed: undoFunc as void Function()),
                                              ),
                                            );
                                          }
                                        });
                                      },
                                    ),
                                    ListTile(
                                      leading: Icon(Icons.delete, color: colorScheme.error),
                                      title: Text('Delete File', style: TextStyle(color: colorScheme.error)),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _showDeleteFileDialog(fileId, file);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Icon(Icons.more_vert, size: 16, color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        file.lastSyncError != null
                            ? (file.lastSyncError!.contains('401') ? Icons.hourglass_empty : Icons.error_outline)
                            : file.syncStatus == 'synced' ? Icons.cloud_done : Icons.cloud_upload,
                        size: 12,
                        color: file.lastSyncError != null
                            ? (file.lastSyncError!.contains('401') ? colorScheme.onSurfaceVariant : colorScheme.error)
                            : colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: file.lastSyncError ?? '',
                        child: Text(
                          file.lastSyncError != null
                              ? (file.lastSyncError!.contains('401') ? 'Waiting for Drive...' : 'Sync error')
                              : file.syncStatus == 'synced' ? 'Synced' : 'Pending',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: file.lastSyncError != null
                                ? (file.lastSyncError!.contains('401') ? colorScheme.onSurfaceVariant : colorScheme.error)
                                : colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(ColorScheme colorScheme, IconData icon, Color iconColor, bool isSelected) {
    return Container(
      color: iconColor.withOpacity(0.1),
      child: Center(
        child: isSelected 
          ? Icon(Icons.check_circle, color: colorScheme.primary, size: 48)
          : Icon(icon, color: iconColor, size: 48),
      ),
    );
  }
}
