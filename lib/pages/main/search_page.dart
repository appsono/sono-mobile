import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sono/models/search/search_item.dart';
import 'package:sono/models/search/search_filter_options.dart';
import 'package:sono/models/search/recent_search_model.dart';
import 'package:sono/services/search/search_service.dart';
import 'package:sono/services/search/recent_searches_service.dart';
import 'package:sono/services/search/search_cache_service.dart';
import 'package:sono/widgets/search/search_idle_state.dart';
import 'package:sono/widgets/search/search_results_view.dart';
import 'package:sono/widgets/search/pages/filtered_search_results_page.dart';
import 'package:sono/widgets/global/page_header.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/global/content_constraint.dart';

class SearchPage extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final bool hasPermission;
  final VoidCallback onRequestPermission;
  final Map<String, dynamic>? currentUser;
  final bool isLoggedIn;

  const SearchPage({
    super.key,
    this.onMenuTap,
    required this.hasPermission,
    required this.onRequestPermission,
    this.currentUser,
    this.isLoggedIn = false,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with
        AutomaticKeepAliveClientMixin<SearchPage>,
        SingleTickerProviderStateMixin {
  //keep alive once initial data is loaded to avoid reinitialization
  @override
  bool get wantKeepAlive => !_isLoadingInitialData;

  final OnAudioQuery _audioQuery = OnAudioQuery();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  final SearchService _searchService = SearchService();
  final RecentSearchesService _recentSearchesService = RecentSearchesService();
  final SearchCacheService _searchCacheService = SearchCacheService();

  late TabController _tabController;

  bool _isLoadingInitialData = true;
  bool _isSearching = false;

  //search state
  String _query = "";
  final SearchFilterOptions _filterOptions = const SearchFilterOptions();

  //data
  List<SongModel> _allSongs = [];
  List<AlbumModel> _allAlbums = [];
  List<ArtistModel> _allArtists = [];

  List<SearchItem> _searchResults = [];
  Map<SearchItemType, List<SearchItem>> _groupedResults = {};

  List<RecentSearch> _recentSearches = [];

  //pagination
  final Map<SearchItemType, int> _loadedCounts = {
    SearchItemType.song: 30,
    SearchItemType.album: 30,
    SearchItemType.artist: 30,
  };
  final int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    if (widget.hasPermission) {
      _loadInitialData();
    }

    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasPermission && !oldWidget.hasPermission) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _tabController.dispose();

    //clear large data structures => help garbage collection
    _allSongs.clear();
    _allAlbums.clear();
    _allArtists.clear();
    _searchResults.clear();
    _groupedResults.clear();
    _recentSearches.clear();
    _loadedCounts.clear();

    //clear cache if query empty
    if (_query.isEmpty) {
      _searchCacheService.clear();
    }

    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!widget.hasPermission) return;

    setState(() => _isLoadingInitialData = true);

    try {
      //use AudioFilterUtils, get filtered data
      _allAlbums = await AudioFilterUtils.getFilteredAlbums(_audioQuery);
      _allArtists = await AudioFilterUtils.getFilteredArtists(_audioQuery);
      _allSongs = await AudioFilterUtils.getFilteredSongs(
        _audioQuery,
        sortType: SongSortType.TITLE,
      );

      if (mounted) {
        setState(() => _isLoadingInitialData = false);
      }
    } catch (e) {
      debugPrint('SearchPage: Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
      }
    }
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _recentSearchesService.getRecentSearches();
    if (mounted) {
      setState(() => _recentSearches = searches);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final newQuery = _searchController.text.trim();
      if (_query != newQuery) {
        setState(() => _query = newQuery);
        if (_query.isNotEmpty) {
          _performSearch();
        } else {
          setState(() {
            _searchResults = [];
            _groupedResults = {};
          });
        }
        //update keep-alive state based on whether theres an active search
        updateKeepAlive();
      }
    });
  }

  Future<void> _performSearch() async {
    if (!mounted || _query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      //check cache first
      final cached = _searchCacheService.get(_query);
      if (cached != null) {
        _updateSearchResults(cached);
        setState(() => _isSearching = false);
        return;
      }

      //perform search in isolate
      final results = await _searchService.performSearch(
        query: _query,
        songs: _allSongs,
        albums: _allAlbums,
        artists: _allArtists,
        filterOptions: _filterOptions,
      );

      //cache results
      _searchCacheService.put(_query, results);

      _updateSearchResults(results);
    } catch (e, stackTrace) {
      debugPrint('SearchPage: Search failed: $e\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _updateSearchResults(List<SearchItem> results) {
    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _groupedResults = SearchService.groupResultsByType(results);

      //reset pagination counts
      _loadedCounts[SearchItemType.song] = _pageSize;
      _loadedCounts[SearchItemType.album] = _pageSize;
      _loadedCounts[SearchItemType.artist] = _pageSize;
    });
  }

  void _onRecentSearchTap(RecentSearch search) {
    _searchController.text = search.query;
    _searchFocusNode.unfocus();
  }

  Future<void> _onRecentSearchDelete(RecentSearch search) async {
    await _recentSearchesService.removeRecentSearch(search.query);
    await _loadRecentSearches();
  }

  Future<void> _onClearAllRecentSearches() async {
    await _recentSearchesService.clearRecentSearches();
    await _loadRecentSearches();
  }

  void _onLoadMore(SearchItemType type) {
    setState(() {
      final currentCount = _loadedCounts[type] ?? _pageSize;
      _loadedCounts[type] = currentCount + _pageSize;
    });
  }

  void _onViewAll(SearchItemType type) {
    final typeResults = _groupedResults[type] ?? [];
    if (typeResults.isEmpty) return;

    _saveSearchToRecent();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FilteredSearchResultsPage(
              type: type,
              results: typeResults,
              query: _query,
            ),
      ),
    );
  }

  Future<void> _saveSearchToRecent() async {
    if (_query.trim().isEmpty) return;

    final search = RecentSearch(
      query: _query.trim(),
      timestamp: DateTime.now(),
      resultCount: _searchResults.length,
    );

    await _recentSearchesService.addRecentSearch(search);
    await _loadRecentSearches();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); //required for AutomaticKeepAliveClientMixin (!)

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Column(
          children: [
            GlobalPageHeader(
              pageTitle: 'Search',
              onMenuTap: widget.onMenuTap,
              currentUser: widget.currentUser,
              isLoggedIn: widget.isLoggedIn,
            ),

            _buildSearchInput(),

            if (_query.isNotEmpty && _searchResults.isNotEmpty) ...[
              _buildTabBar(),
              const SizedBox(height: AppTheme.spacingMd),
            ],

            Expanded(child: ContentConstraint(child: _buildContent())),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingMd,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppTheme.font,
          fontFamily: 'VarelaRound',
        ),
        decoration: InputDecoration(
          hintText: 'Search songs, albums, artists...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: AppTheme.font,
            fontFamily: 'VarelaRound',
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          suffixIcon:
              _query.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                    },
                  )
                  : null,
          filled: true,
          fillColor: AppTheme.surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing,
            vertical: AppTheme.spacingMd,
          ),
        ),
        onSubmitted: (_) {
          if (_query.isNotEmpty) {
            _saveSearchToRecent();
            _searchFocusNode.unfocus();
          }
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.brandPink,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
        labelStyle: const TextStyle(
          fontSize: AppTheme.fontSm,
          fontWeight: FontWeight.w600,
          fontFamily: 'VarelaRound',
        ),
        tabs: [
          Tab(text: 'All (${_searchResults.length})'),
          Tab(
            text:
                'Songs (${_groupedResults[SearchItemType.song]?.length ?? 0})',
          ),
          Tab(
            text:
                'Albums (${_groupedResults[SearchItemType.album]?.length ?? 0})',
          ),
          Tab(
            text:
                'Artists (${_groupedResults[SearchItemType.artist]?.length ?? 0})',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    //no permission
    if (!widget.hasPermission) {
      return _buildNoPermissionState();
    }

    //loading initial data
    if (_isLoadingInitialData) {
      return _buildLoadingState();
    }

    //idle state => no query
    if (_query.isEmpty) {
      return SearchIdleState(
        recentSearches: _recentSearches,
        onRecentSearchTap: _onRecentSearchTap,
        onRecentSearchDelete: _onRecentSearchDelete,
        onClearAll: _onClearAllRecentSearches,
      );
    }

    //searching
    if (_isSearching) {
      return _buildSearchingState();
    }

    //results
    return TabBarView(
      controller: _tabController,
      children: [
        SearchResultsView(
          results: _searchResults,
          groupedResults: _groupedResults,
          currentTab: 0,
          loadedCounts: _loadedCounts,
          pageSize: _pageSize,
          onLoadMore: _onLoadMore,
          onViewAll: _onViewAll,
        ),

        SearchResultsView(
          results: _groupedResults[SearchItemType.song] ?? [],
          groupedResults: _groupedResults,
          currentTab: 1,
          loadedCounts: _loadedCounts,
          pageSize: _pageSize,
          onLoadMore: _onLoadMore,
        ),

        SearchResultsView(
          results: _groupedResults[SearchItemType.album] ?? [],
          groupedResults: _groupedResults,
          currentTab: 2,
          loadedCounts: _loadedCounts,
          pageSize: _pageSize,
          onLoadMore: _onLoadMore,
        ),

        SearchResultsView(
          results: _groupedResults[SearchItemType.artist] ?? [],
          groupedResults: _groupedResults,
          currentTab: 3,
          loadedCounts: _loadedCounts,
          pageSize: _pageSize,
          onLoadMore: _onLoadMore,
        ),
      ],
    );
  }

  Widget _buildNoPermissionState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing2xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'Permission Required',
              style: TextStyle(
                fontSize: AppTheme.fontTitle,
                fontWeight: FontWeight.w600,
                fontFamily: 'VarelaRound',
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Allow Sono to access your music library to enable search',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                color: Colors.white.withValues(alpha: 0.5),
                fontFamily: 'VarelaRound',
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),
            ElevatedButton(
              onPressed: widget.onRequestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXl,
                  vertical: AppTheme.spacingMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
              child: const Text(
                'Grant Permission',
                style: TextStyle(
                  fontSize: AppTheme.fontBody,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'VarelaRound',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: Shimmer.fromColors(
            baseColor: AppTheme.surfaceDark,
            highlightColor: AppTheme.elevatedSurfaceDark,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandPink),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'Searching...',
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: Colors.white.withValues(alpha: 0.7),
              fontFamily: 'VarelaRound',
            ),
          ),
        ],
      ),
    );
  }
}
