import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav_bar.dart';

class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

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
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Binary trees',
                      prefixIcon: Icon(Icons.search, color: colorScheme.outlineVariant),
                      suffixIcon: Icon(Icons.close, color: colorScheme.outline),
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
                  const SizedBox(height: 24),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Chip(
                          label: Text('All', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSecondary)),
                          backgroundColor: colorScheme.secondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        const SizedBox(width: 12),
                        _buildFilterChip(context, 'PDF', colorScheme.error),
                        const SizedBox(width: 12),
                        _buildFilterChip(context, 'PPT', colorScheme.secondaryContainer),
                        const SizedBox(width: 12),
                        _buildFilterChip(context, 'DOCX', colorScheme.primaryContainer),
                        const SizedBox(width: 12),
                        _buildFilterChip(context, 'TXT', colorScheme.outline),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Results List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  Text('3 RESULTS FOUND', style: textTheme.labelLarge?.copyWith(color: colorScheme.outline)),
                  const SizedBox(height: 16),
                  _buildResultCard(
                    context: context,
                    title: 'IA1 - Binary Trees.pdf',
                    icon: Icons.picture_as_pdf,
                    iconColor: colorScheme.error,
                    iconBgColor: colorScheme.errorContainer.withOpacity(0.3),
                    matchType: 'High Match',
                    matchColor: colorScheme.secondaryContainer,
                    folder: 'Semester 1',
                    date: 'Updated 2 days ago',
                    snippet: '...understanding data structures is crucial. When analyzing the computational complexity, traversing a binary tree involves visiting each node exactly once...',
                  ),
                  const SizedBox(height: 16),
                  _buildResultCard(
                    context: context,
                    title: 'Lecture 4 Notes: Trees & Graphs',
                    icon: Icons.description,
                    iconColor: colorScheme.outline,
                    iconBgColor: colorScheme.surfaceContainer,
                    matchType: 'Partial',
                    matchColor: colorScheme.surfaceContainerHigh,
                    folder: 'Data Structures 101',
                    date: 'Updated last week',
                    snippet: '...unlike arrays, binary trees provide a hierarchical structure. A balanced binary tree ensures that the depth is kept to a minimum...',
                  ),
                  const SizedBox(height: 16),
                  _buildResultCard(
                    context: context,
                    title: 'Concept: AVL Trees',
                    icon: Icons.format_quote,
                    iconColor: colorScheme.primary,
                    iconBgColor: colorScheme.primaryContainer.withOpacity(0.2),
                    matchType: 'Mention',
                    matchColor: colorScheme.surfaceContainerHigh,
                    folder: 'Study Guides',
                    date: 'Updated 1 month ago',
                    snippet: '...An AVL tree is a self-balancing binary search tree. It was the first such data structure to be invented...',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, Color dotColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
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
    required String folder,
    required String date,
    required String snippet,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      onTap: () {},
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
                      Expanded(child: Text(title, style: theme.textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: matchColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: matchColor.withOpacity(0.3)),
                        ),
                        child: Text(matchType, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.folder, size: 14, color: colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(folder, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                      const SizedBox(width: 8),
                      Text('•', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                      const SizedBox(width: 8),
                      Text(date, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(snippet, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
