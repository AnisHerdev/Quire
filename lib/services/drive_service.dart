import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import '../utils/mime_utils.dart';

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class DriveService {
  GoogleSignInAccount? _account;
  static const String databaseFileName = 'database.json';

  DriveService();

  bool get isReady => _account != null;

  void setAccount(GoogleSignInAccount? account) {
    _account = account;
  }

  Future<http.Client> _getAuthenticatedClient() async {
    if (_account == null) {
      throw Exception('User is not authenticated with Google.');
    }
    
    final auth = await _account!.authentication;
    final token = auth.accessToken;
    
    if (token == null) {
      throw Exception('Failed to get Google access token.');
    }
    
    return _GoogleAuthClient({
      'Authorization': 'Bearer $token',
      'X-Goog-AuthUser': '0',
    });
  }

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await _getAuthenticatedClient();
    return drive.DriveApi(client);
  }

  // --- App Data Folder Methods (Hidden Sync) ---

  Future<String?> downloadDatabase() async {
    try {
      final driveApi = await _getDriveApi();
      final query = "name='$databaseFileName' and 'appDataFolder' in parents and trashed=false";
      
      final fileList = await driveApi.files.list(q: query, spaces: 'appDataFolder');
      
      if (fileList.files == null || fileList.files!.isEmpty) {
        return null; // Database doesn't exist yet
      }

      final fileId = fileList.files!.first.id!;
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await media.stream.fold<List<int>>(
        [], 
        (previous, element) => previous..addAll(element)
      );
      
      return utf8.decode(bytes);
    } catch (e) {
      print('Failed to download database: $e');
      return null;
    }
  }

  Future<void> uploadDatabase(String jsonString) async {
    try {
      final driveApi = await _getDriveApi();
      final query = "name='$databaseFileName' and 'appDataFolder' in parents and trashed=false";
      
      final fileList = await driveApi.files.list(q: query, spaces: 'appDataFolder');
      
      final bytes = utf8.encode(jsonString);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Update existing file
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(
          drive.File(),
          fileId,
          uploadMedia: media,
        );
      } else {
        // Create new file in appDataFolder
        final newFile = drive.File()
          ..name = databaseFileName
          ..parents = ['appDataFolder']
          ..mimeType = 'application/json';
          
        await driveApi.files.create(
          newFile,
          uploadMedia: media,
        );
      }
    } catch (e) {
      throw Exception('Failed to upload database: $e');
    }
  }

  // --- Visible Drive Methods (PDF Storage) ---

  Future<String> createVisibleFolder(String name, String? parentId) async {
    try {
      final driveApi = await _getDriveApi();
      const mimeType = 'application/vnd.google-apps.folder';
      
      // Check if folder already exists in the given parent
      String query = "name='$name' and mimeType='$mimeType' and trashed=false";
      if (parentId != null) {
        query += " and '$parentId' in parents";
      } else {
        query += " and 'root' in parents";
      }
      
      final fileList = await driveApi.files.list(q: query, spaces: 'drive');
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id!;
      }
      
      final newFolder = drive.File()
        ..name = name
        ..mimeType = mimeType;
        
      if (parentId != null) {
        newFolder.parents = [parentId];
      }
        
      final createdFolder = await driveApi.files.create(newFolder);
      return createdFolder.id!;
    } catch (e) {
      throw Exception('Failed to create visible folder "$name": $e');
    }
  }

  Future<String> getOrCreateQuireRootFolder() async {
    // Option A Migration: Rename 'Quire Inbox' to 'Quire' if it exists.
    try {
      final driveApi = await _getDriveApi();
      final query = "name='Quire Inbox' and mimeType='application/vnd.google-apps.folder' and 'root' in parents and trashed=false";
      final fileList = await driveApi.files.list(q: query, spaces: 'drive');
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final inboxFolder = fileList.files!.first;
        final updateFile = drive.File()..name = 'Quire';
        await driveApi.files.update(updateFile, inboxFolder.id!);
      }
    } catch (e) {
      print('Migration check failed (safe to ignore if not applicable): $e');
    }

    return await createVisibleFolder('Quire', null);
  }

  Future<drive.File> uploadVisibleFile(File localFile, String mimeType, String parentId, {String? customName}) async {
    try {
      final driveApi = await _getDriveApi();
      final length = await localFile.length();
      final media = drive.Media(localFile.openRead(), length);
      
      final fileName = customName ?? localFile.path.split(Platform.pathSeparator).last;
      
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [parentId]
        ..mimeType = mimeType;
        
      final createdFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );
      
      return createdFile;
    } catch (e) {
      throw Exception('Failed to upload file to visible drive: $e');
    }
  }

  Future<void> moveVisibleItem(String itemId, String? oldParentId, String newParentId) async {
    try {
      final driveApi = await _getDriveApi();
      await driveApi.files.update(
        drive.File(),
        itemId,
        addParents: newParentId,
        removeParents: oldParentId,
      );
    } catch (e) {
      throw Exception('Failed to move item in Google Drive: $e');
    }
  }

  Future<void> renameVisibleItem(String itemId, String newName) async {
    try {
      final driveApi = await _getDriveApi();
      final updateFile = drive.File()..name = newName;
      await driveApi.files.update(updateFile, itemId);
    } catch (e) {
      throw Exception('Failed to rename item in Google Drive: $e');
    }
  }

  Future<void> deleteVisibleFile(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      await driveApi.files.delete(fileId);
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('File not found')) {
        throw Exception('FileNotFoundOnDrive');
      }
      throw Exception('Failed to delete file from Google Drive: $e');
    }
  }

  Future<Uint8List?> getThumbnail(String driveId) async {
    try {
      final driveApi = await _getDriveApi();
      final file = await driveApi.files.get(driveId, $fields: 'thumbnailLink') as drive.File;
      final link = file.thumbnailLink;
      if (link != null) {
        final client = await _getAuthenticatedClient();
        final response = await client.get(Uri.parse(link));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      }
    } catch (e) {
      print('Failed to get thumbnail: $e');
    }
    return null;
  }

  Future<Uint8List> downloadFile(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      final bytes = await media.stream.fold<List<int>>(
        [], 
        (previous, element) => previous..addAll(element)
      );
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  Future<Uint8List> getPdfBytes(String fileId, String? driveId, {String mimeType = 'application/pdf'}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/pdf_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      final ext = extensionForMimeType(mimeType);
      final localFile = File('${cacheDir.path}/$fileId$ext');
      
      if (await localFile.exists()) {
        return await localFile.readAsBytes();
      }

      if (driveId == null || driveId.isEmpty) {
        throw Exception(
          'This file has not finished uploading to the cloud yet '
          'and the local copy was removed from this device. '
          'Please connect to the internet, wait for the file to sync, then try again.',
        );
      }

      final bytes = await downloadFile(driveId);
      
      // Save to cache for next time
      await localFile.writeAsBytes(bytes);
      
      return bytes;
    } catch (e) {
      throw Exception('Failed to load file: $e');
    }
  }

  Future<List<String>> searchFilesContent(String query) async {
    try {
      final driveApi = await _getDriveApi();
      final safeQuery = query.replaceAll("'", "\\'");
      final q = "fullText contains '$safeQuery' and trashed=false";
      
      final fileList = await driveApi.files.list(q: q, spaces: 'drive');
      
      if (fileList.files == null || fileList.files!.isEmpty) {
        return [];
      }
      
      return fileList.files!.map((f) => f.id!).toList();
    } catch (e) {
      print('Deep search failed: $e');
      return [];
    }
  }

  Future<String> getStorageQuota() async {
    try {
      final driveApi = await _getDriveApi();
      final about = await driveApi.about.get($fields: 'storageQuota');
      
      final usageBytes = int.tryParse(about.storageQuota?.usage ?? '0') ?? 0;
      final limitBytes = int.tryParse(about.storageQuota?.limit ?? '0') ?? 0;
      
      if (limitBytes == 0) return 'Unknown Storage';
      
      String formatBytes(int bytes) {
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
      
      return '${formatBytes(usageBytes)} used of ${formatBytes(limitBytes)}';
    } catch (e) {
      if (e.toString().contains('401')) return 'Connecting to Drive...';
      return 'Storage unavailable';
    }
  }
}
