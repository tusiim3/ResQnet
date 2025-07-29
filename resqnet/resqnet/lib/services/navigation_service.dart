import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static NavigatorState? get navigator => navigatorKey.currentState;
  
  static void navigateToAlertFeed() {
    if (navigator != null) {
      // Navigate to home screen and then switch to alert feed tab
      navigator!.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'tabIndex': 2}, 
      );
    }
  }
  
  static void navigateToHome({int? tabIndex}) {
    if (navigator != null) {
      navigator!.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: tabIndex != null ? {'tabIndex': tabIndex} : null,
      );
    }
  }
}
