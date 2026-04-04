import 'package:clockwork/day_entry_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayEntryTimeRangesOverlap', () {
    test('returns true for overlapping ranges', () {
      final left = DayEntryTimeRange(startMinutes: 9 * 60, endMinutes: 10 * 60);
      final right = DayEntryTimeRange(
        startMinutes: 9 * 60 + 30,
        endMinutes: 10 * 60 + 30,
      );

      expect(dayEntryTimeRangesOverlap(left, right), isTrue);
    });

    test('returns false when ranges only touch at the boundary', () {
      final left = DayEntryTimeRange(startMinutes: 9 * 60, endMinutes: 10 * 60);
      final right = DayEntryTimeRange(
        startMinutes: 10 * 60,
        endMinutes: 11 * 60,
      );

      expect(dayEntryTimeRangesOverlap(left, right), isFalse);
    });

    test('returns false when either range is invalid', () {
      final left = DayEntryTimeRange(
        startMinutes: 11 * 60,
        endMinutes: 10 * 60,
      );
      final right = DayEntryTimeRange(
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
      );

      expect(dayEntryTimeRangesOverlap(left, right), isFalse);
    });
  });

  group('findOverlappingDayEntryIndices', () {
    test('returns the indices for all overlapping ranges', () {
      final ranges = [
        DayEntryTimeRange(startMinutes: 8 * 60, endMinutes: 9 * 60),
        DayEntryTimeRange(startMinutes: 8 * 60 + 30, endMinutes: 9 * 60 + 15),
        DayEntryTimeRange(startMinutes: 10 * 60, endMinutes: 11 * 60),
        DayEntryTimeRange(startMinutes: 10 * 60 + 30, endMinutes: 11 * 60 + 30),
      ];

      expect(findOverlappingDayEntryIndices(ranges), equals({0, 1, 2, 3}));
    });

    test('ignores null, incomplete, and boundary-touching ranges', () {
      final ranges = [
        DayEntryTimeRange(startMinutes: 9 * 60, endMinutes: 10 * 60),
        DayEntryTimeRange(startMinutes: 10 * 60, endMinutes: 11 * 60),
        null,
        DayEntryTimeRange(startMinutes: 12 * 60, endMinutes: 12 * 60),
      ];

      expect(findOverlappingDayEntryIndices(ranges), isEmpty);
    });
  });
}
