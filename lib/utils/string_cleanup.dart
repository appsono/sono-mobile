String getPrimaryArtist(String? fullArtistName) {
  if (fullArtistName == null || fullArtistName.isEmpty) {
    return 'Unknown Artist';
  }

  final separators = [
    ' feat. ',
    ' ft. ',
    ' feat ',
    ' ft ',
    ' & ',
    ', ',
    '; ',
    ' with ',
  ];

  var lowercasedName = fullArtistName.toLowerCase();

  for (var separator in separators) {
    if (lowercasedName.contains(separator)) {
      return fullArtistName
          .split(RegExp(separator, caseSensitive: false))[0]
          .trim();
    }
  }

  return fullArtistName.trim();
}
