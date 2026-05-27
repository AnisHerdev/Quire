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

        final dbNotifier = ref.read(databaseProvider.notifier);
        final state = ref.read(databaseProvider);
        final updatedFiles = Map<String, QuireFileModel>.from(state.files);
        
        final dir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory('${dir.path}/pdf_cache');
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }

        bool changed = false;

        for (var pickedFile in result.files) {
          if (pickedFile.path != null) {
            final file = File(pickedFile.path!);
            const uuid = Uuid();
            final localId = 'local_${uuid.v4()}';
            
            final localFile = File('${cacheDir.path}/$localId.pdf');
            await file.copy(localFile.path);

            final newFile = QuireFileModel(
              name: pickedFile.name,
              mimeType: 'application/pdf',
              folderId: widget.folderId,
              addedAt: DateTime.now().millisecondsSinceEpoch,
              tags: [],
              syncStatus: 'pending',
              driveId: null,
            );
            
            updatedFiles[localId] = newFile;
            changed = true;
          }
        }

        if (changed) {
          // This is a bit of a hack since processSharedFiles is what triggers background upload, 
          // but we can just update the state and let the user manually sync or we can trigger it.
          // For simplicity, we just save it. It will sync on next app launch or we can call sync.
          dbNotifier.state = state.copyWith(files: updatedFiles);
          await dbNotifier.init(); // trigger sync
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
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            onPressed: () => _showDeleteFolderDialog(folder),
          ),
        ],
      ),
      body: childFolders.isEmpty && childFiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  "This folder is empty.\nTap + to add content.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                if (childFolders.isNotEmpty) ...[
                  Text('Folders', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: childFolders.length,
                    itemBuilder: (context, index) {
                      final child = childFolders[index];
                      return _buildFolderCard(context, child);
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context, FolderModel childFolder) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.folder, color: colorScheme.primary),
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
    
    return InkWell(
      onTap: () {
        context.push('/viewer/$fileId');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.surfaceVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.picture_as_pdf, color: colorScheme.secondary),
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
