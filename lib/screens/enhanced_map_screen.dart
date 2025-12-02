// screens/enhanced_map_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map_application/models/route_info.dart';
import 'package:map_application/services/database_service.dart';
import 'package:map_application/services/enhanced_routing_service.dart';
import 'package:map_application/services/geocoding_service.dart';
import 'package:map_application/services/live_navigation_service.dart';
import 'package:map_application/services/voice_navigation_service.dart';
import 'package:map_application/widgets/add_favorite_dialog.dart';
import 'package:map_application/widgets/search_bottom_sheet.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../models/favorite_place.dart';
import '../models/route_info.dart';

class EnhancedMapScreen extends StatefulWidget {
  const EnhancedMapScreen({super.key});

  @override
  _EnhancedMapScreenState createState() => _EnhancedMapScreenState();
}

class _EnhancedMapScreenState extends State<EnhancedMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final PanelController _panelController = PanelController();

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _routeController;

  // State Variables
  LatLng? _currentLocation;
  LatLng? _destination;
  List<RouteInfo> _routes = [];
  RouteInfo? _selectedRoute;
  final List<Marker> _markers = [];
  List<FavoritePlace> _favorites = [];
  TransportMode _selectedMode = TransportMode.driving;
  bool _isNavigating = false;
  bool _isLoading = false;
  String _mapStyle = 'default';
  double _remainingDistanceKm = 0;
  double _remainingTimeMin = 0;
  double _navigationProgress = 0;
  StreamSubscription<LatLng>? _locationSubscription;
  StreamSubscription<NavigationStep>? _stepSubscription;
  StreamSubscription<Map<String, dynamic>>? _progressSubscription;

  // در EnhancedMapScreen، این متدها رو اضافه کن:

  // در initState:
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _routeController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _initializeServices();
    _setupNavigationListeners(); // اضافه کن
  }

  // Listener های مسیریابی
  void _setupNavigationListeners() {
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();
    _progressSubscription?.cancel();

    // گوش دادن به تغییرات موقعیت
    _locationSubscription =
        LiveNavigationService.locationStream.listen((location) {
      if (mounted) {
        setState(() {
          _currentLocation = location;
          _updateMarkers();
        });

        // حرکت نقشه با کاربر
        if (_isNavigating) {
          _mapController.move(location, 18);
        }
      }
    });

    // گوش دادن به تغییرات مراحل
    _stepSubscription = LiveNavigationService.stepStream.listen((step) {
      if (mounted) {
        _showStepDialog(step);
      }
    });

    // گوش دادن به پیشرفت
    _progressSubscription =
        LiveNavigationService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          if (progress.containsKey('arrived') && progress['arrived']) {
            _isNavigating = false;
            _showArrivalDialog();
            _remainingDistanceKm = 0;
            _remainingTimeMin = 0;
            _navigationProgress = 0;
          } else {
            _remainingDistanceKm =
                (progress['remainingDistance'] ?? 0).toDouble();
            _remainingTimeMin = (progress['remainingTime'] ?? 0).toDouble();
            _navigationProgress = (progress['progress'] ?? 0.0).toDouble();
          }
        });
      }
    });
  }

  // شروع مسیریابی (متد بروزرسانی شده)
  void _startNavigation() async {
    if (_selectedRoute == null) {
      _showErrorSnackBar('لطفاً ابتدا مسیری انتخاب کنید');
      return;
    }

    if (_destination == null) {
      _showErrorSnackBar('مقصدی برای مسیریابی انتخاب نشده است');
      return;
    }

    if (_currentLocation == null) {
      await _getCurrentLocation();
      if (_currentLocation == null) {
        _showErrorSnackBar('موقعیت فعلی در دسترس نیست');
        return;
      }
    }

    if (_isNavigating) {
      // توقف مسیریابی
      await LiveNavigationService.stopNavigation();
      setState(() {
        _isNavigating = false;
        // پاک کردن مسیر و مارکرها
        _routes.clear();
        _selectedRoute = null;
        _destination = null;
        _remainingDistanceKm = 0;
        _remainingTimeMin = 0;
        _navigationProgress = 0;
        _updateMarkers();
      });
      _showSuccessSnackBar('مسیریابی متوقف شد');
    } else {
      // شروع مسیریابی
      setState(() => _isLoading = true);

      final success = await LiveNavigationService.startNavigation(
        _selectedRoute!,
      );

      setState(() {
        _isLoading = false;
        _isNavigating = success;
        _navigationProgress = 0;
        _remainingDistanceKm = _selectedRoute?.distance ?? 0;
        _remainingTimeMin = _selectedRoute?.duration ?? 0;
      });

      if (success) {
        _showSuccessSnackBar('مسیریابی شروع شد');
        _panelController.close(); // بستن پنل

        // تنظیم دوربین سه‌بعدی
        _mapController.move(_currentLocation ?? _destination!, 18);
      } else {
        _showErrorSnackBar('خطا در شروع مسیریابی');
      }
    }
  }

  // نمایش دیالوگ مرحله جدید
  void _showStepDialog(NavigationStep step) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.navigation, color: Colors.blue),
            SizedBox(width: 8),
            Text('مرحله بعدی'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.instruction,
              style: GoogleFonts.vazirmatn(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (step.distance > 0) ...[
              SizedBox(height: 8),
              Text(
                'مسافت: ${step.distance > 1000 ? '${(step.distance / 1000).toStringAsFixed(1)} کیلومتر' : '${step.distance.toInt()} متر'}',
                style: GoogleFonts.vazirmatn(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('متوجه شدم'),
          ),
        ],
      ),
    );

    // بستن خودکار بعد از 3 ثانیه
    Future.delayed(Duration(seconds: 3), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  // نمایش دیالوگ رسیدن به مقصد
  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 8),
            Text('تبریک!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'با موفقیت به مقصد رسیدید',
              style: GoogleFonts.vazirmatn(fontSize: 16),
            ),
            SizedBox(height: 16),
            // نمایش آمار سفر
            if (_selectedRoute != null) ...[
              _buildStatRow(
                'مسافت کل:',
                '${_selectedRoute!.distance.toStringAsFixed(1)} کیلومتر',
              ),
              _buildStatRow(
                'زمان کل:',
                '${_selectedRoute!.duration.toStringAsFixed(0)} دقیقه',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _destination = null;
                _selectedRoute = null;
                _routes.clear();
                _remainingDistanceKm = 0;
                _remainingTimeMin = 0;
                _navigationProgress = 0;
                _updateMarkers();
              });
            },
            child: Text('پایان'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.vazirmatn()),
          Text(
            value,
            style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // در dispose:
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();
    _progressSubscription?.cancel();
    _pulseController.dispose();
    _routeController.dispose();
    LiveNavigationService.dispose(); // اضافه کن
    VoiceNavigationService.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await VoiceNavigationService.initialize();
    await _getCurrentLocation();
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SlidingUpPanel(
        controller: _panelController,
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        minHeight: 100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        panel: _buildBottomPanel(),
        body: _buildMapBody(),
      ),
      floatingActionButton: _buildSpeedDial(),
    );
  }

  Widget _buildMapBody() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation ?? LatLng(35.6892, 51.3890),
            initialZoom: 15,
            onTap: _onMapTap,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _getTileTemplate(),
              userAgentPackageName: 'com.example.navigation_app',
            ),

            // Route Polylines
            if (_routes.isNotEmpty)
              ...AnimationConfiguration.toStaggeredList(
                duration: Duration(milliseconds: 500),
                childAnimationBuilder: (widget) => SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: _routes
                    .map(
                      (route) => PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route.coordinates,
                            color: _getRouteColor(route),
                            strokeWidth: route == _selectedRoute ? 6 : 4,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),

            // Markers
            MarkerLayer(markers: _markers),

            // Current location pulse
            if (_currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation!,
                    width: 60,
                    height: 60,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(
                              0.3 * (1 - _pulseController.value),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Top UI Elements
        _buildTopUI(),

        // Loading Overlay
        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildTopUI() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar
            GlassmorphicContainer(
              width: double.infinity,
              height: 56,
              borderRadius: 28,
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderGradient: LinearGradient(
                colors: [Colors.white24, Colors.white10],
              ),
              child: TextField(
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'جستجوی مقصد...',
                  hintStyle: GoogleFonts.vazirmatn(color: Colors.black54),
                  prefixIcon: Icon(Icons.search, color: Colors.black45),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.mic, color: Colors.black45),
                    onPressed: _startVoiceSearch,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: GoogleFonts.vazirmatn(color: Colors.white),
                onTap: () => _showSearchBottomSheet(),
                readOnly: true,
              ),
            ),

            SizedBox(height: 16),

            // Transport Mode Selector
            if (!_isNavigating)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: TransportMode.values.length,
                  itemBuilder: (context, index) {
                    final mode = TransportMode.values[index];
                    final isSelected = mode == _selectedMode;

                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _selectTransportMode(mode),
                        child: GlassmorphicContainer(
                          width: 80,
                          height: 50,
                          borderRadius: 25,
                          blur: isSelected ? 30 : 15,
                          alignment: Alignment.center,
                          border: isSelected ? 2 : 1,
                          linearGradient: LinearGradient(
                            colors: isSelected
                                ? [
                                    Colors.blue.withOpacity(0.3),
                                    Colors.blue.withOpacity(0.1),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                          ),
                          borderGradient: LinearGradient(
                            colors: isSelected
                                ? [Colors.blue, Colors.blueAccent]
                                : [Colors.white24, Colors.white10],
                          ),
                          child: Icon(
                            _getModeIcon(mode),
                            color: isSelected ? Colors.black45 : Colors.black45,
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Panel Handle
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (_selectedRoute != null) ...[
            // Route Information
            _buildRouteInfo(),

            // Navigation Controls
            _buildNavigationControls(),
          ] else ...[
            // Favorites and Recent
            _buildFavoritesSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    if (_selectedRoute == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoCard(
                icon: Icons.timer,
                title: 'زمان',
                value: '${_selectedRoute!.duration.toStringAsFixed(0)} دقیقه',
                color: Colors.blue,
              ),
              _buildInfoCard(
                icon: Icons.straighten,
                title: 'مسافت',
                value: '${_selectedRoute!.distance.toStringAsFixed(1)} کیلومتر',
                color: Colors.green,
              ),
          _buildInfoCard(
            icon: _getModeIcon(_selectedRoute!.mode),
            title: 'نوع',
            value: _getModeTitle(_selectedRoute!.mode),
            color: Colors.orange,
          ),
        ],
      ),
        if (_isNavigating) ...[
          SizedBox(height: 12),
          _buildNavigationProgress(),
        ],

      if (_routes.length > 1) ...[
        SizedBox(height: 16),
        Text(
          'گزینه‌های مسیر',
              style: GoogleFonts.vazirmatn(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _routes.length,
                itemBuilder: (context, index) {
                  final route = _routes[index];
                  final isSelected = route == _selectedRoute;

                  return GestureDetector(
                    onTap: () => _selectRoute(route),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey[300]!,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            _getModeIcon(route.mode),
                            color: isSelected ? Colors.white : Colors.grey[600],
                            size: 20,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${route.duration.toStringAsFixed(0)}د',
                            style: GoogleFonts.vazirmatn(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.vazirmatn(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: GoogleFonts.vazirmatn(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationProgress() {
    final double? progressValue = _navigationProgress.isNaN
        ? null
        : _navigationProgress.clamp(0.0, 1.0).toDouble();
    final distanceText = _remainingDistanceKm >= 1
        ? '${_remainingDistanceKm.toStringAsFixed(1)} کیلومتر'
        : '${(_remainingDistanceKm * 1000).toStringAsFixed(0)} متر';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'باقی‌مانده مسیر',
              style: GoogleFonts.vazirmatn(color: Colors.grey[700]),
            ),
            Text(
              distanceText,
              style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'زمان تخمینی',
              style: GoogleFonts.vazirmatn(color: Colors.grey[700]),
            ),
            Text(
              '${_remainingTimeMin.toStringAsFixed(0)} دقیقه',
              style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationControls() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _startNavigation,
              icon: Icon(_isNavigating ? Icons.stop : Icons.navigation),
              label: Text(
                _isNavigating ? 'پایان مسیریابی' : 'شروع مسیریابی',
                style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isNavigating ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            onPressed: _addToFavorites,
            icon: Icon(Icons.favorite_border),
            style: IconButton.styleFrom(
              backgroundColor: Colors.pink.withOpacity(0.1),
              foregroundColor: Colors.pink,
              padding: EdgeInsets.all(12),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: _shareRoute,
            icon: Icon(Icons.share),
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.withOpacity(0.1),
              foregroundColor: Colors.green,
              padding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'مکان‌های مورد علاقه',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.vazirmatn(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: _favorites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/animations/empty_favorites.json',
                          width: 150,
                          height: 100,
                        ),
                        Text(
                          'هنوز مکان مورد علاقه‌ای ندارید',
                          style: GoogleFonts.vazirmatn(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final favorite = _favorites[index];
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildFavoriteItem(favorite),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteItem(FavoritePlace favorite) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getCategoryIcon(favorite.category), color: Colors.blue),
        ),
        title: Text(
          favorite.name,
          style: GoogleFonts.vazirmatn(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          favorite.address,
          style: GoogleFonts.vazirmatn(color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'navigate',
              child: ListTile(
                leading: Icon(Icons.navigation),
                title: Text('مسیریابی'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('ویرایش'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('حذف', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleFavoriteAction(value, favorite),
        ),
        onTap: () => _navigateToFavorite(favorite),
      ),
    );
  }

  Widget _buildSpeedDial() {
    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      children: [
        SpeedDialChild(
          child: Icon(Icons.my_location),
          backgroundColor: Colors.green,
          label: 'موقعیت من',
          onTap: _getCurrentLocation,
        ),
        SpeedDialChild(
          child: Icon(
            VoiceNavigationService.isEnabled
                ? Icons.volume_up
                : Icons.volume_off,
          ),
          backgroundColor: Colors.orange,
          label: VoiceNavigationService.isEnabled
              ? 'خاموش کردن صدا'
              : 'روشن کردن صدا',
          onTap: _toggleVoiceNavigation,
        ),
        SpeedDialChild(
          child: Icon(_mapStyle == 'satellite' ? Icons.map : Icons.satellite),
          backgroundColor: Colors.purple,
          label: _mapStyle == 'satellite' ? 'نقشه معمولی' : 'نقشه ماهواره‌ای',
          onTap: _toggleMapStyle,
        ),
        SpeedDialChild(
          child: Icon(Icons.offline_pin),
          backgroundColor: Colors.brown,
          label: 'نقشه آفلاین',
          onTap: _downloadOfflineMap,
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: GlassmorphicContainer(
          width: 150,
          height: 150,
          borderRadius: 20,
          blur: 20,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderGradient: LinearGradient(
            colors: [Colors.white24, Colors.white10],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/loading.json',
                width: 150,
                height: 80,
              ),
              SizedBox(height: 2),
              Text(
                'در حال محاسبه مسیر...',
                style: GoogleFonts.vazirmatn(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Methods
  String _getTileTemplate() {
    switch (_mapStyle) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  Color _getRouteColor(RouteInfo route) {
    switch (route.mode) {
      case TransportMode.driving:
        return Colors.blue;
      case TransportMode.walking:
        return Colors.green;
      case TransportMode.cycling:
        return Colors.orange;
    }
  }

  IconData _getModeIcon(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return Icons.directions_car;
      case TransportMode.walking:
        return Icons.directions_walk;
      case TransportMode.cycling:
        return Icons.directions_bike;
    }
  }

  String _getModeTitle(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return 'رانندگی';
      case TransportMode.walking:
        return 'پیاده‌روی';
      case TransportMode.cycling:
        return 'دوچرخه';
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'restaurant':
        return Icons.restaurant;
      case 'hospital':
        return Icons.local_hospital;
      case 'gas_station':
        return Icons.local_gas_station;
      default:
        return Icons.place;
    }
  }

  // Event Handlers
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _updateMarkers();
        });

        _mapController.move(_currentLocation!, 17);
      }
    } catch (e) {
      _showErrorSnackBar('خطا در دریافت موقعیت: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _destination = point;
      _updateMarkers();
      _routes.clear();
      _selectedRoute = null;
    });

    await _calculateRoute();
    _panelController.open();
  }

  Future<void> _calculateRoute() async {
    if (_currentLocation == null || _destination == null) return;

    setState(() => _isLoading = true);

    try {
      final routes = await EnhancedRoutingService.getMultipleRoutes(
        _currentLocation!,
        _destination!,
        preferredMode: _selectedMode,
      );

      if (routes.isNotEmpty) {
        final selectedRoute = routes.firstWhere(
          (route) => route.mode == _selectedMode,
          orElse: () => routes.first,
        );

        if (!mounted) return;

        setState(() {
          _routes = routes;
          _selectedRoute = selectedRoute;
          _isNavigating = false;
          _navigationProgress = 0;
          _remainingDistanceKm = selectedRoute.distance;
          _remainingTimeMin = selectedRoute.duration;
        });

        _routeController.forward();
        await VoiceNavigationService.announceRouteStart(
          selectedRoute.distance,
          selectedRoute.duration,
        );
      } else {
        if (!mounted) return;
        setState(() {
          _routes = [];
          _selectedRoute = null;
        });
        _showErrorSnackBar('مسیر معتبری یافت نشد');
      }
    } catch (e) {
      _showErrorSnackBar('خطا در محاسبه مسیر: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectTransportMode(TransportMode mode) async {
    if (_selectedMode == mode) return;

    setState(() => _selectedMode = mode);

    if (_routes.isNotEmpty) {
      final matchingRoute = _routes.firstWhere(
        (route) => route.mode == mode,
        orElse: () => _routes.first,
      );

      setState(() {
        _selectedRoute = matchingRoute;
        _remainingDistanceKm = matchingRoute.distance;
        _remainingTimeMin = matchingRoute.duration;
        _navigationProgress = 0;
      });
    }

    if (_destination != null) {
      await _calculateRoute();
    }
  }

  void _selectRoute(RouteInfo route) {
    setState(() {
      _selectedRoute = route;
      _remainingDistanceKm = route.distance;
      _remainingTimeMin = route.duration;
      _navigationProgress = 0;
    });
  }

  Future<void> _addToFavorites() async {
    if (_destination == null) return;

    final address = await GeocodingService.reverseGeocode(_destination!);

    showDialog(
      context: context,
      builder: (context) => AddFavoriteDialog(
        location: _destination!,
        address: address,
        onSave: (favorite) async {
          await DatabaseService.insertFavorite(favorite);
          await _loadFavorites();
          _showSuccessSnackBar('به مکان‌های مورد علاقه اضافه شد');
        },
      ),
    );
  }

  void _shareRoute() {
    if (_selectedRoute == null) return;

    // پیاده‌سازی اشتراک‌گذاری مسیر
    final routeData =
        'مسیر ${_selectedRoute!.distance.toStringAsFixed(1)} کیلومتری در ${_selectedRoute!.duration.toStringAsFixed(0)} دقیقه';
    // استفاده از Share package برای اشتراک‌گذاری
  }

  void _handleFavoriteAction(String action, FavoritePlace favorite) async {
    switch (action) {
      case 'navigate':
        _navigateToFavorite(favorite);
        break;
      case 'edit':
        _editFavorite(favorite);
        break;
      case 'delete':
        await _deleteFavorite(favorite);
        break;
    }
  }

  void _navigateToFavorite(FavoritePlace favorite) {
    setState(() {
      _destination = LatLng(favorite.latitude, favorite.longitude);
      _updateMarkers();
    });

    _mapController.move(_destination!, 15);
    _calculateRoute();
    _panelController.close();
  }

  Future<void> _deleteFavorite(FavoritePlace favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف مکان'),
        content: Text('آیا مطمئن هستید که می‌خواهید این مکان را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && favorite.id != null) {
      await DatabaseService.deleteFavorite(favorite.id!);
      await _loadFavorites();
      _showSuccessSnackBar('مکان حذف شد');
    }
  }

  void _editFavorite(FavoritePlace favorite) {
    showDialog(
      context: context,
      builder: (context) => AddFavoriteDialog(
        location: LatLng(favorite.latitude, favorite.longitude),
        address: favorite.address,
        existingFavorite: favorite,
        onSave: (updatedFavorite) async {
          await DatabaseService.updateFavorite(updatedFavorite);
          await _loadFavorites();
          _showSuccessSnackBar('مکان به‌روزرسانی شد');
        },
      ),
    );
  }

  void _showSearchBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchBottomSheet(
        onPlaceSelected: (place) {
          setState(() {
            _destination = place.location;
            _updateMarkers();
          });
          _mapController.move(place.location, 15);
          _calculateRoute();
        },
      ),
    );
  }

  void _startVoiceSearch() {
    // پیاده‌سازی جستجوی صوتی
    _showInfoSnackBar('جستجوی صوتی در نسخه بعدی...');
  }

  void _toggleVoiceNavigation() {
    VoiceNavigationService.toggle();
    setState(() {});

    _showInfoSnackBar(
      VoiceNavigationService.isEnabled
          ? 'مسیریابی صوتی روشن شد'
          : 'مسیریابی صوتی خاموش شد',
    );
  }

  void _toggleMapStyle() {
    setState(() {
      _mapStyle = _mapStyle == 'default' ? 'satellite' : 'default';
    });
  }

  void _downloadOfflineMap() {
    _showInfoSnackBar('دانلود نقشه آفلاین در نسخه بعدی...');
  }

  void _updateMarkers() {
    _markers.clear();

    // مارکر موقعیت فعلی
    if (_currentLocation != null) {
      if (_isNavigating) {
        // در حالت مسیریابی: فلش سه‌بعدی
        _markers.add(
          Marker(
            point: _currentLocation!,
            width: 60,
            height: 60,
            child: StreamBuilder<double>(
              stream: _getBearingStream(), // جهت حرکت
              builder: (context, snapshot) {
                final bearing = snapshot.data ?? 0.0;
                return Transform.rotate(
                  angle: bearing * (3.141592653589793 / 180), // تبدیل به رادیان
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.blue.shade600, Colors.blue.shade800],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // در حالت عادی: نقطه آبی
        _markers.add(
          Marker(
            point: _currentLocation!,
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(Icons.my_location, color: Colors.white, size: 20),
            ),
          ),
        );
      }
    }

    // مارکر مقصد (فقط اگر مسیریابی فعال نباشد)
    if (_destination != null && !_isNavigating) {
      _markers.add(
        Marker(
          point: _destination!,
          width: 60,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.location_pin, color: Colors.white, size: 30),
          ),
        ),
      );
    }
  }

  // 3. متد دریافت جهت حرکت:

  Stream<double> _getBearingStream() async* {
    double lastBearing = 0;
    LatLng? lastLocation;

    await for (final location in LiveNavigationService.locationStream) {
      if (lastLocation != null) {
        final bearing = _calculateBearing(lastLocation, location);
        if ((bearing - lastBearing).abs() > 5) {
          // فقط تغییرات بزرگتر از 5 درجه
          lastBearing = bearing;
          yield bearing;
        }
      }
      lastLocation = location;
    }
  }
  // 4. محاسبه جهت بین دو نقطه:

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (3.141592653589793 / 180);
    final lat2 = end.latitude * (3.141592653589793 / 180);
    final deltaLng =
        (end.longitude - start.longitude) * (3.141592653589793 / 180);

    final y = math.sin(deltaLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);

    final bearing = math.atan2(y, x);
    return (bearing * 180 / 3.141592653589793 + 360) % 360;
  }

  Future<void> _loadFavorites() async {
    final favorites = await DatabaseService.getFavorites();
    setState(() {
      _favorites = favorites;
    });
  }

  void _startLocationTracking() {
    // پیاده‌سازی ردیابی موقعیت برای مسیریابی
  }

  void _stopLocationTracking() {
    // توقف ردیابی موقعیت
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // در EnhancedMapScreen
  @override
  void didUpdateWidget(EnhancedMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // بهینه‌سازی‌های لازم
  }
}
