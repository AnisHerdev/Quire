class SubjectDetector {
  static final Set<String> _blacklist = {
    'README', 'SUMMARY', 'NOTES', 'INDEX', 'CHANGES', 'LICENSE',
  };

  static final RegExp _prefixPattern = RegExp(r'^([A-Z]{2,4})\d*[_ -]');

  static List<String> detect(String filename) {
    final name = filename.split('.').first.trim();
    if (name.isEmpty) return [];

    final match = _prefixPattern.firstMatch(name);
    if (match == null) return [];

    final prefix = match.group(1)!;
    if (_blacklist.contains(prefix.toUpperCase())) return [];

    return [prefix.toUpperCase()];
  }
}
