import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/database_model.dart';
import '../providers/drive_provider.dart';
import 'drive_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.read(driveServiceProvider));
});

class SyncService {
  final DriveService _driveService;
  static const String _localDbFileName = 'quire_database_cache.json';

  SyncService(this._driveService);

  Future<File> _getLocalDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_localDbFileName');
  }

  /// Loads the database instantly from local device storage for UI rendering.
  Future<QuireDatabase> loadLocalDatabase() async {
    try {
      final file = await _getLocalDbFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        return QuireDatabase.fromJson(jsonMap);
      }
    } catch (e) {
      print('Error loading local db: $e');
    }
    return QuireDatabase.empty();
  }

  /// Saves the database to local storage and asynchronously pushes to Drive.
  Future<void> saveAndSync(QuireDatabase db) async {
    try {
      // 1. Update the sync timestamp
      final updatedDb = db.copyWith(
        syncMetadata: db.syncMetadata.copyWith(
          lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // 2. Save locally for instant access next time
      final file = await _getLocalDbFile();
      final jsonString = jsonEncode(updatedDb.toJson());
      await file.writeAsString(jsonString);

      // 3. Sync to Google Drive's hidden appDataFolder (Background)
      await syncWithCloud(updatedDb);
    } catch (e) {
      print('Failed to save and sync: $e');
    }
  }

  Future<QuireDatabase> syncWithCloud(QuireDatabase localDb) async {
    try {
      final cloudJsonString = await _driveService.downloadDatabase();
      
      if (cloudJsonString == null) {
        await _driveService.uploadDatabase(jsonEncode(localDb.toJson()));
        return localDb;
      }

      final cloudDb = QuireDatabase.fromJson(jsonDecode(cloudJsonString));
      
      // Compare timestamps to determine the winner
      if (localDb.syncMetadata.lastSyncedAt >= cloudDb.syncMetadata.lastSyncedAt) {
        // Local is newer or equal, overwrite cloud
        await _driveService.uploadDatabase(jsonEncode(localDb.toJson()));
        return localDb;
      } else {
        // Cloud is newer, overwrite local cache
        final file = await _getLocalDbFile();
        await file.writeAsString(jsonEncode(cloudDb.toJson()));
        return cloudDb;
      }
    } catch (e) {
      print('Cloud sync failed, data is safe locally: $e');
      return localDb;
    }
  }
}
