// services/offline_map_service.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class OfflineMapService {
  static String? _offlineMapPath;
  static bool _isDownloading = false;

  static Future<String> get offlineMapPath async {
    if (_offlineMapPath != null) return _offlineMapPath!;

    final directory = await getApplicationDocumentsDirectory();
    _offlineMapPath = '${directory.path}/offline_maps';

    // ایجاد پوشه در صورت عدم وجود
    final offlineDir = Directory(_offlineMapPath!);
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }

    return _offlineMapPath!;
  }

  static Future<bool> downloadMapTiles({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int minZoom,
    required int maxZoom,
    Function(double)? onProgress,
  }) async {
    if (_isDownloading) return false;

    _isDownloading = true;
    final mapPath = await offlineMapPath;

    int totalTiles = 0;
    int downloadedTiles = 0;

    // محاسبه تعداد کل تایل‌ها
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final minX = _lngToTileX(minLng, zoom);
      final maxX = _lngToTileX(maxLng, zoom);
      final minY = _latToTileY(maxLat, zoom);
      final maxY = _latToTileY(minLat, zoom);

      totalTiles += (maxX - minX + 1) * (maxY - minY + 1);
    }

    try {
      for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
        final minX = _lngToTileX(minLng, zoom);
        final maxX = _lngToTileX(maxLng, zoom);
        final minY = _latToTileY(maxLat, zoom);
        final maxY = _latToTileY(minLat, zoom);

        for (int x = minX; x <= maxX; x++) {
          for (int y = minY; y <= maxY; y++) {
            final tileUrl = 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
            final filePath = '$mapPath/$zoom/$x/$y.png';

            final file = File(filePath);
            if (await file.exists()) {
              downloadedTiles++;
              continue;
            }

            await file.parent.create(recursive: true);

            try {
              final response = await http.get(Uri.parse(tileUrl));
              if (response.statusCode == 200) {
                await file.writeAsBytes(response.bodyBytes);
              }
            } catch (e) {
              print('خطا در دانلود تایل $tileUrl: $e');
            }

            downloadedTiles++;
            onProgress?.call(downloadedTiles / totalTiles);

            // تاخیر کوتاه برای جلوگیری از محدودیت نرخ
            await Future.delayed(Duration(milliseconds: 50));
          }
        }
      }

      _isDownloading = false;
      return true;
    } catch (e) {
      _isDownloading = false;
      print('خطا در دانلود نقشه آفلاین: $e');
      return false;
    }
  }

  static int _lngToTileX(double lng, int zoom) {
    return ((lng + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  static int _latToTileY(double lat, int zoom) {
    final latRad = lat * (3.141592653589793 / 180.0);
    return ((1.0 -
                (math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) /
                    3.141592653589793)) /
            2.0 *
            (1 << zoom))
        .floor();
  }

  static Future<bool> isOfflineMapAvailable(
    double lat,
    double lng,
    int zoom,
  ) async {
    final mapPath = await offlineMapPath;
    final x = _lngToTileX(lng, zoom);
    final y = _latToTileY(lat, zoom);
    final file = File('$mapPath/$zoom/$x/$y.png');
    return await file.exists();
  }

  static String getOfflineTileUrl(int zoom, int x, int y) {
    return 'file://$_offlineMapPath/$zoom/$x/$y.png';
  }

  static bool get isDownloading => _isDownloading;
}
