import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks open dialogs and menus (popup routes) so the panel can remove them
/// instantly, without their closing animation, when it hides. Doing that
/// while hidden means reopening never shows a stale frame of them first.
class OverlayRouteTracker extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _routes.remove(oldRoute);
    if (newRoute is PopupRoute) _routes.add(newRoute);
  }

  /// Removes, newest first and without animation, every tracked route that
  /// [test] selects.
  void removeWhere(bool Function(Route<dynamic> route) test) {
    for (final route in _routes.reversed.toList()) {
      if (!test(route)) continue;
      final navigator = route.navigator;
      if (navigator != null && route.isActive) navigator.removeRoute(route);
      _routes.remove(route);
    }
  }
}

/// One tracker per app (per ProviderScope), registered on the MaterialApp.
final overlayRouteTrackerProvider = Provider<OverlayRouteTracker>(
  (ref) => OverlayRouteTracker(),
);
