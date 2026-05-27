import 'dart:convert';

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

class SemesterModel {
  final String name;
  final int order;

  const SemesterModel({
    required this.name,
    required this.order,
  });

  factory SemesterModel.fromJson(Map<String, dynamic> json) {
    return SemesterModel(
      name: json['name'] as String? ?? 'Unknown Semester',
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'order': order,
      };

  SemesterModel copyWith({
    String? name,
    int? order,
  }) {
    return SemesterModel(
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }
}

class SubjectModel {
  final String name;
  final String semesterId;

  const SubjectModel({
    required this.name,
    required this.semesterId,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      name: json['name'] as String? ?? 'Unknown Subject',
      semesterId: json['semesterId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'semesterId': semesterId,
      };

  SubjectModel copyWith({
    String? name,
    String? semesterId,
  }) {
    return SubjectModel(
      name: name ?? this.name,
      semesterId: semesterId ?? this.semesterId,
    );
  }
}

class QuireFileModel {
  final String name;
  final String mimeType;
  final String semesterId;
  final String subjectId;
  final int addedAt;
  final List<String> tags;
  final String? driveId;
  final String syncStatus;

  const QuireFileModel({
    required this.name,
    required this.mimeType,
    required this.semesterId,
    required this.subjectId,
    required this.addedAt,
    required this.tags,
    this.driveId,
    this.syncStatus = 'synced',
  });

  factory QuireFileModel.fromJson(Map<String, dynamic> json) {
    return QuireFileModel(
      name: json['name'] as String? ?? 'Unnamed File',
      mimeType: json['mimeType'] as String? ?? '',
      semesterId: json['semesterId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      addedAt: json['addedAt'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      driveId: json['driveId'] as String?,
      syncStatus: json['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'mimeType': mimeType,
        'semesterId': semesterId,
        'subjectId': subjectId,
        'addedAt': addedAt,
        'tags': tags,
        if (driveId != null) 'driveId': driveId,
        'syncStatus': syncStatus,
      };

  QuireFileModel copyWith({
    String? name,
    String? mimeType,
    String? semesterId,
    String? subjectId,
    int? addedAt,
    List<String>? tags,
    String? driveId,
    String? syncStatus,
  }) {
    return QuireFileModel(
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      semesterId: semesterId ?? this.semesterId,
      subjectId: subjectId ?? this.subjectId,
      addedAt: addedAt ?? this.addedAt,
      tags: tags ?? this.tags,
      driveId: driveId ?? this.driveId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class QuireDatabase {
  final SyncMetadata syncMetadata;
  final Map<String, SemesterModel> semesters;
  final Map<String, SubjectModel> subjects;
  final Map<String, QuireFileModel> files;

  const QuireDatabase({
    required this.syncMetadata,
    required this.semesters,
    required this.subjects,
    required this.files,
  });

  factory QuireDatabase.empty() {
    return QuireDatabase(
      syncMetadata: SyncMetadata(
        lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
        version: '1.0',
      ),
      semesters: const {},
      subjects: const {},
      files: const {},
    );
  }

  factory QuireDatabase.fromJson(Map<String, dynamic> json) {
    final semestersJson = json['semesters'] as Map<String, dynamic>? ?? {};
    final subjectsJson = json['subjects'] as Map<String, dynamic>? ?? {};
    final filesJson = json['files'] as Map<String, dynamic>? ?? {};

    return QuireDatabase(
      syncMetadata: json['syncMetadata'] != null 
          ? SyncMetadata.fromJson(json['syncMetadata'] as Map<String, dynamic>)
          : SyncMetadata(lastSyncedAt: 0, version: '1.0'),
      semesters: semestersJson.map((k, v) => MapEntry(k, SemesterModel.fromJson(v as Map<String, dynamic>))),
      subjects: subjectsJson.map((k, v) => MapEntry(k, SubjectModel.fromJson(v as Map<String, dynamic>))),
      files: filesJson.map((k, v) => MapEntry(k, QuireFileModel.fromJson(v as Map<String, dynamic>))),
    );
  }

  Map<String, dynamic> toJson() => {
        'syncMetadata': syncMetadata.toJson(),
        'semesters': semesters.map((k, v) => MapEntry(k, v.toJson())),
        'subjects': subjects.map((k, v) => MapEntry(k, v.toJson())),
        'files': files.map((k, v) => MapEntry(k, v.toJson())),
      };

  QuireDatabase copyWith({
    SyncMetadata? syncMetadata,
    Map<String, SemesterModel>? semesters,
    Map<String, SubjectModel>? subjects,
    Map<String, QuireFileModel>? files,
  }) {
    return QuireDatabase(
      syncMetadata: syncMetadata ?? this.syncMetadata,
      semesters: semesters ?? this.semesters,
      subjects: subjects ?? this.subjects,
      files: files ?? this.files,
    );
  }
}
