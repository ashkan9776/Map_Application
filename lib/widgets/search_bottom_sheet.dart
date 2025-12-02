// widgets/search_bottom_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/geocoding_service.dart';

// Enum to manage the various states of the search UI
enum SearchState { initial, searching, success, empty, error }

class SearchBottomSheet extends StatefulWidget {
  final Function(Place) onPlaceSelected;

  const SearchBottomSheet({super.key, required this.onPlaceSelected});

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  // --- UI Constants ---
  static const _debounceDuration = Duration(milliseconds: 500);
  static const _animationDuration = Duration(milliseconds: 350);
  static const _recentSearchesKey = 'recent_searches';
  static const _maxRecentSearches = 10;

  // --- State Variables ---
  final _controller = TextEditingController();
  Timer? _debounce;
  var _searchState = SearchState.initial;
  List<Place> _places = [];
  List<String> _recentSearches = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _controller.addListener(() {
      if (_controller.text.isEmpty) {
        setState(() {
          _searchState = SearchState.initial;
          _places.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // --- Search Logic with Debouncing ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (query.length > 2) {
        _performSearch(query);
      } else {
        setState(() {
          _places.clear();
          _searchState = SearchState.initial;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searchState = SearchState.searching);
    try {
      final places = await GeocodingService.searchPlaces(query);
      if (!mounted) return;
      setState(() {
        _places = places;
        _searchState = places.isEmpty ? SearchState.empty : SearchState.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _searchState = SearchState.error;
      });
    }
  }

  // --- UI Build Methods ---
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildSearchField(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: _animationDuration,
                  child: _buildContent(scrollController),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    switch (_searchState) {
      case SearchState.searching:
        return _buildLoadingIndicator();
      case SearchState.success:
        return _buildSearchResults(scrollController);
      case SearchState.empty:
        return _buildEmptyState();
      case SearchState.error:
        return _buildErrorState(_errorMessage);
      case SearchState.initial:
      default:
        return _buildInitialState(scrollController);
    }
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _controller,
        autofocus: true,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'جستجوی مقصد...',
          hintStyle: GoogleFonts.vazirmatn(color: Colors.grey[600]),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () => _controller.clear(),
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  // --- State-specific Widgets ---

  Widget _buildSearchResults(ScrollController scrollController) {
    return AnimationLimiter(
      child: ListView.builder(
        controller: scrollController,
        itemCount: _places.length,
        itemBuilder: (context, index) {
          final place = _places[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: _animationDuration,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: ListTile(
                  leading: const Icon(Icons.place_outlined, color: Colors.blueAccent),
                  title: Text(place.name, style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold)),
                  subtitle: Text(place.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    _onPlaceSelected(place);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitialState(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            _buildSectionHeader('جستجوهای اخیر', _clearRecentSearches, 'پاک کردن'),
            ..._recentSearches.map((search) => ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: Text(search, textDirection: TextDirection.rtl, style: GoogleFonts.vazirmatn()),
              onTap: () {
                _controller.text = search;
                _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
                _onSearchChanged(search);
              },
            )),
            const Divider(indent: 16, endIndent: 16),
          ],
          _buildSectionHeader('دسترسی سریع', null, null),
          _buildQuickAction(
            icon: Icons.map_outlined,
            title: 'انتخاب از روی نقشه',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('در حال جستجو...', style: GoogleFonts.vazirmatn()),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/animations/empty_search.json', width: 200, height: 150),
          const SizedBox(height: 16),
          Text('نتیجه‌ای یافت نشد', style: GoogleFonts.vazirmatn(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('عبارت جستجوی خود را تغییر دهید', style: GoogleFonts.vazirmatn(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/animations/error.json', width: 200, height: 150),
          const SizedBox(height: 16),
          Text('خطا در جستجو', style: GoogleFonts.vazirmatn(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(message, style: GoogleFonts.vazirmatn(color: Colors.grey[600]), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onClear, String? clearText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (onClear != null && clearText != null)
            TextButton(onPressed: onClear, child: Text(clearText, style: GoogleFonts.vazirmatn(color: Colors.redAccent))),
          const Spacer(),
          Text(title, style: GoogleFonts.vazirmatn(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildQuickAction({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, textDirection: TextDirection.rtl, style: GoogleFonts.vazirmatn()),
      onTap: onTap,
    );
  }
  
  // --- Helper Methods ---

  void _onPlaceSelected(Place place) {
    _saveRecentSearch(place.name);
    widget.onPlaceSelected(place);
    Navigator.pop(context);
  }

  // --- Recent Searches Logic (SharedPreferences) ---

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList(_recentSearchesKey) ?? [];
    if (mounted) {
      setState(() => _recentSearches = searches);
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove if it already exists to move it to the top
    _recentSearches.removeWhere((s) => s.toLowerCase() == query.toLowerCase());
    _recentSearches.insert(0, query);

    // Ensure list doesn't exceed max size
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches = _recentSearches.sublist(0, _maxRecentSearches);
    }
    
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
    if(mounted) setState(() {});
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    if (mounted) {
      setState(() => _recentSearches.clear());
    }
  }
}
