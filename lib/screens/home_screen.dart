import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/database_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sharing_service.dart';
import '../models/database_model.dart';
import '../widgets/expandable_fab.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize the database (loads cache instantly, then syncs to cloud)
      ref.read(databaseProvider.notifier).init();
      
      // Initialize OS share sheet listener
      ref.read(sharingServiceProvider).init((files) async {
        if (!mounted || files.isEmpty) return;

        // Extract a clean default name
        String initialName = files.first.path.split(Platform.pathSeparator).last;
        if (initialName.contains('share_') || initialName.contains(RegExp(r'[0-9]{10}'))) {
          initialName = 'Document.pdf';
        }

        final customName = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final controller = TextEditingController(text: initialName);
            return AlertDialog(
              title: const Text('Save to Quire'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Document Name',
                  hintText: 'e.g., Biology Chapter 4',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    var name = controller.text.trim();
                    if (name.isEmpty) name = 'Untitled Document';
                    if (!name.toLowerCase().endsWith('.pdf')) name += '.pdf';
                    Navigator.pop(context, name);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );

        if (customName == null) return; // User cancelled

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saving "$customName" to Inbox...'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        try {
          final namesList = List.filled(files.length, customName);
          await ref.read(databaseProvider.notifier).processSharedFiles(files, customNames: namesList);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please sign in to Quire first to save shared files.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    });
  }

  void _showAddFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Workspace'),
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
                ref.read(databaseProvider.notifier).addFolder(controller.text, null);
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
          await ref.read(databaseProvider.notifier).addPickedFiles(paths, names, null);
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final authState = ref.watch(authProvider);
    final database = ref.watch(databaseProvider);
    
    final rootFolders = database.folders.values
        .where((f) => f.parentId == null)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final inboxCount = database.files.values.where((f) => f.folderId == null).length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          authState.user?.displayName ?? 'Quire',
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
            onPressed: () {},
          ),
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
      body: SingleChildScrollView(
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
                  hintStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.outlineVariant),
                  prefixIcon: Icon(Icons.search, color: colorScheme.outline),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Your Folders',
                  style: textTheme.headlineMedium,
                ),
                InkWell(
                  onTap: () {},
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 18, color: colorScheme.primary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dynamic Content Area
            if (rootFolders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    "No folders found. Tap + to create one.",
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
                  childAspectRatio: 1.0,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rootFolders.length,
                itemBuilder: (context, index) {
                  final folder = rootFolders[index];
                  return _buildFolderCard(
                    context: context, 
                    folder: folder, 
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: ExpandableFab(
        distance: 64.0,
        children: [
          ActionButton(
            onPressed: () {
              _showAddFolderDialog();
            },
            icon: const Icon(Icons.create_new_folder),
            label: 'Add Folder',
          ),
          ActionButton(
            onPressed: () {
              _pickAndUploadFiles();
            },
            icon: const Icon(Icons.upload_file),
            label: 'Upload File',
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildFolderCard({
    required BuildContext context,
    required FolderModel folder,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      onTap: () {
        context.push('/folder/${folder.id}', extra: 1); // Depth is 1 for children of root folders
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
                  child: Icon(Icons.folder_special, color: colorScheme.primary),
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
                Text(
                  "Folder",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                    fontSize: 12,
                  ),
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
                      color: colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
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
