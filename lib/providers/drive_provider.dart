import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/drive_service.dart';
import '../models/note_file_model.dart';
import 'auth_provider.dart';

final driveServiceProvider = Provider<DriveService>((ref) {
  return DriveService();
});

class DriveFolderState {
  final bool isLoading;
  final String? quireFolderId;
  final String? error;
  final List<NoteFileModel> rootFiles;

  DriveFolderState({
    this.isLoading = false,
    this.quireFolderId,
    this.error,
    this.rootFiles = const [],
  });
}

class DriveFolderNotifier extends Notifier<DriveFolderState> {
  @override
  DriveFolderState build() {
    return DriveFolderState();
  }

  Future<void> initialize() async {
    state = DriveFolderState(isLoading: true);
    
    try {
      final driveService = ref.read(driveServiceProvider);
      final authService = ref.read(authServiceProvider);
      final googleAccount = authService.currentGoogleAccount;
      
      if (googleAccount == null) {
        state = DriveFolderState(error: 'Not signed in with Google');
        return;
      }
      
      driveService.setAccount(googleAccount);
      
      final folderId = await driveService.getOrCreateQuireFolder();
      final rootFiles = await driveService.listFiles(folderId);
      
      state = DriveFolderState(
        isLoading: false,
        quireFolderId: folderId,
        rootFiles: rootFiles,
      );
    } catch (e) {
      state = DriveFolderState(error: e.toString());
    }
  }
}

final driveFolderProvider = NotifierProvider<DriveFolderNotifier, DriveFolderState>(DriveFolderNotifier.new);

final folderFilesProvider = FutureProvider.family<List<NoteFileModel>, String>((ref, folderId) async {
  final driveService = ref.read(driveServiceProvider);
  final authService = ref.read(authServiceProvider);
  driveService.setAccount(authService.currentGoogleAccount);
  return driveService.listFiles(folderId);
});
