import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLowest.withOpacity(0.8),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text('IA1 - Binary Trees.pdf', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface)),
            Text('Page 1 of 12', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.ios_share, color: colorScheme.onSurfaceVariant), onPressed: () {}),
          IconButton(icon: Icon(Icons.bookmark, color: colorScheme.onSurfaceVariant), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: colorScheme.primaryContainer.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Structural Overview of Binary Search Trees', style: textTheme.headlineLarge?.copyWith(color: colorScheme.onSurface)),
                    const SizedBox(height: 24),
                    Container(width: 64, height: 4, color: colorScheme.primary.withOpacity(0.2)),
                    const SizedBox(height: 24),
                    Text(
                      "In computer science, a binary search tree (BST), also called an ordered or sorted binary tree, is a rooted binary tree data structure with the key of each internal node being greater than all the keys in the respective node's left subtree and less than the ones in its right subtree.",
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "The time complexity of operations on the binary search tree is directly proportional to the height of the tree. BSTs allow binary search for fast lookup, addition, and removal of data items.",
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    // Placeholder for diagram
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
                      ),
                      child: Center(child: Icon(Icons.image, size: 48, color: colorScheme.outline)),
                    ),
                    const SizedBox(height: 16),
                    Center(child: Text('Figure 1.1: A standard unbalanced binary search tree representation.', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline))),
                    const SizedBox(height: 48),
                    Divider(color: colorScheme.outlineVariant.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CS-301 Data Structures', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                        Text('1', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Floating toolbar
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: colorScheme.primaryContainer.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 8)),
                  ],
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.remove, size: 20), onPressed: () {}, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text('100%', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () {}, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 24, color: colorScheme.outlineVariant.withOpacity(0.5)),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.search, size: 22), onPressed: () {}, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 24, color: colorScheme.outlineVariant.withOpacity(0.5)),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.dark_mode, size: 22), onPressed: () {}, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
