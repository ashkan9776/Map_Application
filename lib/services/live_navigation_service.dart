// services/live_navigation_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_info.dart';
import 'voice_navigation_service.dart';

class NavigationStep {
  final String instruction;
  final LatLng location;
  final double distance;
  final String direction;
  final int stepIndex;

  NavigationStep({
    required this.instruction,
    required this.location,
    required this.distance,
    required this.direction,
    required this.stepIndex,
  });
}

class LiveNavigationService {
  static StreamSubscription<Position>? _positionSubscription;
  static RouteInfo? _currentRoute;
  static List<NavigationStep> _navigationSteps = [];
  static int _currentStepIndex = 0;
  static bool _isNavigating = false;
  static LatLng? _currentLocation;
  static double _totalDistanceRemaining = 0;
  static double _totalTimeRemaining = 0;
  
  // Stream Controllers
  static final StreamController<LatLng> _locationController = 
      StreamController<LatLng>.broadcast();
  static final StreamController<NavigationStep> _stepController = 
      StreamController<NavigationStep>.broadcast();
  static final StreamController<Map<String, dynamic>> _progressController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Streams برای UI
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

  // شروع مسیریابی
  static Future<bool> startNavigation(RouteInfo route) async {
    if (_isNavigating) {
      await stopNavigation();
    }

    try {
      _currentRoute = route;
      _isNavigating = true;
      _currentStepIndex = 0;
      
      // تبدیل مسیر به مراحل مسیریابی
      _generateNavigationSteps(route);
      
      // شروع ردیابی موقعیت
      await _startLocationTracking();
      
      // راهنمایی صوتی شروع
      await VoiceNavigationService.announceRouteStart(
        route.distance, 
        route.duration
      );
      
      print('مسیریابی شروع شد ✅');
      return true;
    } catch (e) {
      print('خطا در شروع مسیریابی: $e');
      _isNavigating = false;
      return false;
    }
  }

  // توقف مسیریابی
  static Future<void> stopNavigation() async {
    _isNavigating = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _currentRoute = null;
    _navigationSteps.clear();
    _currentStepIndex = 0;
    
    await VoiceNavigationService.speak('مسیریابی پایان یافت');
    print('مسیریابی متوقف شد ⏹️');
  }

  // تولید مراحل مسیریابی از مسیر
  static void _generateNavigationSteps(RouteInfo route) {
    _navigationSteps.clear();
    final coordinates = route.coordinates;
    
    if (coordinates.length < 2) return;

    for (int i = 0; i < coordinates.length - 1; i++) {
      final current = coordinates[i];
      final next = coordinates[i + 1];
      
      // محاسبه جهت
      final bearing = _calculateBearing(current, next);
      final direction = _bearingToDirection(bearing);
      
      // محاسبه مسافت
      const Distance distance = Distance();
      final stepDistance = distance.as(LengthUnit.Meter, current, next);
      
      String instruction = _generateInstruction(direction, stepDistance, i);
      
      _navigationSteps.add(NavigationStep(
        instruction: instruction,
        location: current,
        distance: stepDistance,
        direction: direction,
        stepIndex: i,
      ));
    }
    
    // مرحله پایانی
    _navigationSteps.add(NavigationStep(
      instruction: 'به مقصد رسیده‌اید',
      location: coordinates.last,
      distance: 0,
      direction: 'arrive',
      stepIndex: coordinates.length - 1,
    ));
    
    print('${_navigationSteps.length} مرحله مسیریابی تولید شد');
  }

  // شروع ردیابی موقعیت
  static Future<void> _startLocationTracking() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // هر 5 متر بروزرسانی
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onLocationUpdate,
      onError: (error) {
        print('خطا در ردیابی موقعیت: $error');
      },
    );
  }

  // بروزرسانی موقعیت
  static void _onLocationUpdate(Position position) {
    if (!_isNavigating) return;

    _currentLocation = LatLng(position.latitude, position.longitude);
    _locationController.add(_currentLocation!);
    
    // بررسی نزدیکی به مرحله بعدی
    _checkStepProgress();
    
    // محاسبه مسافت و زمان باقی‌مانده
    _updateRemainingDistance();
    
    print('موقعیت بروز شد: ${position.latitude}, ${position.longitude}');
  }

  // بررسی پیشرفت مراحل
  static void _checkStepProgress() {
    if (_currentStepIndex >= _navigationSteps.length - 1) {
      // رسیدن به مقصد
      _arriveAtDestination();
      return;
    }

    final currentStep = _navigationSteps[_currentStepIndex];
    final nextStepLocation = _navigationSteps[_currentStepIndex + 1].location;
    
    const Distance distance = Distance();
    final distanceToNext = distance.as(
      LengthUnit.Meter, 
      _currentLocation!, 
      nextStepLocation
    );

    // اگر به اندازه کافی نزدیک شدیم (20 متر)
    if (distanceToNext < 20) {
      _currentStepIndex++;
      
      if (_currentStepIndex < _navigationSteps.length) {
        final newStep = _navigationSteps[_currentStepIndex];
        _stepController.add(newStep);
        
        // راهنمایی صوتی
        VoiceNavigationService.announceDirection(newStep.instruction);
        
        print('مرحله جدید: ${newStep.instruction}');
      }
    }
  }

  // محاسبه مسافت باقی‌مانده
  static void _updateRemainingDistance() {
    if (_currentRoute == null || _currentLocation == null) return;

    const Distance distance = Distance();
    _totalDistanceRemaining = 0;

    // مسافت از موقعیت فعلی تا انتهای مسیر
    final remainingCoordinates = _currentRoute!.coordinates
        .skip(_currentStepIndex)
        .toList();
    
    if (remainingCoordinates.isNotEmpty) {
      // مسافت تا اولین نقطه
      _totalDistanceRemaining += distance.as(
        LengthUnit.Kilometer,
        _currentLocation!,
        remainingCoordinates.first,
      );
      
      // مسافت بین نقاط باقی‌مانده
      for (int i = 0; i < remainingCoordinates.length - 1; i++) {
        _totalDistanceRemaining += distance.as(
          LengthUnit.Kilometer,
          remainingCoordinates[i],
          remainingCoordinates[i + 1],
        );
      }
    }

    // محاسبه زمان باقی‌مانده (بر اساس سرعت متوسط)
    double avgSpeed = 50; // km/h برای رانندگی
    if (_currentRoute!.mode == TransportMode.walking) avgSpeed = 5;
    if (_currentRoute!.mode == TransportMode.cycling) avgSpeed = 20;
    
    _totalTimeRemaining = (_totalDistanceRemaining / avgSpeed) * 60; // دقیقه

    // ارسال بروزرسانی
    _progressController.add({
      'remainingDistance': _totalDistanceRemaining,
      'remainingTime': _totalTimeRemaining,
      'currentStep': _currentStepIndex,
      'totalSteps': _navigationSteps.length,
      'progress': _currentStepIndex / _navigationSteps.length,
    });
  }

  // رسیدن به مقصد
  static void _arriveAtDestination() {
    VoiceNavigationService.speak('تبریک! به مقصد رسیده‌اید');
    
    _progressController.add({
      'arrived': true,
      'totalDistance': _currentRoute?.distance ?? 0,
      'totalTime': _currentRoute?.duration ?? 0,
    });
    
    // توقف خودکار بعد از 5 ثانیه
    Future.delayed(Duration(seconds: 5), () {
      if (_isNavigating) stopNavigation();
    });
    
    print('🎉 به مقصد رسیدید!');
  }

  // محاسبه جهت بین دو نقطه
  static double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final deltaLng = (end.longitude - start.longitude) * math.pi / 180;

    final y = math.sin(deltaLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - 
              math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);

    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  // تبدیل زاویه به جهت
  static String _bearingToDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'north';
    if (bearing >= 22.5 && bearing < 67.5) return 'northeast';
    if (bearing >= 67.5 && bearing < 112.5) return 'east';
    if (bearing >= 112.5 && bearing < 157.5) return 'southeast';
    if (bearing >= 157.5 && bearing < 202.5) return 'south';
    if (bearing >= 202.5 && bearing < 247.5) return 'southwest';
    if (bearing >= 247.5 && bearing < 292.5) return 'west';
    return 'northwest';
  }

  // تولید دستورالعمل
  static String _generateInstruction(String direction, double distance, int index) {
    String directionText;
    
    switch (direction) {
      case 'north': directionText = 'شمال'; break;
      case 'south': directionText = 'جنوب'; break;
      case 'east': directionText = 'شرق'; break;
      case 'west': directionText = 'غرب'; break;
      case 'northeast': directionText = 'شمال شرق'; break;
      case 'northwest': directionText = 'شمال غرب'; break;
      case 'southeast': directionText = 'جنوب شرق'; break;
      case 'southwest': directionText = 'جنوب غرب'; break;
      default: directionText = 'جلو';
    }

    if (index == 0) {
      return 'حرکت به سمت $directionText';
    } else if (distance > 100) {
      return 'ادامه مسیر به سمت $directionText برای ${(distance/1000).toStringAsFixed(1)} کیلومتر';
    } else {
      return 'ادامه مسیر به سمت $directionText برای ${distance.toInt()} متر';
    }
  }

  // تمیزکاری منابع
  static void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
    _stepController.close();
    _progressController.close();
  }
}