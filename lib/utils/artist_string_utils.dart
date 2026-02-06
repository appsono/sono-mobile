library;

/// Cleans up and formats artist names by handling multiple artists
/// Converts "Kanye West, Ty Dolla $ign" to "Kanye West, Ty Dolla $ign"
/// => provides methods to get the first artist or split them properly
class ArtistStringUtils {
  /// Common separators used between multiple artists
  static const List<String> _artistSeparators = [
    ' feat. ',
    ' ft. ',
    ' featuring ',
    ' / ',
    '/',
    ', ',
    ' & ',
    ' and ',
    ' x ',
    ' X ',
  ];

  /// Exact-match exceptions for well-known artists/bands that contain separators
  /// but should NOT be split
  static const Set<String> _exactExceptions = {
    'simon & garfunkel',
    'hall & oates',
    'earth, wind & fire',
    'emerson, lake & palmer',
    'crosby, stills, nash & young',
    'peter, paul and mary',
    'blood, sweat & tears',
    'up, bustle and out',
    'me first and the gimme gimmes',
    'hootie & the blowfish',
    'katrina and the waves',
    'kc and the sunshine band',
    'martha and the vandellas',
    'gladys knight & the pips',
    'bob seger & the silver bullet band',
    'huey lewis and the news',
    'echo & the bunnymen',
    'tom petty and the heartbreakers',
    'bob marley & the wailers',
    'sly & the family stone',
    'bruce springsteen & the e street band',
    'diana ross & the supremes',
    'smokey robinson & the miracles',
    'joan jett & the blackhearts',
    'prince & the revolution',
    'derek & the dominos',
    'sergio mendes & brasil \'66',
    'tyler, the creator',
    'panic! at the disco',
    'florence + the machine',
    'florence and the machine',
  };

  /// Checks if an artist name should be treated as an exception and NOT split
  static bool _isExceptionArtist(String artistString) {
    final lower = artistString.toLowerCase();
    return _exactExceptions.contains(lower);
  }

  /// Splits a combined artist string into individual artists
  ///
  /// Example:
  /// "Kanye West, Ty Dolla $ign" -> ["Kanye West", "Ty Dolla $ign"]
  /// "Drake feat. Lil Wayne" -> ["Drake", "Lil Wayne"]
  /// "Tyler, The Creator" -> ["Tyler, The Creator"] (exception)
  /// "Tyler, The Creator, Frank Ocean" -> ["Tyler, The Creator", "Frank Ocean"]
  static List<String> splitArtists(String artistString) {
    if (artistString.isEmpty) return [];

    //check if entire string is an exception and should not be split
    if (_isExceptionArtist(artistString)) {
      return [artistString.trim()];
    }

    //smart splitting: protect exception artists within combined strings
    //replace exception artists with placeholders before splitting
    String workingString = artistString;
    final Map<String, String> placeholders = {};
    int placeholderIndex = 0;

    //sort exceptions by length (longest first) to avoid partial matches
    final sortedExceptions =
        _exactExceptions.toList()..sort((a, b) => b.length.compareTo(a.length));

    for (final exception in sortedExceptions) {
      //case-insensitive search for exception within the string
      //escape special regex characters in the exception string
      final escapedPattern = RegExp.escape(exception);
      final regex = RegExp(escapedPattern, caseSensitive: false);
      if (regex.hasMatch(workingString)) {
        final placeholder = '___ARTIST_PLACEHOLDER_${placeholderIndex++}___';
        final match = regex.firstMatch(workingString)!;
        placeholders[placeholder] = match.group(0)!;
        workingString = workingString.replaceFirst(regex, placeholder);
      }
    }

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

    //restore placeholders with original exception artist names
    artists =
        artists.map((artist) {
          String result = artist;
          placeholders.forEach((placeholder, original) {
            result = result.replaceAll(placeholder, original);
          });
          return result.trim();
        }).toList();

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
