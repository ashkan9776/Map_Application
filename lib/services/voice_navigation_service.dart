// services/voice_navigation_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class VoiceNavigationService {
  static FlutterTts? _flutterTts;
  static bool _isEnabled = true;
  static final String _language = 'fa-IR';

  static Future<void> initialize() async {
    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage(_language);
    await _flutterTts!.setSpeechRate(0.8);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);
  }

  static Future<void> speak(String text) async {
    if (_flutterTts != null && _isEnabled) {
      await _flutterTts!.speak(text);
    }
  }

  static Future<void> announceDirection(String instruction) async {
    String persianInstruction = _translateInstruction(instruction);
    await speak(persianInstruction);
  }

  static String _translateInstruction(String instruction) {
    // ترجمه دستورالعمل‌های انگلیسی به فارسی
    instruction = instruction.toLowerCase();

    if (instruction.contains('turn right')) return 'به راست بپیچید';
    if (instruction.contains('turn left')) return 'به چپ بپیچید';
    if (instruction.contains('continue straight')) return 'مستقیم ادامه دهید';
    if (instruction.contains('arrive')) return 'به مقصد رسیده‌اید';
    if (instruction.contains('roundabout')) return 'وارد میدان شوید';

    return instruction;
  }

  static void toggle() {
    _isEnabled = !_isEnabled;
  }

  static bool get isEnabled => _isEnabled;

  static Future<void> announceRouteStart(
    double distance,
    double duration,
  ) async {
    String announcement =
        'مسیر ${distance.toStringAsFixed(1)} کیلومتری در ${duration.toStringAsFixed(0)} دقیقه آماده است';
    await speak(announcement);
  }

  static Future<void> dispose() async {
    await _flutterTts?.stop();
  }
}
