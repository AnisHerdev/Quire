import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FileListScreen extends StatelessWidget {
  final String folderId;

  const FileListScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Data Structures', // Placeholder title based on folderId
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs and Sort
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.home, size: 18, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Home', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 16, color: colorScheme.outlineVariant),
                    const SizedBox(width: 8),
                    Text('Semester 1', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.sort, size: 20),
                  label: const Text('Sort'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerLow,
                    foregroundColor: colorScheme.onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // File Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildFileCard(
                  context: context,
                  title: 'IA1 - Arrays.pdf',
                  size: '2.4 MB',
                  date: 'Modified 2d ago',
                  icon: Icons.picture_as_pdf,
                  iconColor: colorScheme.error,
                  iconBgColor: colorScheme.errorContainer.withOpacity(0.3),
                  statusIcon: Icons.offline_pin,
                  statusText: 'Downloaded',
                ),
                _buildFileCard(
                  context: context,
                  title: 'Lecture 3 - Linked Lists.pptx',
                  size: '5.1 MB',
                  date: 'Modified 1w ago',
                  icon: Icons.slideshow,
                  iconColor: colorScheme.secondary,
                  iconBgColor: colorScheme.secondaryContainer.withOpacity(0.3),
                  statusIcon: Icons.cloud_download,
                  statusText: 'Available offline',
                ),
                _buildFileCard(
                  context: context,
                  title: 'Notes - Trees.txt',
                  size: '12 KB',
                  date: 'Modified Just now',
                  icon: Icons.description,
                  iconColor: colorScheme.primary,
                  iconBgColor: colorScheme.primaryContainer.withOpacity(0.2),
                  statusIcon: Icons.offline_pin,
                  statusText: 'Downloaded',
                ),
                // Add New File Placeholder
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add, color: colorScheme.outline, size: 24),
                          ),
                          const SizedBox(height: 12),
                          Text('Add new file', style: textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text('Upload or create document', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard({
    required BuildContext context,
    required String title,
    required String size,
    required String date,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required IconData statusIcon,
    required String statusText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: () {
        context.push('/viewer'); // Navigate to viewer placeholder
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
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: textTheme.labelLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(size, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(width: 4),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Expanded(child: Text(date, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(statusText, style: textTheme.labelSmall?.copyWith(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.open_in_new, size: 14, color: colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
