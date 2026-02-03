library;

/// Cleans up and formats artist names by handling multiple artists
/// Converts "Kanye West, Ty Dolla $ign" to "Kanye West, Ty Dolla $ign"
/// => provides methods to get the first artist or split them properly
class ArtistStringUtils {
  /// Common separators used between multiple artists
  static const List<String> _artistSeparators = [
    ', ',
    ' & ',
    ' and ',
    ' feat. ',
    ' ft. ',
    ' / ',
    '/',
    ' featuring ',
    ' x ',
    ' X ',
  ];

  /// Splits a combined artist string into individual artists
  ///
  /// Example:
  /// "Kanye West, Ty Dolla $ign" -> ["Kanye West", "Ty Dolla $ign"]
  /// "Drake feat. Lil Wayne" -> ["Drake", "Lil Wayne"]
  static List<String> splitArtists(String artistString) {
    if (artistString.isEmpty) return [];

    String workingString = artistString;
    List<String> artists = [];

    //try each separator
    for (final separator in _artistSeparators) {
      if (workingString.contains(separator)) {
        artists =
            workingString
                .split(separator)
                .map((a) => a.trim())
                .where((a) => a.isNotEmpty)
                .toList();
        break;
      }
    }

    //if no separator found => return whole string as single artist
    if (artists.isEmpty) {
      artists = [workingString.trim()];
    }

    return artists;
  }

  /// Gets primary (first) artist from a combined artist string
  ///
  /// Example:
  /// "Kanye West, Ty Dolla $ign" -> "Kanye West"
  /// "Drake" -> "Drake"
  static String getPrimaryArtist(String artistString) {
    if (artistString.isEmpty) return 'Unknown Artist';

    final artists = splitArtists(artistString);
    return artists.isNotEmpty ? artists.first : artistString;
  }

  /// Formats multiple artists for display
  ///
  /// Example:
  /// ["Kanye West", "Ty Dolla $ign"] -> "Kanye West, Ty Dolla $ign"
  /// ["Drake", "Lil Wayne", "Future"] -> "Drake, Lil Wayne & Future"
  static String formatArtistsForDisplay(List<String> artists) {
    if (artists.isEmpty) return 'Unknown Artist';
    if (artists.length == 1) return artists.first;
    if (artists.length == 2) return '${artists[0]} & ${artists[1]}';

    //for 3+ artists: "Artist1, Artist2 & Artist3"
    final allButLast = artists.sublist(0, artists.length - 1).join(', ');
    return '$allButLast & ${artists.last}';
  }

  //checks if artist string contains multiple artists
  static bool hasMultipleArtists(String artistString) {
    return splitArtists(artistString).length > 1;
  }

  //gets number of artists in a combined string
  static int getArtistCount(String artistString) {
    return splitArtists(artistString).length;
  }

  /// Formats artist string for search queries
  /// Returns only primary artist for better search results
  static String formatForSearch(String artistString) {
    return getPrimaryArtist(artistString);
  }

  /// Gets a short display version of artist names
  /// for long lists => "Artist1, Artist2 & 2 more"
  static String getShortDisplay(String artistString, {int maxArtists = 2}) {
    final artists = splitArtists(artistString);

    if (artists.length <= maxArtists) {
      return formatArtistsForDisplay(artists);
    }

    final displayed = artists.take(maxArtists).toList();
    final remaining = artists.length - maxArtists;

    if (displayed.length == 1) {
      return '${displayed[0]} & $remaining more';
    } else {
      return '${displayed.join(', ')} & $remaining more';
    }
  }
}
