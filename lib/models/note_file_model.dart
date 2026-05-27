class NoteFileModel {
  final String id;
  final String name;
  final String mimeType;
  final int? size;
  final DateTime? modifiedTime;
  final List<String> parentIds;
  
  // Computed fields
  final bool isFolder;
  String filePath;

  NoteFileModel({
    required this.id,
    required this.name,
    this.mimeType = '',
    this.size,
    this.modifiedTime,
    this.parentIds = const [],
    this.filePath = '',
  }) : isFolder = mimeType == 'application/vnd.google-apps.folder';

  factory NoteFileModel.fromGoogleDriveFile(dynamic file) {
    // googleapis Drive File size comes as a String due to 64-bit integer limits in JSON
    int? parsedSize;
    if (file.size != null) {
      if (file.size is String) {
        parsedSize = int.tryParse(file.size as String);
      } else if (file.size is int) {
        parsedSize = file.size as int;
      }
    }

    return NoteFileModel(
      id: file.id ?? '',
      name: file.name ?? 'Untitled',
      mimeType: file.mimeType ?? '',
      size: parsedSize,
      modifiedTime: file.modifiedTime,
      parentIds: (file.parents as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  factory NoteFileModel.empty() {
    return NoteFileModel(
      id: '',
      name: '',
      mimeType: '',
    );
  }

  bool get isSupportedFile {
    return mimeType == 'application/pdf' || mimeType == 'text/plain';
  }
}
