import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import '../models/note_file_model.dart';

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

  Future<drive.File> uploadVisibleFile(File localFile, String mimeType, String parentId) async {
    try {
      final driveApi = await _getDriveApi();
      final length = await localFile.length();
      final media = drive.Media(localFile.openRead(), length);
      
      final fileName = localFile.path.split(Platform.pathSeparator).last;
      
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
}
