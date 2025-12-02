// widgets/navigation_progress_widget.dart
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/live_navigation_service.dart';

/// A widget that displays the current navigation progress, including the
/// next instruction, remaining distance/time, and a progress bar.
class NavigationProgressWidget extends StatelessWidget {
  const NavigationProgressWidget({super.key});

  // --- UI Constants ---
  static const _animationDuration = Duration(milliseconds: 300);
  static const _primaryColor = Colors.white;
  static const _secondaryColor = Colors.white70;
  static const _backgroundColor = Color(0x990D47A1); // Deep blue with transparency
  static const _progressColor = Colors.cyanAccent;

  /// Formats the distance to be more readable (e.g., "850 m" or "1.2 km").
  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).toStringAsFixed(0);
      return '$meters متر';
    }
    return '${distanceKm.toStringAsFixed(1)} کیلومتر';
  }

  @override
  Widget build(BuildContext context) {
    // Use a StreamBuilder to listen to the overall navigation state
    return StreamBuilder<bool>(
      // A simple stream to check the navigation status periodically or on change
      stream: Stream.periodic(const Duration(seconds: 1), (_) => LiveNavigationService.isNavigating),
      initialData: LiveNavigationService.isNavigating,
      builder: (context, snapshot) {
        final isNavigating = snapshot.data ?? false;

        // Animate the appearance and disappearance of the widget
        return AnimatedOpacity(
          duration: _animationDuration,
          opacity: isNavigating ? 1.0 : 0.0,
          child: isNavigating
              ? _buildContent()
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildContent() {
    // This StreamBuilder rebuilds the UI based on progress updates
    return StreamBuilder<Map<String, dynamic>>(
      stream: LiveNavigationService.progressStream,
      builder: (context, progressSnapshot) {
        final progressData = progressSnapshot.data ?? {};
        final remainingDistance = (progressData['remainingDistance'] ?? 0.0) as double;
        final remainingTime = (progressData['remainingTime'] ?? 0.0) as double;
        final progress = (progressData['progress'] ?? 0.0) as double;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: 150,
            borderRadius: 20,
            blur: 15,
            alignment: Alignment.center,
            border: 2,
            linearGradient: LinearGradient(
              colors: [
                _backgroundColor.withOpacity(0.4),
                _backgroundColor.withOpacity(0.2),
              ],
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight,
            ),
            borderGradient: LinearGradient(
              colors: [
                _primaryColor.withOpacity(0.3),
                _primaryColor.withOpacity(0.1),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInstructionView(),
                  const SizedBox(height: 12),
                  _buildStatsRow(remainingDistance, remainingTime),
                  const SizedBox(height: 10),
                  _buildProgressBar(progress),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the view for the current navigation instruction.
  Widget _buildInstructionView() {
    return StreamBuilder<NavigationStep>(
      stream: LiveNavigationService.stepStream,
      builder: (context, stepSnapshot) {
        final instruction = stepSnapshot.data?.instruction ?? 'در حال آماده‌سازی مسیر...';
        return Row(
          children: [
            const Icon(Icons.navigation_rounded, color: _primaryColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: _animationDuration,
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: Text(
                  instruction,
                  key: ValueKey<String>(instruction), // Important for AnimatedSwitcher
                  style: GoogleFonts.vazirmatn(
                    color: _primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the row displaying remaining distance and time.
  Widget _buildStatsRow(double remainingDistance, double remainingTime) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildInfoItem(
          icon: Icons.straighten_rounded,
          label: 'باقی‌مانده',
          value: _formatDistance(remainingDistance),
        ),
        _buildInfoItem(
          icon: Icons.access_time_filled_rounded,
          label: 'زمان تخمینی',
          value: '${remainingTime.toStringAsFixed(0)} دقیقه',
        ),
      ],
    );
  }

  /// Builds a single stat item with an icon, label, and animated value.
  Widget _buildInfoItem({required IconData icon, required String label, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _secondaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.vazirmatn(color: _secondaryColor, fontSize: 11),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: _animationDuration,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: Text(
            value,
            key: ValueKey<String>(value), // Key is crucial for animation
            style: GoogleFonts.vazirmatn(
              color: _primaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the progress bar and the percentage text.
  Widget _buildProgressBar(double progress) {
    final progressPercent = (progress.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: LinearProgressIndicator(
            value: progress.isNaN ? 0.0 : progress,
            backgroundColor: Colors.black.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(_progressColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$progressPercent% تکمیل شده',
          style: GoogleFonts.vazirmatn(color: _secondaryColor, fontSize: 10),
        ),
      ],
    );
  }
}
