import 'package:flutter_test/flutter_test.dart';
import 'package:quire/utils/duplicate_filename.dart';

void main() {
  group('uniqueDuplicateFilename', () {
    test('keeps the filename when it is not taken', () {
      expect(uniqueDuplicateFilename('Notes.pdf', ['Other.pdf']), 'Notes.pdf');
    });

    test('adds a copy number before the extension', () {
      expect(
        uniqueDuplicateFilename('Notes.pdf', ['Notes.pdf']),
        'Notes (1).pdf',
      );
    });

    test('increments past existing copies', () {
      expect(
        uniqueDuplicateFilename('Notes.pdf', [
          'Notes.pdf',
          'Notes (1).pdf',
          'Notes (2).pdf',
        ]),
        'Notes (3).pdf',
      );
    });

    test('compares names case-insensitively', () {
      expect(
        uniqueDuplicateFilename('Notes.pdf', ['notes.PDF']),
        'Notes (1).pdf',
      );
    });

    test('handles filenames without extensions', () {
      expect(uniqueDuplicateFilename('Notes', ['Notes']), 'Notes (1)');
    });
  });
}
