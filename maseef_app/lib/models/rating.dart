/// A chalet's public rating, exactly as stored by a reviews backend.
///
/// There is no default and no placeholder: a chalet without genuine reviews has
/// no [RatingSummary] at all (`null`), and the UI says "No ratings yet".
class RatingSummary {
  const RatingSummary({required this.average, required this.count});

  /// Mean score from 1 to 5.
  final double average;

  /// Number of genuine reviews behind [average].
  final int count;

  /// Only a positive review count and an in-range average may be shown.
  bool get isShowable =>
      count > 0 && !average.isNaN && average >= 1 && average <= 5;
}
