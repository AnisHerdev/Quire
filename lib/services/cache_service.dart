import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final cacheServiceProvider = Provider((ref) => CacheService());

class CacheService {
  Future<Directory> _getCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/pdf_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<String> getCacheSizeFormatted() async {
    final cacheDir = await _getCacheDir();
    int totalBytes = 0;
    
    try {
      final files = cacheDir.listSync();
      for (var file in files) {
        if (file is File) {
          totalBytes += await file.length();
        }
      }
      return _formatBytes(totalBytes);
    } catch (e) {
      return 'Unknown Size';
    }
  }

  Future<void> clearCacheExceptRecent(int keepCount) async {
    final cacheDir = await _getCacheDir();
    try {
      final files = cacheDir.listSync().whereType<File>().toList();
      
      // Sort by last accessed time descending (newest first)
      files.sort((a, b) {
        final aTime = a.lastAccessedSync();
        final bTime = b.lastAccessedSync();
        return bTime.compareTo(aTime);
      });
      
      // Keep the first N files, delete the rest
      for (int i = keepCount; i < files.length; i++) {
        await files[i].delete();
      }
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }
}
