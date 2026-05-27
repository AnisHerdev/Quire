class FileModel {
  final String id;
  final String name;
  final String mimeType;
  final String? size;
  final DateTime? modifiedTime;
  final List<String>? parentIds;
  final bool isFolder;
  final String filePath; // Computed breadcrumb string

  const FileModel({
    required this.id,
    required this.name,
    required this.mimeType,
    this.size,
    this.modifiedTime,
    this.parentIds,
    required this.isFolder,
    required this.filePath,
  });

  // Factory to be implemented later when googleapis is integrated
  // factory FileModel.fromDriveFile(drive.File file, String computedPath) {
  //   return FileModel(
  //     id: file.id ?? '',
  //     name: file.name ?? '',
  //     mimeType: file.mimeType ?? '',
  //     size: file.size,
  //     modifiedTime: file.modifiedTime,
  //     parentIds: file.parents,
  //     isFolder: file.mimeType == 'application/vnd.google-apps.folder',
  //     filePath: computedPath,
  //   );
  // }
}
