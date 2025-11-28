// widgets/search_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/geocoding_service.dart';

class SearchBottomSheet extends StatefulWidget {
  final Function(Place) onPlaceSelected;

  SearchBottomSheet({required this.onPlaceSelected});

  @override
  _SearchBottomSheetState createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Place> _places = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Search Field
              Padding(
                padding: EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: '...جستجوی آدرس، مکان یا نقطه جغرافیایی',
                    hintStyle: GoogleFonts.vazirmatn(),
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _places.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _searchPlaces,
                ),
              ),

              // Results
              Expanded(
                child: _isSearching
                    ? Center(child: CircularProgressIndicator())
                    : _places.isNotEmpty
                    ? _buildSearchResults(scrollController)
                    : _buildRecentSearches(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      itemCount: _places.length,
      itemBuilder: (context, index) {
        final place = _places[index];
        return AnimationConfiguration.staggeredList(
          position: index,
          duration: Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.place, color: Colors.blue),
                ),
                title: Text(
                  place.name,
                  style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  place.displayName,
                  style: GoogleFonts.vazirmatn(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  _saveRecentSearch(place.name);
                  widget.onPlaceSelected(place);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentSearches(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,

        children: [
          if (_recentSearches.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _clearRecentSearches,
                    child: Text('پاک کردن همه'),
                  ),
                  Text(
                    'جستجوهای اخیر',
                    style: GoogleFonts.vazirmatn(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),

            ...AnimationConfiguration.toStaggeredList(
              duration: Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: _recentSearches
                  .map(
                    (search) => ListTile(
                      leading: Icon(Icons.history, color: Colors.grey),
                      title: Text(search, style: GoogleFonts.vazirmatn()),
                      trailing: IconButton(
                        icon: Icon(Icons.close, size: 18),
                        onPressed: () => _removeRecentSearch(search),
                      ),
                      onTap: () {
                        _controller.text = search;
                        _searchPlaces(search);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],

          // Quick Actions
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'دسترسی سریع',
              style: GoogleFonts.vazirmatn(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          _buildQuickAction(
            icon: Icons.my_location,
            title: 'موقعیت فعلی من',
            subtitle: 'استفاده از GPS',
            onTap: _useCurrentLocation,
          ),

          _buildQuickAction(
            icon: Icons.map,
            title: 'انتخاب از روی نقشه',
            subtitle: 'لمس روی نقشه',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.green),
      ),
      title: Text(title, style: GoogleFonts.vazirmatn()),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.vazirmatn(color: Colors.grey[600]),
      ),
      onTap: onTap,
    );
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 2) {
      setState(() {
        _places.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final places = await GeocodingService.searchPlaces(query);
      setState(() {
        _places = places;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در جستجو: $e')));
    }
  }

  void _useCurrentLocation() {
    // پیاده‌سازی استفاده از موقعیت فعلی
    Navigator.pop(context);
  }

  void _loadRecentSearches() {
    // بارگذاری جستجوهای اخیر از SharedPreferences
    setState(() {
      _recentSearches = ['تهران', 'بازار', 'بیمارستان']; // نمونه
    });
  }

  void _saveRecentSearch(String search) {
    // ذخیره جستجوی جدید
    if (!_recentSearches.contains(search)) {
      _recentSearches.insert(0, search);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.take(10).toList();
      }
    }
  }

  void _removeRecentSearch(String search) {
    setState(() {
      _recentSearches.remove(search);
    });
  }

  void _clearRecentSearches() {
    setState(() {
      _recentSearches.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
