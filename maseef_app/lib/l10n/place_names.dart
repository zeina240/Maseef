/// English display names for the Arabic place names stored on each listing.
///
/// Unknown places stay as stored rather than being given an invented name.
const Map<String, String> englishPlaceNames = {
  'نابلس': 'Nablus',
  'جنين': 'Jenin',
  'النصارية': 'Al-Nasariya',
  'طلوزة': 'Talluza',
  'دير غزالة': 'Deir Ghazaleh',
};

/// Extra spellings that should still find the place. They are not shown.
const Map<String, List<String>> extraPlaceSearchTerms = {
  'النصارية': ['Nasariya'],
  'طلوزة': ['Talouza', 'Tallouza'],
  'دير غزالة': ['Deir Ghazala', 'Deir Ghazalah'],
};

String displayPlaceName(String canonical, {required bool arabic}) {
  if (arabic) return canonical;
  return englishPlaceNames[canonical] ?? canonical;
}

List<String> searchTermsForPlace(String canonical) {
  final terms = <String>[canonical];
  final english = englishPlaceNames[canonical];
  if (english != null) terms.add(english);
  final extra = extraPlaceSearchTerms[canonical];
  if (extra != null) terms.addAll(extra);
  return terms;
}
