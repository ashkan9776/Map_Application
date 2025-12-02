// widgets/add_favorite_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/favorite_place.dart';

class AddFavoriteDialog extends StatefulWidget {
  final LatLng location;
  final String address;
  final FavoritePlace? existingFavorite;
  final Function(FavoritePlace) onSave;

  const AddFavoriteDialog({
    super.key,
    required this.location,
    required this.address,
    this.existingFavorite,
    required this.onSave,
  });

  @override
  State<AddFavoriteDialog> createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<AddFavoriteDialog> {
  // --- Form and State ---
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _selectedCategory;

  // --- Constants ---
  static const _defaultCategory = 'place';
  static const Map<String, (String, IconData)> _categories = {
    'place': ('عمومی', Icons.place_outlined),
    'home': ('خانه', Icons.home_rounded),
    'work': ('محل کار', Icons.work_rounded),
    'restaurant': ('رستوران', Icons.restaurant_rounded),
    'hospital': ('بیمارستان', Icons.local_hospital_rounded),
    'gas_station': ('پمپ بنزین', Icons.local_gas_station_rounded),
  };

  @override
  void initState() {
    super.initState();
    final favorite = widget.existingFavorite;
    _nameController = TextEditingController(text: favorite?.name ?? '');
    // Ensure the selected category exists in our map, otherwise use default.
    if (favorite?.category != null && _categories.containsKey(favorite!.category)) {
      _selectedCategory = favorite.category;
    } else {
      _selectedCategory = _defaultCategory;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onSave() {
    // Validate the form before proceeding.
    if (_formKey.currentState?.validate() ?? false) {
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
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingFavorite != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit_location_alt_rounded : Icons.star_border_rounded, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(
            isEditing ? 'ویرایش مکان' : 'افزودن به علاقه‌مندی‌ها',
            style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.address, style: GoogleFonts.vazirmatn(color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 24),
            _buildNameField(),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('انصراف', style: GoogleFonts.vazirmatn()),
        ),
        ElevatedButton.icon(
          onPressed: _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text('ذخیره', style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: 'نام مکان',
        hintText: 'مثلا: کافه نزدیک دانشگاه',
        prefixIcon: const Icon(Icons.label_important_outline_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'لطفاً یک نام برای این مکان وارد کنید.';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'دسته‌بندی',
        prefixIcon: const Icon(Icons.category_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _categories.entries.map((entry) {
        final id = entry.key;
        final (title, icon) = entry.value;
        return DropdownMenuItem<String>(
          value: id,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(title, style: GoogleFonts.vazirmatn()),
              const SizedBox(width: 8),
              Icon(icon, color: Colors.grey[700]),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCategory = value);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'لطفا یک دسته‌بندی انتخاب کنید.';
        }
        return null;
      },
    );
  }
}
