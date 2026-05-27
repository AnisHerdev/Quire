import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/bottom_nav_bar.dart';
import '../providers/search_provider.dart';
import '../providers/database_provider.dart';
import '../models/database_model.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate if query exists from another screen
    _controller.text = ref.read(searchProvider).query;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final searchState = ref.watch(searchProvider);
    final database = ref.watch(databaseProvider);

    // Filter logic
    final query = searchState.query.toLowerCase();
    final List<MapEntry<String, QuireFileModel>> results = [];
    
    if (query.isNotEmpty) {
      for (final entry in database.files.entries) {
        final file = entry.value;
        final matchesTitle = file.name.toLowerCase().contains(query);
        final matchesCloud = file.driveId != null && searchState.cloudMatchDriveIds.contains(file.driveId);
        
        if (matchesTitle || matchesCloud) {
          results.add(entry);
        }
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explore Sanctuary', style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text('Deep search across your notes, documents, and concepts.', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  // Search Bar
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (val) {
                      ref.read(searchProvider.notifier).setQuery(val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Binary trees, Physics...',
                      prefixIcon: Icon(Icons.search, color: colorScheme.outlineVariant),
                      suffixIcon: query.isNotEmpty 
                          ? IconButton(
                              icon: Icon(Icons.close, color: colorScheme.outline),
                              onPressed: () {
                                _controller.clear();
                                ref.read(searchProvider.notifier).clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.secondary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Loading Indicator for Cloud Search
            if (searchState.isSearchingCloud)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.secondary)),
                    const SizedBox(width: 12),
                    Text('Deep searching contents...', style: textTheme.bodySmall?.copyWith(color: colorScheme.secondary)),
                  ],
                ),
              ),

            // Search Results List
            Expanded(
              child: query.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.manage_search, size: 64, color: colorScheme.surfaceVariant),
                          const SizedBox(height: 16),
                          Text('Type to search titles and contents', style: textTheme.titleMedium?.copyWith(color: colorScheme.outline)),
                        ],
                      ),
                    )
                  : results.isEmpty && !searchState.isSearchingCloud
                      ? Center(
                          child: Text('No matches found for "$query"', style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: results.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final entry = results[index];
                            final localId = entry.key;
                            final file = entry.value;

                            final isCloudMatch = file.driveId != null && searchState.cloudMatchDriveIds.contains(file.driveId);
                            final matchesTitle = file.name.toLowerCase().contains(query);

                            // Determine Match Type
                            String matchType = 'Title Match';
                            Color matchColor = colorScheme.primaryContainer;
                            if (isCloudMatch && !matchesTitle) {
                              matchType = 'Content Deep Match';
                              matchColor = colorScheme.secondaryContainer;
                            } else if (isCloudMatch && matchesTitle) {
                              matchType = 'Title & Content';
                              matchColor = colorScheme.tertiaryContainer;
                            }

                            // Determine Icon
                            IconData iconData = Icons.insert_drive_file;
                            Color iconColor = colorScheme.outline;
                            if (file.mimeType.contains('pdf')) {
                              iconData = Icons.picture_as_pdf;
                              iconColor = colorScheme.error;
                            } else if (file.mimeType.contains('presentation') || file.name.endsWith('.ppt') || file.name.endsWith('.pptx')) {
                              iconData = Icons.slideshow;
                              iconColor = Colors.orange;
                            } else if (file.name.endsWith('.docx') || file.name.endsWith('.doc')) {
                              iconData = Icons.description;
                              iconColor = Colors.blue;
                            }

                            final dateStr = 'Added ${timeago.format(DateTime.fromMillisecondsSinceEpoch(file.addedAt))}';

                            return _buildResultCard(
                              context: context,
                              title: file.name,
                              icon: iconData,
                              iconColor: iconColor,
                              iconBgColor: iconColor.withOpacity(0.1),
                              matchType: matchType,
                              matchColor: matchColor,
                              date: dateStr,
                              onTap: () {
                                // Navigate to PDF viewer
                                context.push('/pdf-viewer/$localId');
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildResultCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String matchType,
    required Color matchColor,
    required String date,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      onTap: onTap,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title, 
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: matchColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: matchColor),
                        ),
                        child: Text(matchType, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(date, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
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
}
