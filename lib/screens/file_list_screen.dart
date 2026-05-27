import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/drive_provider.dart';
import '../models/note_file_model.dart';

class FileListScreen extends ConsumerWidget {
  final String folderId;

  const FileListScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final filesAsyncValue = ref.watch(folderFilesProvider(folderId));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
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
          'Folder', // Could be passed as a param or we can fetch folder metadata later
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
            onPressed: () {},
          ),
        ],
      ),
      body: filesAsyncValue.when(
        data: (files) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumbs (simplified for now, full path handled in recursive fetch later)
                Row(
                  children: [
                    Icon(Icons.home, size: 18, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Home', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 16, color: colorScheme.outlineVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Folder View', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (files.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        "This folder is empty.",
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
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return _buildFileCard(context: context, file: file);
                    },
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading files: $err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(folderFilesProvider(folderId)),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard({
    required BuildContext context,
    required NoteFileModel file,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final isFolder = file.isFolder;
    
    // Determine icons and colors based on mimeType
    IconData icon;
    Color iconColor;
    
    if (isFolder) {
      icon = Icons.folder;
      iconColor = colorScheme.primaryContainer;
    } else if (file.mimeType.contains('pdf')) {
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

    final String sizeStr = file.size != null 
        ? '${(file.size! / 1024).toStringAsFixed(1)} KB' 
        : (isFolder ? '' : 'Unknown');
        
    final String dateStr = file.modifiedTime != null 
        ? '${file.modifiedTime!.year}-${file.modifiedTime!.month.toString().padLeft(2, '0')}-${file.modifiedTime!.day.toString().padLeft(2, '0')}' 
        : '';

    return InkWell(
      onTap: () {
        if (isFolder) {
          context.push('/folder/${file.id}');
        } else {
          context.push('/pdf-viewer/${file.id}');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
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
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant, size: 20),
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
                if (!isFolder && sizeStr.isNotEmpty) ...[
                  Text(sizeStr, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                ],
                Expanded(child: Text(dateStr, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
