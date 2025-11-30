// widgets/navigation_progress_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/live_navigation_service.dart';

class NavigationProgressWidget extends StatefulWidget {
  const NavigationProgressWidget({super.key});

  @override
  _NavigationProgressWidgetState createState() => _NavigationProgressWidgetState();
}

class _NavigationProgressWidgetState extends State<NavigationProgressWidget> {
  double _remainingDistance = 0;
  double _remainingTime = 0;
  double _progress = 0;
  String? _currentInstruction;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    LiveNavigationService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _remainingDistance = progress['remainingDistance'] ?? 0;
          _remainingTime = progress['remainingTime'] ?? 0;
          _progress = progress['progress'] ?? 0;
        });
      }
    });

    LiveNavigationService.stepStream.listen((step) {
      if (mounted) {
        setState(() {
          _currentInstruction = step.instruction;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!LiveNavigationService.isNavigating) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // دستورالعمل فعلی
          if (_currentInstruction != null) ...[
            Row(
              children: [
                Icon(Icons.navigation, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentInstruction!,
                    style: GoogleFonts.vazirmatn(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
          
          // اطلاعات باقی‌مانده
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.straighten,
                label: 'مسافت باقی‌مانده',
                value: '${_remainingDistance.toStringAsFixed(1)} کیلومتر',
              ),
              _buildInfoItem(
                icon: Icons.access_time,
                label: 'زمان باقی‌مانده',
                value: '${_remainingTime.toStringAsFixed(0)} دقیقه',
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // نوار پیشرفت
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          
          SizedBox(height: 4),
          
          Text(
            '${(_progress * 100).toStringAsFixed(0)}% تکمیل شده',
            style: GoogleFonts.vazirmatn(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.vazirmatn(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.vazirmatn(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}