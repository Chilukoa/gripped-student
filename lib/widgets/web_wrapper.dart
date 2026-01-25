import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// A responsive wrapper widget that adjusts the app content
/// to work well across different screen sizes on web.
class WebWrapper extends StatelessWidget {
  final Widget child;

  const WebWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Pass through - let the app handle its own responsive design
    // Each screen should use ResponsiveSize helpers for truly adaptive layouts
    return child;
  }
}

/// Helper to get responsive sizing based on screen width
class ResponsiveSize {
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Returns true if the screen is considered "mobile" width (< 600px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Returns true if the screen is considered "tablet" width (600-1200px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  /// Returns true if the screen is considered "desktop" width (>= 1200px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  /// Get a responsive value based on screen size
  static T responsive<T>(BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (isTablet(context)) {
      return tablet ?? mobile;
    }
    return mobile;
  }

  /// Get responsive font size - scales based on screen width but with limits
  static double fontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    if (width > 600) {
      // On larger screens, don't scale up as much
      return baseFontSize;
    }
    // On smaller screens, scale proportionally
    return baseFontSize * (width / 400).clamp(0.8, 1.2);
  }

  /// Get responsive spacing
  static double spacing(BuildContext context, double baseSpacing) {
    final width = MediaQuery.of(context).size.width;
    if (width > 600) {
      return baseSpacing;
    }
    return baseSpacing * (width / 400).clamp(0.8, 1.2);
  }
}
