import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/database_model.dart';
import '../services/sync_service.dart';
import '../utils/duplicate_filename.dart';
import 'auth_provider.dart';
import 'drive_provider.dart';

class _SyncInProgress extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;
  void stop() => state = false;
}

final syncInProgressProvider = NotifierProvider<_SyncInProgress, bool>(_SyncInProgress.new);

final databaseProvider = NotifierProvider<DatabaseNotifier, QuireDatabase>(
  DatabaseNotifier.new,
);

class _ShareRequest {
  final List<SharedMediaFile> files;
  final List<String>? customNames;
  final List<String>? tags;
  final String? folderName;
  final bool replaceDuplicate;

  const _ShareRequest(
    this.files, {
    this.customNames,
    this.tags,
    this.folderName,
    this.replaceDuplicate = false,
  });
}

class DatabaseNotifier extends Notifier<QuireDatabase> {
  bool _isProcessingSharedFiles = false;
  final List<_ShareRequest> _pendingShareQueue = [];

  @override
  QuireDatabase build() {
    return QuireDatabase.empty();
  }

  Future<void> init() async {
    final syncService = ref.read(syncServiceProvider);

    // 1. Instantly load local DB for fast UI
    state = await syncService.loadLocalDatabase();

    // 2. Trigger background cloud sync if logged in
    final authService = ref.read(authServiceProvider);
    var googleAccount = authService.currentGoogleAccount;
    if (googleAccount == null) {
      googleAccount = await authService.signInSilently();
    }

    if (googleAccount != null) {
      ref.read(driveServiceProvider).setAccount(googleAccount);
      await _performBackgroundSync();
    }
  }

  Future<void> _performBackgroundSync() async {
    ref.read(syncInProgressProvider.notifier).start();
    try {
      final syncService = ref.read(syncServiceProvider);
      final before = state;
      final result = await syncService.syncWithCloud(before);

      // If state was modified during the network call (e.g., share callback
      // added files), the in-memory state is newer — don't overwrite it.
      // The concurrent modification's saveAndSync already pushed to cloud.
      if (state.syncMetadata.lastSyncedAt <= before.syncMetadata.lastSyncedAt) {
        state = result;
      }
    } finally {
      ref.read(syncInProgressProvider.notifier).stop();
    }
  }


  Future<void> addFolder(
    String name,
    String? parentId, {
    List<String>? associatedTags,
  }) async {
    const uuid = Uuid();
    final id = 'folder_${uuid.v4()}';

    // Count how many items currently share the same parentId to set order
    final order =
        state.folders.values.where((f) => f.parentId == parentId).length + 1;

    final newFolder = FolderModel(
      id: id,
      name: name,
      parentId: parentId,
      order: order,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
      associatedTags: associatedTags ?? [],
    );

    final updatedFolders = Map<String, FolderModel>.from(state.folders)
      ..[id] = newFolder;
    state = state.copyWith(folders: updatedFolders);

    await ref.read(syncServiceProvider).saveAndSync(state);
  }

  Future<void> reorderFolders(List<String> folderIds) async {
    final updatedFolders = Map<String, FolderModel>.from(state.folders);
    for (int i = 0; i < folderIds.length; i++) {
      final id = folderIds[i];
      if (updatedFolders.containsKey(id)) {
        updatedFolders[id] = updatedFolders[id]!.copyWith(order: i);
      }
    }
    state = state.copyWith(folders: updatedFolders);
    await ref.read(syncServiceProvider).saveAndSync(state);
  }

  Future<void> deleteFolder(String folderId, {bool keepFiles = false}) async {
    // 1. Find all child folders recursively
    final foldersToDelete = <String>{folderId};
    bool added;
    do {
      added = false;
      for (final f in state.folders.values) {
        if (f.parentId != null &&
            foldersToDelete.contains(f.parentId) &&
            !foldersToDelete.contains(f.id)) {
          foldersToDelete.add(f.id);
          added = true;
        }
      }
    } while (added);

    // 2. Find all files in these folders
    final fileEntries = state.files.entries
        .where(
          (e) =>
              e.value.folderId != null &&
              foldersToDelete.contains(e.value.folderId),
        )
        .toList();

    // 3. Delete files or move to Inbox
    if (keepFiles) {
      final updatedFiles = Map<String, QuireFileModel>.from(state.files);
      for (final entry in fileEntries) {
        updatedFiles[entry.key] = entry.value.copyWith(
          folderId: null,
          clearFolderId: true,
        );
      }
      state = state.copyWith(files: updatedFiles);
    } else {
      final filesToDelete = fileEntries.map((e) => e.key).toList();
      if (filesToDelete.isNotEmpty) {
        await deleteFiles(filesToDelete);
      }
    }

    // 4. Delete the folders from state and Google Drive
    final updatedFolders = Map<String, FolderModel>.from(state.folders);
    final driveService = ref.read(driveServiceProvider);

    for (final id in foldersToDelete) {
      final f = updatedFolders[id];
      if (f != null && f.driveId != null && driveService.isReady) {
        try {
          await driveService.deleteVisibleFile(f.driveId!);
        } catch (e) {}
      }
      updatedFolders.remove(id);
    }

    state = state.copyWith(folders: updatedFolders);
    await ref.read(syncServiceProvider).saveAndSync(state);
  }

  Future<bool> _ensureDriveAuthenticated() async {
    final driveService = ref.read(driveServiceProvider);
    if (driveService.isReady) return true;

    final authService = ref.read(authServiceProvider);
    var googleAccount = authService.currentGoogleAccount;
    if (googleAccount == null) {
      googleAccount = await authService.signInSilently();
    }

    if (googleAccount != null) {
      driveService.setAccount(googleAccount);
      return true;
    }

    return false;
  }

  Future<void> processSharedFiles(
    List<SharedMediaFile> files, {
    List<String>? customNames,
    List<String>? tags,
    String? folderName,
    bool replaceDuplicate = false,
  }) async {
    if (_isProcessingSharedFiles) {
      _pendingShareQueue.add(
        _ShareRequest(
          files,
          customNames: customNames,
          tags: tags,
          folderName: folderName,
          replaceDuplicate: replaceDuplicate,
        ),
      );
      return;
    }

    _isProcessingSharedFiles = true;
    try {
      await _processSharedFilesInternal(
        files,
        customNames: customNames,
        tags: tags,
        folderName: folderName,
        replaceDuplicate: replaceDuplicate,
      );
    } finally {
      _isProcessingSharedFiles = false;
      if (_pendingShareQueue.isNotEmpty) {
        final next = _pendingShareQueue.removeAt(0);
        processSharedFiles(
          next.files,
          customNames: next.customNames,
          tags: next.tags,
          folderName: next.folderName,
          replaceDuplicate: next.replaceDuplicate,
        );
      }
    }
  }

  Future<void> _processSharedFilesInternal(
    List<SharedMediaFile> files, {
    List<String>? customNames,
    List<String>? tags,
    String? folderName,
    bool replaceDuplicate = false,
  }) async {
    final isAuthenticated = await _ensureDriveAuthenticated();
    if (!isAuthenticated) {
      throw StateError('User is not authenticated with Google.');
    }

    final updatedFiles = Map<String, QuireFileModel>.from(state.files);
    final updatedAllTags = Set<String>.from(state.allTags);

    // Resolve folderId from folderName:
    //   ''    → explicit inbox, no folder
    //   other → use as folder name (existing or new)
    final effectiveFolderName = (folderName != null && folderName.isNotEmpty)
        ? folderName
        : null;
    String? resolvedFolderId;
    if (effectiveFolderName != null) {
      final existing = state.folders.values.where(
        (f) => f.name.toLowerCase() == effectiveFolderName.toLowerCase(),
      );
      if (existing.isNotEmpty) {
        resolvedFolderId = existing.first.id;
      } else {
        const uuid = Uuid();
        final newFolderId = 'folder_${uuid.v4()}';
        final newFolder = FolderModel(
          id: newFolderId,
          name: effectiveFolderName,
          order:
              state.folders.values.where((f) => f.parentId == null).length + 1,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          syncStatus: 'pending',
          associatedTags: tags ?? [],
        );
        final updatedFolders = Map<String, FolderModel>.from(state.folders)
          ..[newFolderId] = newFolder;
        state = state.copyWith(folders: updatedFolders);
        resolvedFolderId = newFolderId;
      }
    }

    int filesProcessed = 0;
    int filesSkipped = 0;
    String? lastError;
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/pdf_cache');

    for (var sharedFile in files) {
      try {
        final file = File(sharedFile.path);
        if (!await file.exists()) {
          filesSkipped++;
          continue;
        }

        final index = files.indexOf(sharedFile);
        var finalName =
            (customNames != null &&
                customNames.length > index &&
                customNames[index].isNotEmpty)
            ? customNames[index]
            : (sharedFile.path.split(Platform.pathSeparator).last);

        final mimeType = sharedFile.mimeType ?? _getMimeType(finalName);
        final fileSize = await file.length();

        String? duplicateId;
        String? sameNameId;
        for (final entry in updatedFiles.entries) {
          final existingFile = entry.value;
          if (existingFile.name.toLowerCase() == finalName.toLowerCase()) {
            final ext = extensionForMimeType(existingFile.mimeType);
            final cachedFile = File('${cacheDir.path}/${entry.key}$ext');
            final cachedFileExists = await cachedFile.exists();
            if (existingFile.driveId != null || cachedFileExists) {
              sameNameId ??= entry.key;
            }
            if (cachedFileExists) {
              final cachedSize = await cachedFile.length();
              if (cachedSize == fileSize) {
                duplicateId = entry.key;
                break;
              }
            }
          }
        }
        if (duplicateId != null) {
          if (replaceDuplicate) {
            final dupExt = extensionForMimeType(updatedFiles[duplicateId]!.mimeType);
            final cachedFile = File('${cacheDir.path}/$duplicateId$dupExt');
            if (await cachedFile.exists()) {
              await cachedFile.delete();
            }
            updatedFiles.remove(duplicateId);
          } else {
            finalName = uniqueDuplicateFilename(
              finalName,
              updatedFiles.values.map((file) => file.name),
            );
          }
        } else if (sameNameId != null && !replaceDuplicate) {
          finalName = uniqueDuplicateFilename(
            finalName,
            updatedFiles.values.map((file) => file.name),
          );
        } else if (sameNameId != null && replaceDuplicate) {
          final sameExt = extensionForMimeType(updatedFiles[sameNameId]!.mimeType);
          final cachedFile = File('${cacheDir.path}/$sameNameId$sameExt');
          if (await cachedFile.exists()) {
            await cachedFile.delete();
          }
          updatedFiles.remove(sameNameId);
        }

        const uuid = Uuid();
        final localId = 'local_${uuid.v4()}';

        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }

        final ext = extensionForMimeType(mimeType);
        final localFile = File('${cacheDir.path}/$localId$ext');
        await file.copy(localFile.path);

        if (tags != null) {
          updatedAllTags.addAll(tags);
        }

        final newFile = QuireFileModel(
          name: finalName,
          mimeType: mimeType,
          folderId: resolvedFolderId,
          addedAt: DateTime.now().millisecondsSinceEpoch,
          tags: tags ?? [],
          syncStatus: 'pending',
          driveId: null,
        );

        updatedFiles[localId] = newFile;
        filesProcessed++;
      } catch (e) {
        filesSkipped++;
        lastError = e.toString();
      }
    }

    if (filesProcessed > 0) {
      state = state.copyWith(
        files: updatedFiles,
        allTags: updatedAllTags,
        syncMetadata: state.syncMetadata.copyWith(
          lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await ref.read(syncServiceProvider).saveAndSync(state);
      _syncPendingFiles();
    }

    if (filesProcessed == 0 && filesSkipped > 0) {
      throw StateError(
        'No files could be saved. ${lastError ?? "Check if the files still exist."}',
      );
    }
  }

  Future<void> addPickedFiles(
    List<String> paths,
    List<String> names,
    String? folderId,
  ) async {
    final isAuthenticated = await _ensureDriveAuthenticated();
    if (!isAuthenticated) {
      throw StateError('User is not authenticated with Google.');
    }

    final updatedFiles = Map<String, QuireFileModel>.from(state.files);
    bool stateChanged = false;

    for (int i = 0; i < paths.length; i++) {
      try {
        final path = paths[i];
        final name = names[i];
        final file = File(path);
        if (!await file.exists()) continue;

        const uuid = Uuid();
        final localId = 'local_${uuid.v4()}';

        final dir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory('${dir.path}/pdf_cache');
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }

        final mimeType = _getMimeType(name);
        final ext = extensionForMimeType(mimeType);
        final localFile = File('${cacheDir.path}/$localId$ext');
        await file.copy(localFile.path);

        final newFile = QuireFileModel(
          name: name,
          mimeType: mimeType,
          folderId: folderId,
          addedAt: DateTime.now().millisecondsSinceEpoch,
          tags: [],
          syncStatus: 'pending',
          driveId: null,
        );

        updatedFiles[localId] = newFile;
        stateChanged = true;
      } catch (e) {
        print('Error processing picked file: $e');
      }
    }

    if (stateChanged) {
      state = state.copyWith(
        files: updatedFiles,
        syncMetadata: state.syncMetadata.copyWith(
          lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await ref.read(syncServiceProvider).saveAndSync(state);
      _syncPendingFiles();
    }
  }

  Future<void> _syncPendingFiles() async {
    final driveService = ref.read(driveServiceProvider);
    if (!driveService.isReady) return;

    try {
      final rootId = await driveService.getOrCreateQuireRootFolder();
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/pdf_cache');

      bool dbChanged = false;
      final updatedFolders = Map<String, FolderModel>.from(state.folders);
      final updatedFiles = Map<String, QuireFileModel>.from(state.files);

      // 1. Sync Folders
      final pendingFolders = state.folders.entries
          .where((e) => e.value.syncStatus == 'pending')
          .toList();
      for (var entry in pendingFolders) {
        final folderId = entry.key;
        final folderModel = entry.value;

        try {
          String parentDriveId = rootId;
          if (folderModel.parentId != null) {
            final parentFolder = updatedFolders[folderModel.parentId];
            if (parentFolder != null && parentFolder.driveId != null) {
              parentDriveId = parentFolder.driveId!;
            } else {
              continue; // Parent not synced yet, skip for now
            }
          }

          final driveId = await driveService.createVisibleFolder(
            folderModel.name,
            parentDriveId,
          );
          updatedFolders[folderId] = folderModel.copyWith(
            driveId: driveId,
            syncStatus: 'synced',
          );
          dbChanged = true;
        } catch (e) {
          print('Folder sync failed for $folderId: $e');
        }
      }

      // 2. Sync Files
      final pendingFiles = state.files.entries
          .where((e) => e.value.syncStatus == 'pending')
          .toList();
      for (var entry in pendingFiles) {
        final localId = entry.key;
        final fileModel = entry.value;

        final ext = extensionForMimeType(fileModel.mimeType);
        final localFile = File('${cacheDir.path}/$localId$ext');
        if (await localFile.exists()) {
          try {
            String parentDriveId = rootId;
            if (fileModel.folderId != null) {
              final folder = updatedFolders[fileModel.folderId];
              if (folder != null && folder.driveId != null) {
                parentDriveId = folder.driveId!;
              } else {
                continue; // Parent folder not synced yet
              }
            }

            final driveFile = await driveService.uploadVisibleFile(
              localFile,
              fileModel.mimeType,
              parentDriveId,
              customName: fileModel.name,
            );

            if (driveFile.id != null) {
              updatedFiles[localId] = fileModel.copyWith(
                driveId: driveFile.id,
                syncStatus: 'synced',
              );
              dbChanged = true;
            }
          } catch (e) {
            print('Background sync failed for $localId: $e');
          }
        }
      }

      if (dbChanged) {
        state = state.copyWith(folders: updatedFolders, files: updatedFiles);
        await ref.read(syncServiceProvider).saveAndSync(state);
      }
    } catch (e) {
      print('Failed to sync pending items: $e');
    }
  }

  Future<void> _moveFilesInDrive(
    Map<String, QuireFileModel> originalStates,
    String? newFolderId,
  ) async {
    final driveService = ref.read(driveServiceProvider);
    if (!driveService.isReady) return;

    try {
      final rootId = await driveService.getOrCreateQuireRootFolder();

      String newParentDriveId = rootId;
      if (newFolderId != null) {
        final folder = state.folders[newFolderId];
        if (folder != null && folder.driveId != null) {
          newParentDriveId = folder.driveId!;
        } else {
          return; // Wait for next sync loop
        }
      }

      for (var entry in originalStates.entries) {
        final file = state.files[entry.key];
        final originalFile = entry.value;
        if (file != null && file.driveId != null) {
          String oldParentDriveId = rootId;
          if (originalFile.folderId != null) {
            final oldFolder = state.folders[originalFile.folderId];
            if (oldFolder != null && oldFolder.driveId != null) {
              oldParentDriveId = oldFolder.driveId!;
            }
          }
          await driveService.moveVisibleItem(
            file.driveId!,
            oldParentDriveId,
            newParentDriveId,
          );
        }
      }
    } catch (e) {
      print('Drive move failed: $e');
    }
  }

  Future<void> Function() moveFiles(List<String> fileIds, String? newFolderId) {
    final originalStates = <String, QuireFileModel>{};
    final updatedFiles = Map<String, QuireFileModel>.from(state.files);

    for (final id in fileIds) {
      if (updatedFiles.containsKey(id)) {
        originalStates[id] = updatedFiles[id]!;
        updatedFiles[id] = updatedFiles[id]!.copyWith(
          folderId: newFolderId,
          clearFolderId: newFolderId == null,
        );
      }
    }

    state = state.copyWith(files: updatedFiles);
    ref.read(syncServiceProvider).saveAndSync(state);

    _moveFilesInDrive(originalStates, newFolderId);

    // Return an undo function
    return () async {
      final undoFiles = Map<String, QuireFileModel>.from(state.files);
      for (final id in originalStates.keys) {
        if (undoFiles.containsKey(id)) {
          undoFiles[id] = originalStates[id]!;
        }
      }
      state = state.copyWith(files: undoFiles);
      await ref.read(syncServiceProvider).saveAndSync(state);
    };
  }

  Future<void> renameFolder(String folderId, String newName) async {
    if (!state.folders.containsKey(folderId)) return;

    final updatedFolders = Map<String, FolderModel>.from(state.folders);
    final folder = updatedFolders[folderId]!;
    updatedFolders[folderId] = folder.copyWith(name: newName);

    state = state.copyWith(folders: updatedFolders);
    await ref.read(syncServiceProvider).saveAndSync(state);

    if (folder.driveId != null) {
      final driveService = ref.read(driveServiceProvider);
      if (driveService.isReady) {
        try {
          await driveService.renameVisibleItem(folder.driveId!, newName);
        } catch (e) {}
      }
    }
  }

  Future<void> updateFolderState(
    Map<String, FolderModel> updatedFolders,
  ) async {
    state = state.copyWith(folders: updatedFolders);
    await ref.read(syncServiceProvider).saveAndSync(state);
  }

  String _getMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> deleteFiles(
    List<String> fileIds, {
    bool forceLocalDelete = false,
  }) async {
    final driveService = ref.read(driveServiceProvider);

    bool requiresCloudDeletion = false;
    for (final id in fileIds) {
      final file = state.files[id];
      if (file != null && file.driveId != null) {
        requiresCloudDeletion = true;
        break;
      }
    }

    if (requiresCloudDeletion) {
      final isAuthenticated = await _ensureDriveAuthenticated();
      if (!isAuthenticated) {
        throw StateError(
          'You need an internet connection to delete files from Drive.',
        );
      }
    }

    final updatedFiles = Map<String, QuireFileModel>.from(state.files);
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/pdf_cache');

    for (final id in fileIds) {
      final file = updatedFiles[id];
      if (file == null) continue;

      if (file.driveId != null) {
        try {
          await driveService.deleteVisibleFile(file.driveId!);
        } catch (e) {
          if (!forceLocalDelete &&
              e.toString().contains('FileNotFoundOnDrive')) {
            throw Exception('FileNotFoundOnDrive');
          }
          if (!forceLocalDelete) {
            rethrow;
          }
        }
      }

      final fileExt = extensionForMimeType(file.mimeType);
      final localFile = File('${cacheDir.path}/$id$fileExt');
      if (await localFile.exists()) {
        await localFile.delete();
      }

      updatedFiles.remove(id);
    }

    state = state.copyWith(files: updatedFiles);
    await ref.read(syncServiceProvider).saveAndSync(state);
  }

  Future<void> removeFromCache(String fileId) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = state.files[fileId];
    final ext = dbFile != null ? extensionForMimeType(dbFile.mimeType) : '.bin';
    final cacheFile = File('${dir.path}/pdf_cache/$fileId$ext');
    if (await cacheFile.exists()) {
      await cacheFile.delete();
    }
  }

  Future<void> clearAllCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/pdf_cache');
    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }
}

String extensionForMimeType(String mimeType) {
  switch (mimeType) {
    case 'application/pdf':
      return '.pdf';
    case 'application/msword':
      return '.doc';
    case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      return '.docx';
    case 'application/vnd.ms-powerpoint':
      return '.ppt';
    case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      return '.pptx';
    case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      return '.xlsx';
    case 'text/plain':
      return '.txt';
    case 'application/octet-stream':
      return '.bin';
    default:
      return '.bin';
  }
}
