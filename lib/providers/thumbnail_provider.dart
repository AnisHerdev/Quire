import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'drive_provider.dart';

final thumbnailProvider = FutureProvider.family<Uint8List?, String>((ref, driveId) async {
  if (driveId.isEmpty) return null;

  try {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/pdf_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final thumbFile = File('${cacheDir.path}/${driveId}_thumb.jpg');
    if (await thumbFile.exists()) {
      return await thumbFile.readAsBytes();
    }

    final driveService = ref.read(driveServiceProvider);
    if (!driveService.isReady) return null;

    final bytes = await driveService.getThumbnail(driveId);
    
    if (bytes != null) {
      await thumbFile.writeAsBytes(bytes);
    }
    
    return bytes;
  } catch (e) {
    print('Error in thumbnail provider: $e');
    return null;
  }
});
