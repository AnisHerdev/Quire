class SyncMetadata {
  final int lastSyncedAt;
  final String version;

  const SyncMetadata({
    required this.lastSyncedAt,
    required this.version,
  });

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      lastSyncedAt: json['lastSyncedAt'] as int? ?? 0,
      version: json['version'] as String? ?? '1.0',
    );
  }

  Map<String, dynamic> toJson() => {
        'lastSyncedAt': lastSyncedAt,
        'version': version,
      };

  SyncMetadata copyWith({
    int? lastSyncedAt,
    String? version,
  }) {
    return SyncMetadata(
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      version: version ?? this.version,
    );
  }
}

class FolderModel {
  final String id;
  final String name;
  final String? parentId;
  final int order;
  final int createdAt;
  final String? driveId;
  final String syncStatus;
  final List<String> associatedTags;

  const FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    required this.order,
    required this.createdAt,
    this.driveId,
    this.syncStatus = 'synced',
    this.associatedTags = const [],
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Folder',
      parentId: json['parentId'] as String?,
      order: json['order'] as int? ?? 0,
      createdAt: json['createdAt'] as int? ?? 0,
      driveId: json['driveId'] as String?,
      syncStatus: json['syncStatus'] as String? ?? 'synced',
      associatedTags: (json['associatedTags'] as List<dynamic>?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (parentId != null) 'parentId': parentId,
        'order': order,
        'createdAt': createdAt,
        if (driveId != null) 'driveId': driveId,
        'syncStatus': syncStatus,
        if (associatedTags.isNotEmpty) 'associatedTags': associatedTags,
      };

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentId,
    int? order,
    int? createdAt,
    String? driveId,
    String? syncStatus,
    List<String>? associatedTags,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      driveId: driveId ?? this.driveId,
      syncStatus: syncStatus ?? this.syncStatus,
      associatedTags: associatedTags ?? this.associatedTags,
    );
  }
}

class QuireFileModel {
  final String name;
  final String mimeType;
  final String? folderId;
  final int addedAt;
  final List<String> tags;
  final String? driveId;
  final String syncStatus;

  const QuireFileModel({
    required this.name,
    required this.mimeType,
    this.folderId,
    required this.addedAt,
    required this.tags,
    this.driveId,
    this.syncStatus = 'synced',
  });

  factory QuireFileModel.fromJson(Map<String, dynamic> json) {
    return QuireFileModel(
      name: json['name'] as String? ?? 'Unnamed File',
      mimeType: json['mimeType'] as String? ?? '',
      folderId: (json['folderId'] as String?)?.isNotEmpty == true ? json['folderId'] : null,
      addedAt: json['addedAt'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      driveId: json['driveId'] as String?,
      syncStatus: json['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'mimeType': mimeType,
        if (folderId != null) 'folderId': folderId,
        'addedAt': addedAt,
        'tags': tags,
        if (driveId != null) 'driveId': driveId,
        'syncStatus': syncStatus,
      };

  QuireFileModel copyWith({
    String? name,
    String? mimeType,
    String? folderId,
    bool clearFolderId = false,
    int? addedAt,
    List<String>? tags,
    String? driveId,
    String? syncStatus,
  }) {
    return QuireFileModel(
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      addedAt: addedAt ?? this.addedAt,
      tags: tags ?? this.tags,
      driveId: driveId ?? this.driveId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class QuireDatabase {
  final SyncMetadata syncMetadata;
  final Map<String, FolderModel> folders;
  final Map<String, QuireFileModel> files;
  final Set<String> allTags;

  const QuireDatabase({
    required this.syncMetadata,
    required this.folders,
    required this.files,
    this.allTags = const {},
  });

  factory QuireDatabase.empty() {
    return QuireDatabase(
      syncMetadata: SyncMetadata(
        lastSyncedAt: 0,
        version: '2.0',
      ),
      folders: const {},
      files: const {},
    );
  }

  factory QuireDatabase.fromJson(Map<String, dynamic> json) {
    // If version is < 2.0, force a fresh start by returning empty.
    final syncMetaJson = json['syncMetadata'] as Map<String, dynamic>?;
    final version = syncMetaJson?['version'] as String? ?? '1.0';
    if (!version.startsWith('2.')) {
      return QuireDatabase.empty();
    }

    final foldersJson = json['folders'] as Map<String, dynamic>? ?? {};
    final filesJson = json['files'] as Map<String, dynamic>? ?? {};
    final tagsList = json['allTags'] as List<dynamic>? ?? [];

    return QuireDatabase(
      syncMetadata: syncMetaJson != null 
          ? SyncMetadata.fromJson(syncMetaJson)
          : SyncMetadata(lastSyncedAt: 0, version: '2.0'),
      folders: foldersJson.map((k, v) => MapEntry(k, FolderModel.fromJson(v as Map<String, dynamic>))),
      files: filesJson.map((k, v) => MapEntry(k, QuireFileModel.fromJson(v as Map<String, dynamic>))),
      allTags: tagsList.map((e) => e.toString()).toSet(),
    );
  }

  Map<String, dynamic> toJson() => {
        'syncMetadata': syncMetadata.toJson(),
        'folders': folders.map((k, v) => MapEntry(k, v.toJson())),
        'files': files.map((k, v) => MapEntry(k, v.toJson())),
        'allTags': allTags.toList(),
      };

  QuireDatabase copyWith({
    SyncMetadata? syncMetadata,
    Map<String, FolderModel>? folders,
    Map<String, QuireFileModel>? files,
    Set<String>? allTags,
  }) {
    return QuireDatabase(
      syncMetadata: syncMetadata ?? this.syncMetadata,
      folders: folders ?? this.folders,
      files: files ?? this.files,
      allTags: allTags ?? this.allTags,
    );
  }
}
