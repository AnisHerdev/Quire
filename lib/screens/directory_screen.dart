import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/database_provider.dart';
import '../models/database_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/expandable_fab.dart';
import '../widgets/move_file_dialog.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

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
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder Name'),
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
                ref.read(databaseProvider.notifier).addFolder(controller.text, widget.folderId);
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
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
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing ${result.files.length} file(s)...')),
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
              ref.read(databaseProvider.notifier).deleteFiles([fileId]);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Set<String> _selectedFiles = {};

  void _toggleSelection(String fileId) {
    setState(() {
      if (_selectedFiles.contains(fileId)) {
        _selectedFiles.remove(fileId);
      } else {
        _selectedFiles.add(fileId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  void _showDeleteMultipleDialog(List<String> fileIds) {
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
              ref.read(databaseProvider.notifier).deleteFiles(fileIds);
              _clearSelection();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _selectedFiles.isNotEmpty
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedFiles.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.drive_file_move),
                  onPressed: () {
                    final selectedList = _selectedFiles.toList();
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
                  onPressed: () {
                    final selectedList = _selectedFiles.toList();
                    _showDeleteMultipleDialog(selectedList);
                  },
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
                  ReorderableGridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
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
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
                
                if (childFiles.isNotEmpty) ...[
                  Text('Files', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: childFiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final fileEntry = childFiles[index];
                      return _buildFileTile(context, fileEntry.key, fileEntry.value);
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
    );
  }

  Widget _buildFolderCard({
    Key? key,
    required BuildContext context, 
    required FolderModel childFolder,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      key: key,
      onTap: () {
        context.push('/folder/${childFolder.id}', extra: widget.depth + 1);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.surfaceVariant),
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
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.folder, color: colorScheme.primary),
                ),
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

  Widget _buildFileTile(BuildContext context, String fileId, QuireFileModel file) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final isSelected = _selectedFiles.contains(fileId);

    return InkWell(
      onLongPress: () => _toggleSelection(fileId),
      onTap: () {
        if (_selectedFiles.isNotEmpty) {
          _toggleSelection(fileId);
        } else {
          context.push('/pdf-viewer/$fileId');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.surfaceVariant),
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
              child: Icon(isSelected ? Icons.check : Icons.picture_as_pdf, color: isSelected ? colorScheme.onPrimary : colorScheme.secondary),
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
                        file.syncStatus == 'synced' ? Icons.cloud_done : Icons.cloud_upload,
                        size: 14,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        file.syncStatus == 'synced' ? 'Synced' : 'Pending',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_selectedFiles.isEmpty)
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
}
