import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/database_model.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';
import 'drive_provider.dart';

final databaseProvider = NotifierProvider<DatabaseNotifier, QuireDatabase>(DatabaseNotifier.new);

class DatabaseNotifier extends Notifier<QuireDatabase> {
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
    final syncService = ref.read(syncServiceProvider);
    // Overwrites state with the merged cloud data
    state = await syncService.syncWithCloud(state);
  }

  Future<void> addSemester(String name) async {
    final id = 'sem_${DateTime.now().millisecondsSinceEpoch}';
    final newSem = SemesterModel(name: name, order: state.semesters.length + 1);
    
    final updatedSemesters = Map<String, SemesterModel>.from(state.semesters)..[id] = newSem;
    state = state.copyWith(semesters: updatedSemesters);
    
    await ref.read(syncServiceProvider).saveAndSync(state);
  }

  Future<void> addSubject(String name, String semesterId) async {
    final id = 'subj_${DateTime.now().millisecondsSinceEpoch}';
    final newSubj = SubjectModel(name: name, semesterId: semesterId);
    
    final updatedSubjects = Map<String, SubjectModel>.from(state.subjects)..[id] = newSubj;
    state = state.copyWith(subjects: updatedSubjects);
    
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

  Future<void> processSharedFiles(List<SharedMediaFile> files, {List<String>? customNames}) async {
    final isAuthenticated = await _ensureDriveAuthenticated();
    if (!isAuthenticated) {
      throw StateError('User is not authenticated with Google.');
    }

    final driveService = ref.read(driveServiceProvider);
    final updatedFiles = Map<String, QuireFileModel>.from(state.files);
    bool stateChanged = false;

    for (var sharedFile in files) {
      try {
        final file = File(sharedFile.path);
        if (!await file.exists()) continue;

        // Extract original name or use custom name
        final index = files.indexOf(sharedFile);
        final finalName = (customNames != null && customNames.length > index && customNames[index].isNotEmpty) 
            ? customNames[index] 
            : (sharedFile.path.split(Platform.pathSeparator).last);
            
        final mimeType = sharedFile.mimeType ?? 'application/pdf'; // fallback

        // Generate a local ID and copy file to cache immediately
        const uuid = Uuid();
        final localId = 'local_${uuid.v4()}';
        
        final dir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory('${dir.path}/pdf_cache');
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }
        
        final localFile = File('${cacheDir.path}/$localId.pdf');
        await file.copy(localFile.path);

        // Instantly save to local database
        final newFile = QuireFileModel(
          name: finalName,
          mimeType: mimeType,
          semesterId: '', // Uncategorized
          subjectId: '',  // Uncategorized
          addedAt: DateTime.now().millisecondsSinceEpoch,
          tags: [],
          syncStatus: 'pending',
          driveId: null,
        );
        
        updatedFiles[localId] = newFile;
        stateChanged = true;
      } catch (e) {
        print('Error processing shared file: $e');
      }
    }

    if (stateChanged) {
      state = state.copyWith(files: updatedFiles);
      await ref.read(syncServiceProvider).saveAndSync(state);
      
      // Kick off background sync without blocking UI
      _syncPendingFiles();
    }
  }

  Future<void> _syncPendingFiles() async {
    final driveService = ref.read(driveServiceProvider);
    if (!driveService.isReady) return;

    final pendingFiles = state.files.entries.where((e) => e.value.syncStatus == 'pending').toList();
    if (pendingFiles.isEmpty) return;

    try {
      final rootId = await driveService.createVisibleFolder('Quire Inbox', null);
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/pdf_cache');
      
      bool dbChanged = false;
      final updatedFiles = Map<String, QuireFileModel>.from(state.files);

      for (var entry in pendingFiles) {
        final localId = entry.key;
        final fileModel = entry.value;
        
        final localFile = File('${cacheDir.path}/$localId.pdf');
        if (await localFile.exists()) {
          try {
            final driveFile = await driveService.uploadVisibleFile(
              localFile, 
              fileModel.mimeType, 
              rootId,
              customName: fileModel.name, // Pass the exact database name!
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
        state = state.copyWith(files: updatedFiles);
        await ref.read(syncServiceProvider).saveAndSync(state);
      }
    } catch (e) {
      print('Failed to sync pending files: $e');
    }
  }

  Future<Future<void> Function()> moveFiles(List<String> fileIds, String newSemesterId, String newSubjectId) async {
    final originalStates = <String, QuireFileModel>{};
    final updatedFiles = Map<String, QuireFileModel>.from(state.files);
    
    for (final id in fileIds) {
      if (updatedFiles.containsKey(id)) {
        originalStates[id] = updatedFiles[id]!;
        updatedFiles[id] = updatedFiles[id]!.copyWith(
          semesterId: newSemesterId,
          subjectId: newSubjectId,
        );
      }
    }
    
    state = state.copyWith(files: updatedFiles);
    await ref.read(syncServiceProvider).saveAndSync(state);

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
}
