class DayEntryTimeRange {
  const DayEntryTimeRange({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  bool get isValid => endMinutes > startMinutes;
}

bool dayEntryTimeRangesOverlap(
  DayEntryTimeRange left,
  DayEntryTimeRange right,
) {
  if (!left.isValid || !right.isValid) {
    return false;
  }

  return left.startMinutes < right.endMinutes &&
      left.endMinutes > right.startMinutes;
}

Set<int> findOverlappingDayEntryIndices(List<DayEntryTimeRange?> ranges) {
  final overlappingIndices = <int>{};

  for (var leftIndex = 0; leftIndex < ranges.length; leftIndex++) {
    final leftRange = ranges[leftIndex];
    if (leftRange == null || !leftRange.isValid) {
      continue;
    }

    for (
      var rightIndex = leftIndex + 1;
      rightIndex < ranges.length;
      rightIndex++
    ) {
      final rightRange = ranges[rightIndex];
      if (rightRange == null || !rightRange.isValid) {
        continue;
      }

      if (!dayEntryTimeRangesOverlap(leftRange, rightRange)) {
        continue;
      }

      overlappingIndices.add(leftIndex);
      overlappingIndices.add(rightIndex);
    }
  }

  return overlappingIndices;
}
