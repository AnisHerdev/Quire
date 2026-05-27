import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class OfflineFilesScreen extends StatefulWidget {
  const OfflineFilesScreen({super.key});

  @override
  State<OfflineFilesScreen> createState() => _OfflineFilesScreenState();
}

class _OfflineFilesScreenState extends State<OfflineFilesScreen> {
  bool _file1Offline = true;
  bool _file2Offline = false;
  bool _file3Offline = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text('Offline Files', style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary)),
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
            Text('Access your downloaded notes and reading materials without an internet connection.', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            
            // Storage Indicator Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.surfaceVariant),
                boxShadow: [
                  BoxShadow(color: colorScheme.primaryContainer.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cloud_done, color: colorScheme.primaryContainer, size: 20),
                              const SizedBox(width: 8),
                              Text('LOCAL STORAGE', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
                              children: [
                                const TextSpan(text: '2.1 GB '),
                                TextSpan(text: 'of 5 GB used', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.primaryContainer,
                          textStyle: textTheme.labelSmall,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('Manage Storage'),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.42,
                      backgroundColor: colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primaryContainer),
                      minHeight: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Documents (1.5 GB)', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      Text('Media (0.6 GB)', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Downloaded Items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Downloaded Items', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.sort), onPressed: () {}, color: colorScheme.onSurfaceVariant),
                    IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // List Items
            _buildFileListItem(
              context: context,
              title: 'Quantum Mechanics - Chapter 4',
              type: 'PDF',
              size: '12.4 MB',
              status: 'Downloaded 2h ago',
              icon: Icons.picture_as_pdf,
              iconColor: colorScheme.error,
              iconBgColor: colorScheme.errorContainer.withOpacity(0.3),
              isOffline: _file1Offline,
              onToggle: (val) => setState(() => _file1Offline = val),
            ),
            const SizedBox(height: 12),
            _buildFileListItem(
              context: context,
              title: 'Thesis Draft v3.docx',
              type: 'DOCX',
              size: '4.2 MB',
              status: 'Downloaded Yesterday',
              icon: Icons.description,
              iconColor: colorScheme.secondary,
              iconBgColor: colorScheme.secondaryContainer.withOpacity(0.3),
              isOffline: _file2Offline,
              onToggle: (val) => setState(() => _file2Offline = val),
            ),
            const SizedBox(height: 12),
            _buildFileListItem(
              context: context,
              title: 'Research_Dataset_2023.zip',
              type: 'ZIP',
              size: '850 MB',
              status: 'Not available offline',
              icon: Icons.folder_zip,
              iconColor: colorScheme.onSurfaceVariant,
              iconBgColor: colorScheme.surfaceContainerHigh,
              isOffline: _file3Offline,
              onToggle: (val) => setState(() => _file3Offline = val),
              isFaded: true,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildFileListItem({
    required BuildContext context,
    required String title,
    required String type,
    required String size,
    required String status,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required bool isOffline,
    required ValueChanged<bool> onToggle,
    bool isFaded = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Opacity(
      opacity: isFaded ? 0.7 : 1.0,
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
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(type, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(size, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(status, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: isOffline,
              onChanged: onToggle,
              activeColor: colorScheme.onPrimaryContainer,
              activeTrackColor: colorScheme.primaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}
