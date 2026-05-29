String uniqueDuplicateFilename(
  String filename,
  Iterable<String> existingNames,
) {
  final takenNames = existingNames.map((name) => name.toLowerCase()).toSet();
  if (!takenNames.contains(filename.toLowerCase())) return filename;

  final dotIndex = filename.lastIndexOf('.');
  final hasExtension = dotIndex > 0;
  final baseName = hasExtension ? filename.substring(0, dotIndex) : filename;
  final extension = hasExtension ? filename.substring(dotIndex) : '';

  var copyNumber = 1;
  while (true) {
    final candidate = '$baseName ($copyNumber)$extension';
    if (!takenNames.contains(candidate.toLowerCase())) return candidate;
    copyNumber++;
  }
}
