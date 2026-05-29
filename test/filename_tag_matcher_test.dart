import 'package:flutter_test/flutter_test.dart';
import 'package:quire/utils/filename_tag_matcher.dart';

void main() {
  group('FilenameTagMatcher.matches', () {
    test('matches a tag as a complete filename segment', () {
      expect(FilenameTagMatcher.matches('os_osfil.pdf', 'os'), isTrue);
    });

    test('matches a tag at the start of the filename', () {
      expect(FilenameTagMatcher.matches('syncronize.pdf', 'syn'), isTrue);
    });

    test('matches a tag at the start of any separated segment', () {
      expect(
        FilenameTagMatcher.matches('unit-3_syncronize.pdf', 'syn'),
        isTrue,
      );
    });

    test('does not match a tag buried inside a word', () {
      expect(FilenameTagMatcher.matches('bios.pdf', 'os'), isFalse);
    });

    test('ignores whitespace and case in tags', () {
      expect(FilenameTagMatcher.matches('SYN_notes.pdf', ' syn '), isTrue);
    });

    test('does not match an empty tag', () {
      expect(FilenameTagMatcher.matches('notes.pdf', ''), isFalse);
    });
  });
}
