
// services/voice_navigation_service.dart
import 'dart:async';
import 'dart:collection';

import 'package:flutter_tts/flutter_tts.dart';

/// Manages voice announcements for navigation using a message queue.
class VoiceNavigationService {
  // --- Configuration ---
  static const String _language = 'fa-IR';
  static const double _speechRate = 0.9;
  static const double _pitch = 1.0;

  // --- State ---
  static FlutterTts? _flutterTts;
  static bool _isEnabled = true;
  static bool _isSpeaking = false;
  static final Queue<String> _messageQueue = Queue<String>();

  // --- Announcement Phrases ---
  static const String _startPhrase = 'مسیریابی برای شما محاسبه شد.';
  static const String _reroutingPhrase = 'در حال محاسبه مسیر جدید';
  static const String _arrivalPhrase = 'شما به مقصد خود رسیده‌اید.';
  static const String _toggleOnPhrase = 'راهنمای صوتی فعال شد';
  static const String _toggleOffPhrase = 'راهنمay صوتی غیرفعال شد';
  static const String _endNavigationPhrase = 'مسیریابی پایان یافت';
  

  /// Initializes the Text-to-Speech engine and sets up listeners.
  static Future<void> initialize() async {
    if (_flutterTts != null) return; // Already initialized

    _flutterTts = FlutterTts();

    // Set engine parameters
    await _flutterTts!.setLanguage(_language);
    await _flutterTts!.setSpeechRate(_speechRate);
    await _flutterTts!.setPitch(_pitch);

    // Handler for when speech is complete
    _flutterTts!.setCompletionHandler(() {
      _isSpeaking = false;
      _processQueue(); // Check for the next message
    });

    // Handler for any error
    _flutterTts!.setErrorHandler((msg) {
      print("TTS Error: $msg");
      _isSpeaking = false;
      _processQueue(); // Attempt to continue with the next message
    });
  }
  
  /// Adds a message to the queue and processes it.
  /// This is the primary method to make an announcement.
  static Future<void> speak(String text) async {
    if (!_isEnabled || text.trim().isEmpty) {
      return;
    }
    _messageQueue.add(text);
    _processQueue();
  }

  /// Processes the next message in the queue if TTS is not currently active.
  static void _processQueue() {
    if (_isSpeaking || _messageQueue.isEmpty || _flutterTts == null || !_isEnabled) {
      return;
    }

    _isSpeaking = true;
    final message = _messageQueue.removeFirst();
    _flutterTts!.speak(message);
  }

  /// Toggles the voice navigation on or off.
  static void toggle() {
    _isEnabled = !_isEnabled;
    if (_isEnabled) {
      speak(_toggleOnPhrase);
    } else {
      // If disabling, stop current speech and clear the queue
      _messageQueue.clear();
      _flutterTts?.stop();
      _isSpeaking = false;
      // We create a new TTS instance to say the phrase, then immediately stop it.
      // This is a simple way to announce the "off" state without complex queue management.
      FlutterTts()..setLanguage(_language)..speak(_toggleOffPhrase);
    }
  }

  static bool get isEnabled => _isEnabled;
  static bool get isSpeaking => _isSpeaking;

  // --- Specific Announcement Methods ---

  /// Announces the calculated route details (distance and duration).
  static Future<void> announceRouteStart(double distanceKm, double durationMin) async {
    final String distanceText = distanceKm < 1
        ? '${(distanceKm * 1000).toStringAsFixed(0)} متر'
        : '${distanceKm.toStringAsFixed(1)} کیلومتر';
    
    final String durationText = '${durationMin.toStringAsFixed(0)} دقیقه';
    
    await speak('$_startPhrase مسیر شما $distanceText در $durationText');
  }

  /// Announces a navigation instruction (e.g., "Turn right").
  static Future<void> announceDirection(String instruction) async {
    await speak(instruction);
  }

  /// Announces that the user has arrived at the destination.
  static Future<void> announceArrival() async {
    await speak(_arrivalPhrase);
  }

  /// Announces that the route is being recalculated.
  static Future<void> announceRerouting() async {
    await speak(_reroutingPhrase);
  }

  /// Announces the end of the navigation session.
  static Future<void> announceNavigationEnd() async {
    await speak(_endNavigationPhrase);
  }

  /// Releases resources used by the TTS engine.
  static Future<void> dispose() async {
    _messageQueue.clear();
    await _flutterTts?.stop();
    _isSpeaking = false;
    // We don't nullify _flutterTts here, so it can be re-used if needed.
  }
}
