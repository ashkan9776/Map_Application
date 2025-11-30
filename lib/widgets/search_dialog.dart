// widgets/search_dialog.dart
import 'package:flutter/material.dart';
import '../services/geocoding_service.dart';

class SearchDialog extends StatefulWidget {
  final Function(Place) onPlaceSelected;

  const SearchDialog({super.key, required this.onPlaceSelected});

  @override
  _SearchDialogState createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _controller = TextEditingController();
  List<Place> _places = [];
  bool _isSearching = false;

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() => _places.clear());
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در جستجو: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: 400,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'جستجوی مکان...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _searchPlaces,
            ),
            
            SizedBox(height: 16),
            
            Expanded(
              child: _isSearching
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _places.length,
                      itemBuilder: (context, index) {
                        final place = _places[index];
                        return ListTile(
                          title: Text(place.name),
                          subtitle: Text(place.displayName),
                          onTap: () {
                            widget.onPlaceSelected(place);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}