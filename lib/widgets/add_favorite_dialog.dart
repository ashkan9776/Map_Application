// widgets/add_favorite_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/favorite_place.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class AddFavoriteDialog extends StatefulWidget {
  final LatLng location;
  final String address;
  final FavoritePlace? existingFavorite;
  final Function(FavoritePlace) onSave;

  const AddFavoriteDialog({super.key, 
    required this.location,
    required this.address,
    this.existingFavorite,
    required this.onSave,
  });

  @override
  _AddFavoriteDialogState createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<AddFavoriteDialog> {
  late TextEditingController _nameController;
  String _selectedCategory = 'general';
  
  final List<Map<String, dynamic>> _categories = [
    {'id': 'home', 'title': 'خانه', 'icon': Icons.home},
    {'id': 'work', 'title': 'محل کار', 'icon': Icons.work},
    {'id': 'restaurant', 'title': 'رستوران', 'icon': Icons.restaurant},
    {'id': 'hospital', 'title': 'بیمارستان', 'icon': Icons.local_hospital},
    {'id': 'gas_station', 'title': 'پمپ بنزین', 'icon': Icons.local_gas_station},
    {'id': 'general', 'title': 'عمومی', 'icon': Icons.place},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingFavorite?.name ?? ''
    );
    _selectedCategory = widget.existingFavorite?.category ?? 'general';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existingFavorite != null 
                ? 'ویرایش مکان' 
                : 'افزودن به علاقه‌مندی‌ها',
              style: GoogleFonts.vazirmatn(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 20),
            
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'نام مکان',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            
            SizedBox(height: 16),
            
            Text(
              'دسته‌بندی:',
              style: GoogleFonts.vazirmatn(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = category['id'] == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = category['id'];
                  }),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          category['icon'],
                          size: 18,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          category['title'],
                          style: GoogleFonts.vazirmatn(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontWeight: isSelected 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('انصراف'),
                ),
                ElevatedButton(
                  onPressed: _saveFavorite,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('ذخیره'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveFavorite() {
    if (_nameController.text.trim().isEmpty) return;
    
    final favorite = FavoritePlace(
      id: widget.existingFavorite?.id,
      name: _nameController.text.trim(),
      address: widget.address,
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
      createdAt: widget.existingFavorite?.createdAt ?? DateTime.now(),
      category: _selectedCategory,
    );
    
    widget.onSave(favorite);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
