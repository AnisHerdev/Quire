import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Quire',
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
          const CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Placeholder avatar
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
                  'Your Semesters',
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

            // Folder Grid
            GridView.count(
              crossAxisCount: 2, // 2 columns for mobile
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildFolderCard(
                  context: context,
                  title: 'Semester 1',
                  itemCount: '12 items',
                  id: 'sem1',
                  colorTheme: colorScheme.primaryContainer,
                ),
                _buildFolderCard(
                  context: context,
                  title: 'Semester 2',
                  itemCount: '8 items',
                  id: 'sem2',
                  colorTheme: colorScheme.secondaryContainer,
                ),
                _buildFolderCard(
                  context: context,
                  title: 'Certificates',
                  itemCount: '3 items',
                  id: 'cert',
                  colorTheme: colorScheme.surfaceVariant, // Placeholder for tertiary
                ),
              ],
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

  Widget _buildFolderCard({
    required BuildContext context,
    required String title,
    required String itemCount,
    required String id,
    required Color colorTheme,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      onTap: () {
        context.push('/folder/$id');
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
                  child: Icon(Icons.folder, color: colorScheme.primaryContainer),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall, // closer to headline-md
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  itemCount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
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
