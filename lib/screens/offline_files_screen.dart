import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/database_provider.dart';
import '../providers/thumbnail_provider.dart';
import '../providers/view_mode_provider.dart';
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

  @override
  void initState() {
    super.initState();
    ref.read(fileViewModeProvider.notifier).init();
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
        if (entity is File && !entity.path.endsWith('_thumb.jpg')) {
          final fileName = entity.uri.pathSegments.last;
          final fileId = fileName.split('.').first;
          final dbFile = db.files[fileId];
          final stat = await entity.stat();
          files.add(_CachedFileInfo(
            fileId: fileId,
            name: dbFile?.name ?? fileId,
            mimeType: dbFile?.mimeType ?? '',
            driveId: dbFile?.driveId,
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

  Future<void> _showCacheCleanupDialog() async {
    final theme = Theme.of(context);
    int keepCount = 10;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text('Free Up Space', style: theme.textTheme.headlineSmall),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How many of your most recently opened files should stay downloaded for offline access?',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'The rest will be removed from this device only. Your files will stay safe on Google Drive and will re-download when you open them.',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Keep last:', style: theme.textTheme.labelLarge),
                    Text('$keepCount files', style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    )),
                  ],
                ),
                Slider(
                  value: keepCount.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 10,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    setDialogState(() => keepCount = val.toInt());
                  },
                ),
                if (keepCount == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'This will remove all offline files from your device.',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text('Clear'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      await ref.read(cacheServiceProvider).clearCacheExceptRecent(keepCount);
      _refreshData();
    }
  }

  Future<void> _deleteFile(String fileId, String fileName) async {
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$fileName"?'),
        content: const Text('How would you like to remove this file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'device'),
            child: Text(
              'Remove from device only',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.pop(ctx, 'permanent'),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (action == 'device') {
      await ref.read(databaseProvider.notifier).removeFromCache(fileId);
      if (mounted) _refreshData();
    } else if (action == 'permanent') {
      try {
        await ref.read(databaseProvider.notifier).deleteFiles([fileId]);
        if (mounted) _refreshData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete from cloud: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
            icon: Icon(
              ref.watch(fileViewModeProvider) ? Icons.list : Icons.grid_view,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => ref.read(fileViewModeProvider.notifier).toggle(),
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
                    else if (ref.watch(fileViewModeProvider))
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
                onPressed: _cachedFiles.isEmpty ? null : _showCacheCleanupDialog,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  textStyle: textTheme.labelSmall,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Free Up Space'),
                    SizedBox(width: 4),
                    Icon(Icons.cleaning_services, size: 16),
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

    return InkWell(
      onTap: () {
        if (file.mimeType == 'application/pdf') {
          context.push('/pdf-viewer/${file.fileId}');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.surfaceContainerHighest),
        ),
        child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: file.driveId != null
                  ? Consumer(
                      builder: (context, ref, _) {
                        final thumbAsync = ref.watch(thumbnailProvider(file.driveId!));
                        return thumbAsync.when(
                          data: (bytes) {
                            if (bytes != null) {
                              return Image.memory(bytes, fit: BoxFit.cover);
                            }
                            return _buildIconThumb(iconColor, file);
                          },
                          loading: () => _buildIconThumb(iconColor, file),
                          error: (_, __) => _buildIconThumb(iconColor, file),
                        );
                      },
                    )
                  : _buildIconThumb(iconColor, file),
            ),
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
          IconButton(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            onPressed: () => _deleteFile(file.fileId, file.name),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildGridFileCard(_CachedFileInfo file, ColorScheme colorScheme, TextTheme textTheme) {
    final iconColor = _colorForMime(file.mimeType, colorScheme);

    return InkWell(
      onTap: () {
        if (file.mimeType == 'application/pdf') {
          context.push('/pdf-viewer/${file.fileId}');
        }
      },
      onLongPress: () => _deleteFile(file.fileId, file.name),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.surfaceContainerHighest),
          boxShadow: [
            BoxShadow(color: colorScheme.primary.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: file.driveId != null
                    ? Consumer(
                        builder: (context, ref, _) {
                          final thumbAsync = ref.watch(thumbnailProvider(file.driveId!));
                          return thumbAsync.when(
                            data: (bytes) {
                              if (bytes != null) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(bytes, fit: BoxFit.cover),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => _deleteFile(file.fileId, file.name),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: colorScheme.error.withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(Icons.delete_outline, color: colorScheme.onError, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return _buildFallbackThumb(iconColor, file, colorScheme);
                            },
                            loading: () => _buildFallbackThumb(iconColor, file, colorScheme),
                            error: (_, __) => _buildFallbackThumb(iconColor, file, colorScheme),
                          );
                        },
                      )
                    : _buildFallbackThumb(iconColor, file, colorScheme),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name, style: textTheme.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(_formatSize(file.sizeBytes), style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackThumb(Color iconColor, _CachedFileInfo file, ColorScheme colorScheme) {
    return Container(
      color: iconColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(_iconForMime(file.mimeType), color: iconColor, size: 48),
      ),
    );
  }

  Widget _buildIconThumb(Color iconColor, _CachedFileInfo file) {
    return Container(
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_iconForMime(file.mimeType), color: iconColor, size: 24),
    );
  }
}

class _CachedFileInfo {
  final String fileId;
  final String name;
  final String mimeType;
  final String? driveId;
  final int sizeBytes;
  final int addedAt;
  final String addedAtReadable;

  const _CachedFileInfo({
    required this.fileId,
    required this.name,
    required this.mimeType,
    this.driveId,
    required this.sizeBytes,
    required this.addedAt,
    required this.addedAtReadable,
  });
}
