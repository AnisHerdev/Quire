class FilenameTagMatcher {
  static bool matches(String filename, String tag) {
    final normalizedFilename = filename.toUpperCase();
    final normalizedTag = tag.trim().toUpperCase();
    if (normalizedTag.isEmpty) return false;

    final escapedTag = RegExp.escape(normalizedTag);
    final pattern = RegExp('(?:^|[^A-Z0-9])$escapedTag');
    return pattern.hasMatch(normalizedFilename);
  }
}
