import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/database_provider.dart';
import '../services/cache_service.dart';

class OfflineFilesScreen extends ConsumerStatefulWidget {
  const OfflineFilesScreen({super.key});

  @override
  ConsumerState<OfflineFilesScreen> createState() => _OfflineFilesScreenState();
}

class _OfflineFilesScreenState extends ConsumerState<OfflineFilesScreen> {
  List<_CachedFileInfo> _cachedFiles = [];
  String _cacheSize = 'Calculating...';
  bool _loading = true;
  bool _useGridView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    setState(() => _loading = true);
    await _loadCachedFiles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCachedFiles() async {
    final cacheService = ref.read(cacheServiceProvider);
    final db = ref.read(databaseProvider);
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/pdf_cache');

    final size = await cacheService.getCacheSizeFormatted();
    final files = <_CachedFileInfo>[];

    if (await cacheDir.exists()) {
      for (final entity in cacheDir.listSync()) {
        if (entity is File && entity.path.endsWith('.pdf')) {
          final fileId = entity.uri.pathSegments.last.replaceAll('.pdf', '');
          final dbFile = db.files[fileId];
          final stat = await entity.stat();
          files.add(_CachedFileInfo(
            fileId: fileId,
            name: dbFile?.name ?? fileId,
            mimeType: dbFile?.mimeType ?? '',
            sizeBytes: stat.size,
            addedAt: stat.modified.millisecondsSinceEpoch,
            addedAtReadable: _formatDate(stat.modified),
          ));
        }
      }
    }

    files.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    if (mounted) {
      setState(() {
        _cacheSize = size;
        _cachedFiles = files;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Cache?'),
        content: const Text('This will remove all locally cached files. They will still be available online.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider.notifier).clearAllCache();
      _refreshData();
    }
  }

  Future<void> _deleteFile(String fileId, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Remove "$fileName" from Quire completely?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider.notifier).deleteFiles([fileId], forceLocalDelete: true);
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Offline Files', style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary)),
        actions: [
          IconButton(
            icon: Icon(_useGridView ? Icons.list : Icons.grid_view, color: colorScheme.onSurfaceVariant),
            onPressed: () => setState(() => _useGridView = !_useGridView),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurfaceVariant),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cachedFiles.isEmpty
                          ? 'No files cached for offline reading.'
                          : 'Access your downloaded notes without an internet connection.',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),

                    // Storage Indicator Card
                    _buildStorageCard(colorScheme, textTheme),
                    const SizedBox(height: 32),

                    // Downloaded Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Downloaded Items', style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600, color: colorScheme.onSurface,
                        )),
                        Text('${_cachedFiles.length} files', style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_cachedFiles.isEmpty)
                      _buildEmptyState(colorScheme, textTheme)
                    else if (_useGridView)
                      _buildGridView(colorScheme, textTheme)
                    else
                      _buildListView(colorScheme, textTheme),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildStorageCard(ColorScheme colorScheme, TextTheme textTheme) {
    final totalBytes = _cachedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    // Use a generous assumed quota since we can't query device storage easily
    final assumedQuota = _cachedFiles.isEmpty ? 1.0 : totalBytes / (5 * 1024 * 1024 * 1024);
    final progress = assumedQuota.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.surfaceContainerHighest),
        boxShadow: [
          BoxShadow(color: colorScheme.primary.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4)),
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
                      Icon(Icons.storage, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('LOCAL CACHE', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _cacheSize,
                    style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
                  ),
                ],
              ),
              TextButton(
                onPressed: _cachedFiles.isEmpty ? null : _clearAllCache,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  textStyle: textTheme.labelSmall,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Clear Cache'),
                    SizedBox(width: 4),
                    Icon(Icons.delete_outline, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_cachedFiles.length} file(s) cached',
            style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.cloud_off, size: 64, color: colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No offline files', style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline)),
            const SizedBox(height: 8),
            Text('Open a PDF to cache it for offline reading.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: _cachedFiles.map((file) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildFileListItem(file, colorScheme, textTheme),
      )).toList(),
    );
  }

  Widget _buildGridView(ColorScheme colorScheme, TextTheme textTheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _cachedFiles.length,
      itemBuilder: (context, index) => _buildGridFileCard(_cachedFiles[index], colorScheme, textTheme),
    );
  }

  IconData _iconForMime(String mimeType) {
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow;
    if (mimeType.contains('document') || mimeType.contains('wordprocessingml')) return Icons.description;
    if (mimeType.contains('text')) return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  Color _colorForMime(String mimeType, ColorScheme colorScheme) {
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Colors.orange;
    if (mimeType.contains('document') || mimeType.contains('wordprocessingml')) return Colors.blue;
    if (mimeType.contains('text')) return Colors.green;
    return colorScheme.onSurfaceVariant;
  }

  Widget _buildFileListItem(_CachedFileInfo file, ColorScheme colorScheme, TextTheme textTheme) {
    final iconColor = _colorForMime(file.mimeType, colorScheme);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconForMime(file.mimeType), color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500, color: colorScheme.onSurface,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_formatSize(file.sizeBytes), style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: BoxDecoration(
                      color: colorScheme.outlineVariant, shape: BoxShape.circle,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Cached ${file.addedAtReadable}',
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            onSelected: (value) {
              if (value == 'delete') {
                _deleteFile(file.fileId, file.name);
              } else if (value == 'remove_cache') {
                ref.read(databaseProvider.notifier).removeFromCache(file.fileId);
                _refreshData();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'delete', child: Row(
                children: [
                  Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Text('Delete from Quire', style: TextStyle(color: colorScheme.error)),
                ],
              )),
              PopupMenuItem(value: 'remove_cache', child: Row(
                children: [
                  Icon(Icons.cloud_off, color: colorScheme.onSurfaceVariant, size: 20),
                  const SizedBox(width: 8),
                  const Text('Remove from cache'),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridFileCard(_CachedFileInfo file, ColorScheme colorScheme, TextTheme textTheme) {
    final iconColor = _colorForMime(file.mimeType, colorScheme);

    return InkWell(
      onLongPress: () => _deleteFile(file.fileId, file.name),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.surfaceContainerHighest),
          boxShadow: [
            BoxShadow(color: colorScheme.primary.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
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
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconForMime(file.mimeType), color: iconColor, size: 20),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _deleteFile(file.fileId, file.name),
                ),
              ],
            ),
            const Spacer(),
            Text(file.name, style: textTheme.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(_formatSize(file.sizeBytes), style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}

class _CachedFileInfo {
  final String fileId;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final int addedAt;
  final String addedAtReadable;

  const _CachedFileInfo({
    required this.fileId,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.addedAt,
    required this.addedAtReadable,
  });
}
