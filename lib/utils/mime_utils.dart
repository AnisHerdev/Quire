const Map<String, String> _extensionToMime = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'html': 'text/html',
  'htm': 'text/html',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'svg': 'image/svg+xml',
  'zip': 'application/zip',
  'gdoc': 'application/vnd.google-apps.document',
  'gsheet': 'application/vnd.google-apps.spreadsheet',
  'gslides': 'application/vnd.google-apps.presentation',
};

const Map<String, String> _mimeToExtension = {
  'application/pdf': '.pdf',
  'application/msword': '.doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
  'application/vnd.ms-powerpoint': '.ppt',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': '.pptx',
  'application/vnd.ms-excel': '.xls',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
  'text/plain': '.txt',
  'text/csv': '.csv',
  'text/html': '.html',
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/gif': '.gif',
  'image/svg+xml': '.svg',
  'application/zip': '.zip',
  'application/vnd.google-apps.document': '.gdoc',
  'application/vnd.google-apps.spreadsheet': '.gsheet',
  'application/vnd.google-apps.presentation': '.gslides',
};

String mimeTypeForExtension(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return _extensionToMime[ext] ?? 'application/octet-stream';
}

String extensionForMimeType(String mimeType) {
  return _mimeToExtension[mimeType] ?? '.bin';
}
