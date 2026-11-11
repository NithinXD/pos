import 'package:flutter/material.dart';

/// Responsive utility for POS screen sizing, tablet/mobile detection,
/// and modern fine-grained MediaQuery selectors (sizeOf, viewInsetsOf, paddingOf).
class Responsive {
  /// Mobile breakpoint (< 600px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  /// Tablet portrait / compact tablet (600px - 899px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 && width < 900;
  }

  /// Tablet landscape / POS terminal / Desktop (>= 900px)
  static bool isWideTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  /// Whether current orientation is landscape
  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Screen Width using modern selective MediaQuery
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Screen Height using modern selective MediaQuery
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Bottom Inset (Software keyboard height)
  static double keyboardHeight(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom;

  /// System Bottom Padding (Gesture / Navigation bar)
  static double bottomPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  /// System Top Padding (Status bar / camera notch)
  static double topPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  /// Dynamic column count for tables/cards grid
  static int tableGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1150) return 5;
    if (w >= 850) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  /// Dynamic column count for menu items grid
  static int menuGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1200) return 3;
    if (w >= 700) return 2;
    return 1;
  }
}
