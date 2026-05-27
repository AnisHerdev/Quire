import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/drive_provider.dart';
import '../providers/auth_provider.dart';
import '../models/note_file_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final authState = ref.watch(authProvider);
    final driveState = ref.watch(driveFolderProvider);

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

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Your Notes',
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
            if (driveState.isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text("Loading your notes...", style: textTheme.bodyLarge),
                    ],
                  ),
                ),
              )
            else if (driveState.error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        driveState.error!,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(driveFolderProvider.notifier).initialize();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            else if (driveState.rootFiles.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    "No notes found. Create a folder to get started.",
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
                itemCount: driveState.rootFiles.length,
                itemBuilder: (context, index) {
                  final file = driveState.rootFiles[index];
                  return _buildFileCard(context: context, file: file);
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildFileCard({
    required BuildContext context,
    required NoteFileModel file,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final bool isFolder = file.isFolder;
    final icon = isFolder ? Icons.folder : Icons.insert_drive_file;
    final iconColor = isFolder ? colorScheme.primaryContainer : colorScheme.secondaryContainer;
    
    // Drive API doesn't return immediate child counts, so we use modified time or generic text for files
    final subtitle = isFolder 
        ? "Folder" 
        : (file.modifiedTime != null ? '${file.modifiedTime!.year}-${file.modifiedTime!.month.toString().padLeft(2, '0')}-${file.modifiedTime!.day.toString().padLeft(2, '0')}' : "File");

    return InkWell(
      onTap: () {
        if (isFolder) {
          // Changed to pass folderId via query parameter, or standard path matching
          context.push('/folder/${file.id}');
        } else {
          // If it's a file, presumably we'll have a pdf viewer route eventually
          context.push('/pdf-viewer/${file.id}');
        }
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
                  child: Icon(icon, color: iconColor),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
}
