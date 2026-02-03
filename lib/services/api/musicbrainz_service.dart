import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MusicBrainzService {
  final String _baseUrl = 'https://musicbrainz.org/ws/2/';

  //fetches earliest known release date for album
  Future<String?> getFirstReleaseDate({
    required String artist,
    required String album,
  }) async {
    if (artist.isEmpty || album.isEmpty) return null;

    final query = 'release:"$album" AND artist:"$artist"';
    final url = Uri.parse(
      '${_baseUrl}release/?query=${Uri.encodeComponent(query)}&fmt=json',
    );

    try {
      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'SonoApp/1.0.9 ( business@mail.sono.wtf )',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final releases = data['releases'] as List?;

        if (releases != null && releases.isNotEmpty) {
          String? earliestDate;
          for (var release in releases) {
            final dateStr = release['date'] as String?;
            if (dateStr != null && dateStr.isNotEmpty) {
              if (earliestDate == null || dateStr.compareTo(earliestDate) < 0) {
                earliestDate = dateStr;
              }
            }
          }
          return earliestDate;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'MusicBrainzService: Error fetching release date for "$album": $e',
        );
      }
    }
    return null;
  }

  /// attempts to find a representative artist image URL for [artist].
  ///
  /// strategy:
  /// 1. search MusicBrainz for the artist and obtain the MBID
  /// 2. query the artist endpoint with 'inc=url-rels' and look for a relation
  ///    of type 'image' that contains a direct URL
  /// 3. If no direct image relation exists => look for a 'wikidata' relation
  ///    resolve the Wikidata Q-id, read the P18 (image) claim and resolve the
  ///    file name to a usable URL via the Wikimedia Commons API
  ///
  ///returns the image URL or 'null' when none could be found
  Future<String?> getArtistImageUrl({required String artist}) async {
    if (artist.isEmpty) return null;
    //use SharedPreferences cache to avoid repeated remote lookups
    final cacheKey = 'mb_artist_image_${artist.toLowerCase().trim()}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) return cached;
    } catch (e) {
      if (kDebugMode) print('MusicBrainzService: cache read failed: $e');
    }
    const int maxRetries = 3;
    const Duration baseDelay = Duration(milliseconds: 500);
    final String userAgent = 'SonoApp/1.0.9 ( mathis@mathiiis.de )';

    //helper to perform GET with retry/backoff on network errors
    Future<http.Response?> getWithRetries(Uri url) async {
      int attempt = 0;
      Duration delay = baseDelay;
      while (attempt < maxRetries) {
        attempt++;
        try {
          final resp = await http
              .get(
                url,
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': userAgent,
                },
              )
              .timeout(const Duration(seconds: 15));
          return resp;
        } on SocketException catch (e) {
          if (kDebugMode) {
            print(
              'MusicBrainzService: network error on $url (attempt $attempt): $e',
            );
          }
          if (attempt >= maxRetries) rethrow;
          await Future.delayed(delay);
          delay *= 2;
        } on http.ClientException catch (e) {
          if (kDebugMode) {
            print('MusicBrainzService: client exception on $url: $e');
          }
          if (attempt >= maxRetries) rethrow;
          await Future.delayed(delay);
          delay *= 2;
        } catch (e) {
          if (kDebugMode) {
            print('MusicBrainzService: unexpected error on $url: $e');
          }
          rethrow;
        }
      }
      return null;
    }

    try {
      //1) try MusicBrainz artist search => MBID
      final searchQuery = 'artist:"$artist"';
      final searchUrl = Uri.parse(
        '${_baseUrl}artist/?query=${Uri.encodeComponent(searchQuery)}&fmt=json&limit=1',
      );
      http.Response? searchResp;
      try {
        searchResp = await getWithRetries(searchUrl);
      } catch (e) {
        if (kDebugMode) print('MusicBrainzService: failed search requests: $e');
        searchResp = null;
      }

      String? mbid;
      if (searchResp != null && searchResp.statusCode == 200) {
        final searchData = json.decode(searchResp.body) as Map<String, dynamic>;
        final artists = searchData['artists'] as List?;
        if (artists != null && artists.isNotEmpty) {
          mbid = artists.first['id'] as String?;
        }
      }

      //2) if we have an MBID => try relations (url-rels)
      String? wikidataQ;
      if (mbid != null && mbid.isNotEmpty) {
        final relUrl = Uri.parse(
          '${_baseUrl}artist/$mbid?inc=url-rels&fmt=json',
        );
        http.Response? relResp;
        try {
          relResp = await getWithRetries(relUrl);
        } catch (e) {
          if (kDebugMode) {
            print('MusicBrainzService: failed relations request: $e');
          }
          relResp = null;
        }

        if (relResp != null && relResp.statusCode == 200) {
          final relData = json.decode(relResp.body) as Map<String, dynamic>;
          final relations = relData['relations'] as List?;
          if (relations != null) {
            for (final rel in relations) {
              try {
                final type = (rel['type'] as String?)?.toLowerCase();
                final url = rel['url'] as Map<String, dynamic>?;
                if (type == 'image' && url != null && url['resource'] != null) {
                  final imageUrl = url['resource'] as String;
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(cacheKey, imageUrl);
                  } catch (e) {
                    if (kDebugMode) {
                      print('MusicBrainzService: cache write failed: $e');
                    }
                  }
                  return imageUrl;
                }
              } catch (_) {}
            }

            for (final rel in relations) {
              try {
                final type = (rel['type'] as String?)?.toLowerCase();
                final url = rel['url'] as Map<String, dynamic>?;
                if ((type == 'wikidata' ||
                        type == 'wikipedia' ||
                        type == 'wikimedia') &&
                    url != null &&
                    url['resource'] != null) {
                  final resource = url['resource'] as String;
                  final match = RegExp(
                    r'/(Q[0-9]+)\$?',
                  ).firstMatch('$resource\$');
                  if (match != null) {
                    wikidataQ = match.group(1);
                    break;
                  }
                }
              } catch (_) {}
            }
          }
        }
      }

      //3) if we didnt get a P18 via MB relations => fallback to Wikidata search directly
      if (wikidataQ == null) {
        try {
          final wdSearchUrl = Uri.parse(
            'https://www.wikidata.org/w/api.php?action=wbsearchentities&search=${Uri.encodeComponent(artist)}&language=en&format=json&limit=1',
          );
          final wdSearchResp = await getWithRetries(wdSearchUrl);
          if (wdSearchResp != null && wdSearchResp.statusCode == 200) {
            final wdSearchData =
                json.decode(wdSearchResp.body) as Map<String, dynamic>;
            final searchResults = wdSearchData['search'] as List?;
            if (searchResults != null && searchResults.isNotEmpty) {
              wikidataQ = searchResults.first['id'] as String?;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('MusicBrainzService: Wikidata search failed: $e');
          }
        }
      }

      //4) if we have a Wikidata Q-id => fetch entity and look for P18
      if (wikidataQ != null && wikidataQ.isNotEmpty) {
        final wdUrl = Uri.parse(
          'https://www.wikidata.org/wiki/Special:EntityData/$wikidataQ.json',
        );
        try {
          final wdResp = await getWithRetries(wdUrl);
          if (wdResp != null && wdResp.statusCode == 200) {
            final wdData = json.decode(wdResp.body) as Map<String, dynamic>;
            final entities = wdData['entities'] as Map<String, dynamic>?;
            final entity = entities?[wikidataQ] as Map<String, dynamic>?;
            final claims = entity?['claims'] as Map<String, dynamic>?;
            final p18List = claims?['P18'] as List?;
            if (p18List != null && p18List.isNotEmpty) {
              final fileName =
                  p18List.first['mainsnak']?['datavalue']?['value'] as String?;
              if (fileName != null && fileName.isNotEmpty) {
                final commonsUrl = Uri.parse(
                  'https://commons.wikimedia.org/w/api.php?action=query&titles=${Uri.encodeComponent('File:$fileName')}&prop=imageinfo&iiprop=url&format=json',
                );
                final commonsResp = await getWithRetries(commonsUrl);
                if (commonsResp != null && commonsResp.statusCode == 200) {
                  final commonsData =
                      json.decode(commonsResp.body) as Map<String, dynamic>;
                  final query = commonsData['query'] as Map<String, dynamic>?;
                  final pages = query?['pages'] as Map<String, dynamic>?;
                  if (pages != null && pages.isNotEmpty) {
                    final page = pages.values.first as Map<String, dynamic>;
                    final imageinfo = page['imageinfo'] as List?;
                    if (imageinfo != null && imageinfo.isNotEmpty) {
                      final imageUrl = imageinfo.first['url'] as String?;
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(cacheKey, imageUrl);
                        } catch (e) {
                          if (kDebugMode) {
                            print('MusicBrainzService: cache write failed: $e');
                          }
                        }
                        return imageUrl;
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('MusicBrainzService: failed to fetch Wikidata entity: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'MusicBrainzService: Error fetching artist image for "$artist": $e',
        );
      }
    }

    return null;
  }
}
