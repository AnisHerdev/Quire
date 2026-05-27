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

  Future<String> getOrCreateQuireFolder() async {
    try {
      final driveApi = await _getDriveApi();
      const folderName = 'Quire-Notes';
      const mimeType = 'application/vnd.google-apps.folder';
      
      final query = "name='$folderName' and mimeType='$mimeType' and trashed=false";
      final fileList = await driveApi.files.list(q: query, spaces: 'drive');
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id!;
      }
      
      final newFolder = drive.File()
        ..name = folderName
        ..mimeType = mimeType;
        
      final createdFolder = await driveApi.files.create(newFolder);
      return createdFolder.id!;
    } catch (e) {
      throw Exception('Failed to get or create Quire folder: $e');
    }
  }

  Future<List<NoteFileModel>> listFiles(String parentFolderId) async {
    try {
      final driveApi = await _getDriveApi();
      final query = "'$parentFolderId' in parents and trashed=false";
      
      const fields = 'files(id, name, mimeType, size, modifiedTime, parents)';
      
      final fileList = await driveApi.files.list(
        q: query,
        orderBy: 'folder, name',
        pageSize: 1000,
        $fields: fields,
      );
      
      final files = fileList.files ?? [];
      return files.map((f) => NoteFileModel.fromGoogleDriveFile(f)).toList();
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }

  Future<List<NoteFileModel>> getAllFilesRecursive(String rootFolderId) async {
    try {
      final result = <NoteFileModel>[];
      await _fetchRecursively(rootFolderId, '', result);
      return result;
    } catch (e) {
      throw Exception('Failed to fetch all files recursively: $e');
    }
  }

  Future<void> _fetchRecursively(String folderId, String currentPath, List<NoteFileModel> result) async {
    final driveApi = await _getDriveApi();
    final query = "'$folderId' in parents and trashed=false";
    const fields = 'files(id, name, mimeType, size, modifiedTime, parents)';
    
    final fileList = await driveApi.files.list(
      q: query,
      orderBy: 'folder, name',
      pageSize: 1000,
      $fields: fields,
    );
    
    final items = fileList.files ?? [];
    for (var item in items) {
      final model = NoteFileModel.fromGoogleDriveFile(item);
      final newPath = currentPath.isEmpty ? model.name : '$currentPath > ${model.name}';
      model.filePath = newPath;
      
      result.add(model);
      
      if (model.isFolder) {
        await _fetchRecursively(model.id, newPath, result);
      }
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
