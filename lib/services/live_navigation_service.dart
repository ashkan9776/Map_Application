// services/live_navigation_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_info.dart';
import 'voice_navigation_service.dart';

// مدل داده برای یک مرحله از مسیریابی
class NavigationStep {
  final String instruction;
  final LatLng location;
  final double distance; // فاصله تا مرحله بعدی
  final int stepIndex;

  NavigationStep({
    required this.instruction,
    required this.location,
    required this.distance,
    required this.stepIndex,
  });
}

// مقادیر ثابت برای تنظیمات سرویس
class _Constants {
  static const double stepProximityThreshold = 25.0; // متر - فاصله برای رفتن به مرحله بعد
  static const int locationUpdateDistanceFilter = 5; // متر - حداقل جابجایی برای آپدیت
  static const int arrivalStopDelaySeconds = 5; // ثانیه - تاخیر برای توقف خودکار پس از رسیدن
  static const double minorSegmentThreshold = 15.0; // متر - مراحل کوتاه‌تر از این ادغام می‌شوند

  // سرعت‌های متوسط برای تخمین زمان
  static const double avgSpeedDriving = 45.0; // km/h
  static const double avgSpeedWalking = 5.0; // km/h
  static const double avgSpeedCycling = 18.0; // km/h

  // آستانه زاویه برای تشخیص نوع پیچ (درجه)
  static const double straightAngleThreshold = 20.0;
  static const double slightTurnAngleThreshold = 45.0;
  static const double normalTurnAngleThreshold = 100.0;
}


class LiveNavigationService {
  static StreamSubscription<Position>? _positionSubscription;
  static RouteInfo? _currentRoute;
  static final List<NavigationStep> _navigationSteps = [];
  static int _currentStepIndex = 0;
  static bool _isNavigating = false;
  static LatLng? _currentLocation;
  
  // Stream Controllers
  static final _locationController = StreamController<LatLng>.broadcast();
  static final _stepController = StreamController<NavigationStep>.broadcast();
  static final _progressController = StreamController<Map<String, dynamic>>.broadcast();

  // Streams برای استفاده در UI
  static Stream<LatLng> get locationStream => _locationController.stream;
  static Stream<NavigationStep> get stepStream => _stepController.stream;
  static Stream<Map<String, dynamic>> get progressStream => _progressController.stream;

  // Getters
  static bool get isNavigating => _isNavigating;
  static RouteInfo? get currentRoute => _currentRoute;
  static NavigationStep? get currentStep => 
      _currentStepIndex < _navigationSteps.length 
          ? _navigationSteps[_currentStepIndex] 
          : null;

  /// شروع فرآیند مسیریابی با یک مسیر مشخص
  static Future<bool> startNavigation(RouteInfo route) async {
    if (_isNavigating) await stopNavigation();

    try {
      _currentRoute = route;
      _isNavigating = true;
      _currentStepIndex = 0;
      
      _generateNavigationSteps(route);
      
      await _startLocationTracking();
      
      if (_navigationSteps.isNotEmpty) {
        final firstStep = _navigationSteps.first;
        _stepController.add(firstStep);
        await VoiceNavigationService.announceDirection(firstStep.instruction);
      } else {
        await VoiceNavigationService.announceRouteStart(route.distance, route.duration);
      }
      
      print('مسیریابی شروع شد ✅');
      return true;
    } catch (e) {
      print('خطا در شروع مسیریابی: $e');
      _isNavigating = false;
      return false;
    }
  }

  /// توقف کامل فرآیند مسیریابی
  static Future<void> stopNavigation() async {
    if (!_isNavigating) return;
    _isNavigating = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _currentRoute = null;
    _navigationSteps.clear();
    _currentStepIndex = 0;
    
    await VoiceNavigationService.speak('مسیریابی پایان یافت');
    print('مسیریابی متوقف شد ⏹️');
  }

  /// تولید مراحل هوشمند مسیریابی از روی نقاط مسیر
  static void _generateNavigationSteps(RouteInfo route) {
    _navigationSteps.clear();
    final coordinates = route.coordinates;
    
    if (coordinates.length < 2) return;

    // 1. دستورالعمل اولیه (شروع حرکت)
    final bearing = _calculateBearing(coordinates[0], coordinates[1]);
    final direction = _bearingToDirection(bearing);
    _navigationSteps.add(NavigationStep(
      instruction: 'حرکت به سمت $direction را آغاز کنید',
      location: coordinates[0],
      distance: 0, // فاصله این مرحله تا خودش صفر است
      stepIndex: 0,
    ));

    // 2. تولید مراحل میانی با تشخیص پیچ
    for (int i = 1; i < coordinates.length - 1; i++) {
      final prevPoint = coordinates[i - 1];
      final currentPoint = coordinates[i];
      final nextPoint = coordinates[i + 1];
      
      final distanceToNext = const Distance().as(LengthUnit.Meter, currentPoint, nextPoint);
      
      // از نقاط خیلی نزدیک برای جلوگیری از دستورات اضافی صرف نظر کن
      if (distanceToNext < _Constants.minorSegmentThreshold) continue;

      final prevBearing = _calculateBearing(prevPoint, currentPoint);
      final nextBearing = _calculateBearing(currentPoint, nextPoint);
      
      String turnInstruction = _getTurnInstruction(prevBearing, nextBearing);
      
      // اگر دستور "مستقیم" بود، آن را با مرحله قبلی ادغام کن
      final lastStep = _navigationSteps.last;
      if (turnInstruction == "مستقیم ادامه دهید" && lastStep.instruction.contains("مستقیم")) {
        final mergedInstruction = 'برای ${((lastStep.distance + distanceToNext) / 1000).toStringAsFixed(1)} کیلومتر در مسیر مستقیم بمانید';
        _navigationSteps.last = NavigationStep(
          instruction: mergedInstruction,
          location: lastStep.location,
          distance: lastStep.distance + distanceToNext,
          stepIndex: lastStep.stepIndex,
        );
      } else {
        _navigationSteps.add(NavigationStep(
          instruction: turnInstruction,
          location: currentPoint,
          distance: distanceToNext,
          stepIndex: _navigationSteps.length,
        ));
      }
    }
    
    // 3. مرحله پایانی (رسیدن به مقصد)
    _navigationSteps.add(NavigationStep(
      instruction: 'شما به مقصد رسیده‌اید',
      location: coordinates.last,
      distance: 0,
      stepIndex: _navigationSteps.length,
    ));
    
    print('${_navigationSteps.length} مرحله مسیریابی هوشمند تولید شد');
  }

  /// شروع ردیابی موقعیت مکانی کاربر
  static Future<void> _startLocationTracking() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _Constants.locationUpdateDistanceFilter,
    );

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onLocationUpdate,
      onError: (error) => print('خطا در ردیابی موقعیت: $error'),
    );
  }

  /// با هر بروزرسانی موقعیت، این متد فراخوانی می‌شود
  static void _onLocationUpdate(Position position) {
    if (!_isNavigating) return;

    _currentLocation = LatLng(position.latitude, position.longitude);
    _locationController.add(_currentLocation!);
    
    _checkStepProgress();
    _updateRouteProgress();
    
    print('موقعیت بروز شد: ${position.latitude}, ${position.longitude}');
  }

  /// بررسی می‌کند که آیا کاربر به مرحله بعدی نزدیک شده است یا خیر
  static void _checkStepProgress() {
    if (_currentStepIndex >= _navigationSteps.length - 1) {
      _arriveAtDestination();
      return;
    }

    final nextStepLocation = _navigationSteps[_currentStepIndex + 1].location;
    final distanceToNextStep = const Distance().as(
      LengthUnit.Meter, 
      _currentLocation!, 
      nextStepLocation
    );

    // اگر به اندازه کافی به نقطه مرحله بعدی نزدیک شدیم
    if (distanceToNextStep < _Constants.stepProximityThreshold) {
      _currentStepIndex++;
      final newStep = _navigationSteps[_currentStepIndex];
      _stepController.add(newStep);
      
      // اعلام دستورالعمل صوتی مرحله جدید
      VoiceNavigationService.announceDirection(newStep.instruction);
      
      print('مرحله جدید: ${newStep.instruction}');
      
      if(newStep.instruction.contains("مقصد")) {
        _arriveAtDestination();
      }
    }
  }

  /// محاسبه و بروزرسانی مسافت و زمان باقی‌مانده
  static void _updateRouteProgress() {
    if (_currentRoute == null || _currentLocation == null) return;

    const distanceCalculator = Distance();
    double remainingDistance = 0;

    // مسافت از موقعیت فعلی تا شروع مرحله بعدی
    final nextStepLocation = _navigationSteps[_currentStepIndex + 1].location;
    remainingDistance += distanceCalculator.as(
      LengthUnit.Kilometer,
      _currentLocation!,
      nextStepLocation,
    );
      
    // جمع مسافت تمام مراحل باقی‌مانده
    for (int i = _currentStepIndex + 1; i < _navigationSteps.length -1; i++) {
      remainingDistance += _navigationSteps[i].distance / 1000; // to km
    }

    // محاسبه زمان باقی‌مانده بر اساس سرعت متوسط
    double avgSpeed;
    switch (_currentRoute!.mode) {
      case TransportMode.walking: avgSpeed = _Constants.avgSpeedWalking; break;
      case TransportMode.cycling: avgSpeed = _Constants.avgSpeedCycling; break;
      default: avgSpeed = _Constants.avgSpeedDriving;
    }
    
    final remainingTime = (remainingDistance / avgSpeed) * 60; // to minutes

    // محاسبه درصد پیشرفت مسیر
    final totalDistance = _currentRoute!.distance;
    final progress = totalDistance > 0
        ? (1.0 - (remainingDistance / totalDistance)).clamp(0.0, 1.0)
        : 0.0;

    _progressController.add({
      'remainingDistance': remainingDistance,
      'remainingTime': remainingTime,
      'progress': progress,
    });
  }

  /// رویداد رسیدن به مقصد نهایی
  static void _arriveAtDestination() {
    VoiceNavigationService.speak('تبریک! به مقصد رسیده‌اید');
    
    _progressController.add({ 'arrived': true });
    
    // توقف خودکار مسیریابی پس از چند ثانیه
    Future.delayed(const Duration(seconds: _Constants.arrivalStopDelaySeconds), () {
      if (_isNavigating) stopNavigation();
    });
    
    print('🎉 به مقصد رسیدید!');
  }
  
  /// یک دستورالعمل قابل فهم بر اساس زاویه پیچ برمی‌گرداند
  static String _getTurnInstruction(double prevBearing, double nextBearing) {
    double angle = nextBearing - prevBearing;
    if (angle > 180) angle -= 360;
    if (angle < -180) angle += 360;

    if (angle.abs() <= _Constants.straightAngleThreshold) {
      return "مستقیم ادامه دهید";
    } else if (angle > 0) { // پیچ به راست
      if (angle < _Constants.slightTurnAngleThreshold) return "کمی به راست بپیچید";
      if (angle < _Constants.normalTurnAngleThreshold) return "به راست بپیچید";
      return "گردش به راست شدید انجام دهید";
    } else { // پیچ به چپ
      if (angle.abs() < _Constants.slightTurnAngleThreshold) return "کمی به چپ بپیچید";
      if (angle.abs() < _Constants.normalTurnAngleThreshold) return "به چپ بپیچید";
      return "گردش به چپ شدید انجام دهید";
    }
  }

  /// محاسبه زاویه (Bearing) بین دو نقطه جغرافیایی
  static double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitudeInRad;
    final lon1 = start.longitudeInRad;
    final lat2 = end.latitudeInRad;
    final lon2 = end.longitudeInRad;
    
    final y = math.sin(lon2 - lon1) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
              math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1);
    
    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360; // to degrees
  }

  /// تبدیل زاویه به یک جهت متنی (شمال، جنوب، ...)
  static String _bearingToDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'شمال';
    if (bearing < 67.5) return 'شمال شرقی';
    if (bearing < 112.5) return 'شرق';
    if (bearing < 157.5) return 'جنوب شرقی';
    if (bearing < 202.5) return 'جنوب';
    if (bearing < 247.5) return 'جنوب غربی';
    if (bearing < 292.5) return 'غرب';
    return 'شمال غربی';
  }

  /// آزادسازی منابع و بستن StreamController ها
  static void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
    _stepController.close();
    _progressController.close();
  }
}
