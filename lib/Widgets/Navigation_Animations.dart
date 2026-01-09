import 'package:flutter/material.dart';

class NavigationUtils {
  /// Navigate with Fade Transition
  static Future<T?> navigateWithFade<T>(BuildContext context, Widget destination) {
    return Navigator.push<T>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Fade animation
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300), // Adjust speed here
      ),
    );
  }

  /// Navigate with Fade + Replace (no back button)
  static void navigateWithFadeReplacement(BuildContext context, Widget destination) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Navigate with Scale Transition (Zoom In effect)
  static void navigateWithScale(BuildContext context, Widget destination) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Scale animation with curve
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );

          return ScaleTransition(
            scale: Tween<double>(
              begin: 0.8, // Start at 80% size
              end: 1.0,   // End at 100% size
            ).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Navigate with Scale + Fade (More elegant)
  static void navigateWithScaleFade(BuildContext context, Widget destination) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );

          return ScaleTransition(
            scale: Tween<double>(
              begin: 0.9, // Start slightly smaller
              end: 1.0,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
  /// Navigate with iOS-style Scale (page behind scales down)
  /// Navigate with iOS-style Scale (page behind scales down)
  static Future<T?> navigateWithIOSScale<T>(BuildContext context, Widget destination) {
    return Navigator.push<T>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );

          // Current page scales down as new page comes in
          final reverseAnimation = Tween<double>(
            begin: 1.0,
            end: 0.9,
          ).animate(curvedAnimation);

          return Stack(
            children: [
              // Old page scaling down
              ScaleTransition(
                scale: reverseAnimation,
                child: Container(), // This is the previous page
              ),
              // New page scaling up
              ScaleTransition(
                scale: Tween<double>(
                  begin: 1.1,
                  end: 1.0,
                ).animate(curvedAnimation),
                child: FadeTransition(
                  opacity: curvedAnimation,
                  child: child,
                ),
              ),
            ],
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

}