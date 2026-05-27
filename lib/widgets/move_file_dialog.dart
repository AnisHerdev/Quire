import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../models/database_model.dart';

class MoveFileDialog extends ConsumerStatefulWidget {
  final List<String> fileIds;
  
  const MoveFileDialog({super.key, required this.fileIds});

  @override
  ConsumerState<MoveFileDialog> createState() => _MoveFileDialogState();
}

class _MoveFileDialogState extends ConsumerState<MoveFileDialog> {
  List<Widget> _buildFolderTiles(
    BuildContext context, 
    Map<String, FolderModel> folders, 
    String? parentId, 
    int depth,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final childFolders = folders.entries
        .where((e) => e.value.parentId == parentId)
        .toList()
      ..sort((a, b) => a.value.order.compareTo(b.value.order));

    List<Widget> tiles = [];
    for (final child in childFolders) {
      tiles.add(
        ListTile(
          contentPadding: EdgeInsets.only(left: 24.0 + (depth * 24.0), right: 24),
          leading: Icon(Icons.folder, color: colorScheme.primary),
          title: Text(child.value.name, style: textTheme.bodyMedium),
          onTap: () {
            final undoFunc = ref.read(databaseProvider.notifier).moveFiles(
              widget.fileIds,
              child.key,
            );
            Navigator.pop(context, undoFunc);
          },
        ),
      );
      tiles.addAll(_buildFolderTiles(context, folders, child.key, depth + 1, colorScheme, textTheme));
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final database = ref.watch(databaseProvider);
    
    final folderWidgets = _buildFolderTiles(context, database.folders, null, 0, colorScheme, textTheme);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Move to...',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.inbox, color: colorScheme.secondary),
            title: Text('Inbox (Uncategorized)', style: textTheme.bodyMedium),
            onTap: () {
              final undoFunc = ref.read(databaseProvider.notifier).moveFiles(
                widget.fileIds,
                null,
              );
              Navigator.pop(context, undoFunc);
            },
          ),
          const Divider(),
          if (folderWidgets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No folders created yet. Go to Home to create one.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: folderWidgets,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
