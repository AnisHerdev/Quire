import 'package:flutter_test/flutter_test.dart';
import 'package:quire/utils/subject_detector.dart';

void main() {
  group('SubjectDetector.detect', () {
    test('detects 2-letter subject code with underscore', () {
      expect(SubjectDetector.detect('DS_Unit3.pdf'), ['DS']);
    });

    test('detects 2-letter code with number right after', () {
      expect(SubjectDetector.detect('CS101_HW1.docx'), ['CS']);
    });

    test('detects 3-letter code with hyphen', () {
      expect(SubjectDetector.detect('ECE-301-Lab2.ppt'), ['ECE']);
    });

    test('detects 4-letter code with space', () {
      expect(SubjectDetector.detect('CHEM 101 notes.pdf'), ['CHEM']);
    });

    test('returns empty for no uppercase prefix', () {
      expect(SubjectDetector.detect('my_notes.pdf'), []);
    });

    test('returns empty for filename without separator', () {
      expect(SubjectDetector.detect('NoUnderscore.pdf'), []);
    });

    test('returns empty for README (blacklisted)', () {
      expect(SubjectDetector.detect('README.pdf'), []);
    });

    test('returns empty for SUMMARY (blacklisted)', () {
      expect(SubjectDetector.detect('SUMMARY.docx'), []);
    });

    test('returns empty for NOTES (blacklisted)', () {
      expect(SubjectDetector.detect('NOTES.pdf'), []);
    });

    test('returns empty for empty string', () {
      expect(SubjectDetector.detect(''), []);
    });

    test('detects with hyphen separator', () {
      expect(SubjectDetector.detect('BIO-101-lab.pdf'), ['BIO']);
    });

    test('detects with space separator', () {
      expect(SubjectDetector.detect('MATH 201 final.pdf'), ['MATH']);
    });

    test('returns empty for single uppercase letter', () {
      expect(SubjectDetector.detect('A_notes.pdf'), []);
    });

    test('returns empty for 5-letter uppercase prefix', () {
      expect(SubjectDetector.detect('PHYSICS_101.pdf'), []);
    });

    test('returns empty for INDEX (blacklisted)', () {
      expect(SubjectDetector.detect('INDEX.txt'), []);
    });

    test('returns empty for CHANGES (blacklisted)', () {
      expect(SubjectDetector.detect('CHANGES.md'), []);
    });

    test('returns empty for LICENSE (blacklisted)', () {
      expect(SubjectDetector.detect('LICENSE.txt'), []);
    });
  });
}
