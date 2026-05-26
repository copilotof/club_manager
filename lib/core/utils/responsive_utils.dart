// lib/core/utils/responsive_utils.dart
import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  // تحديد نوع الجهاز
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint &&
        MediaQuery.of(context).size.width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  // الحصول على حجم الخط المتجاوب
  static double responsiveFontSize(
    BuildContext context, {
    required double fontSize,
  }) {
    double scaleFactor =
        MediaQuery.of(context).size.width / 375; // 375 هو عرض iPhone SE
    if (scaleFactor > 1.2) scaleFactor = 1.2;
    if (scaleFactor < 0.8) scaleFactor = 0.8;
    return fontSize * scaleFactor;
  }

  // الحصول على المسافة (padding/margin) المتجاوبة
  static double responsiveSpacing(
    BuildContext context, {
    required double spacing,
  }) {
    double scaleFactor = MediaQuery.of(context).size.width / 375;
    if (scaleFactor > 1.5) scaleFactor = 1.5;
    if (scaleFactor < 0.8) scaleFactor = 0.8;
    return spacing * scaleFactor;
  }

  // عرض الصورة المتجاوبة
  static double responsiveImageSize(
    BuildContext context, {
    required double size,
  }) {
    if (isMobile(context)) return size * 0.8;
    if (isTablet(context)) return size;
    return size * 1.2;
  }
}

// ويدجت مساعدة لتبديل التخطيط حسب نوع الجهاز
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(context, constraints),
    );
  }
}

// ويدجت لعرض تخطيط مختلف للهواتف والأجهزة اللوحية
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveUtils.tabletBreakpoint) {
          return desktopLayout ?? tabletLayout ?? mobileLayout;
        } else if (constraints.maxWidth >= ResponsiveUtils.mobileBreakpoint) {
          return tabletLayout ?? mobileLayout;
        } else {
          return mobileLayout;
        }
      },
    );
  }
}

// ويدجت لعرض شبكة متجاوبة (GridView responsive)
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;

    if (screenWidth < 500) {
      crossAxisCount = 1;
      childAspectRatio = 1.5;
    } else if (screenWidth < 800) {
      crossAxisCount = 2;
      childAspectRatio = 1.3;
    } else if (screenWidth < 1100) {
      crossAxisCount = 3;
      childAspectRatio = 1.2;
    } else {
      crossAxisCount = 4;
      childAspectRatio = 1.1;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
