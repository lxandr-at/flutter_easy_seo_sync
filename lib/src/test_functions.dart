import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easy_seo/flutter_easy_seo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import 'test_mock_defaults.dart'; // Pure Dart package, no Flutter dependency

/// Injects a mock [initialRoute] into the `SystemChannels.navigation`
/// platform channel before [WidgetTester.pumpWidget] is called.
///
/// This simulates the browser opening at a specific URL so that
/// route-dependent widgets (e.g. deep links) are tested from the
/// correct starting point.
///
/// ```dart
/// testSeoWidgets('loads blog post', (tester) async {
///   setRouteBeforePumpWidget(tester, '/blog/post-1');
///   await tester.pumpWidget(const MyApp());
///   // ...
/// });
/// ```
void setRouteBeforePumpWidget(WidgetTester tester, String initialRoute) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation, (methodCall) async {
    if (methodCall.method == 'getInitialRoute') {
      return initialRoute;
    }
    return null;
  });
}

/// Polls [condition] until it returns `true` or [timeout] elapses.
///
/// Steps out of the fake-async zone on each iteration to allow real-world
/// async operations (network mocks, engine updates) to settle. A small
/// [pump] call is issued each cycle to flush the microtask queue and
/// trigger layout rebuilds.
///
/// Throws an [Exception] if the condition is not met within [timeout].
/// Increase [timeout] for long-running operations such as bulk database
/// loads.
Future<void> waitUntilReady(
    WidgetTester tester,
    bool Function() condition, {
      Duration timeout = const Duration(seconds: 5),
    }) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw Exception('Timeout');

    // 1. Step outside the fake async zone to allow real-time asynchronous operations
    // (like network mocks or engine updates) to catch up.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));

    // 2. Pass a micro-duration to pump().
    // This explicitly tells the Test Widgets Flutter Binding to advance the virtual clock.
    // Advancing the clock forces the engine to flush the microtask queue (your GoRouter redirect
    // provider change) and trigger a layout rebuild frame, without getting stuck in infinite animations.
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Waits until a widget with `ValueKey(route)` exists in the tree **and**
/// [EasySEOManager.instance.seoPageIsReady] returns `true`.
///
/// This combines structural DOM checks with the SEO lifecycle readiness
/// check to ensure the page is fully rendered and SEO metadata is
/// propagated before assertions run.
///
/// An optional [extraCheck] callback can be provided for additional
/// assertions such as verifying language propagation or global state.
///
/// ```dart
/// await waitForRoute('/blog/post-1', tester, extraCheck: () {
///   return EasySEOManager.instance.currentLang == 'en';
/// });
/// ```
///
/// Throws an [Exception] if the condition is not met within [timeout].
Future<void> waitForRoute(
    String route,
    WidgetTester tester, {
      bool Function()? extraCheck,
      Duration timeout = const Duration(seconds: 5),
    }) async {
  debugPrint('🚀 [TEST] Waiting for: $route');

  await waitUntilReady(tester, () {
    // 1. Core structural DOM check
    final routeExists = find.byKey(ValueKey(route)).evaluate().isNotEmpty;

    // 2. Core package lifecycle readiness check
    final seoReady = EasySEOManager.instance.seoPageIsReady();

    // 3. Evaluate the user-defined hook if it was provided
    if (extraCheck != null) {
      return routeExists && seoReady && extraCheck();
    }

    return routeExists && seoReady;
  }, timeout: timeout);

  debugPrint('🚀 [TEST] DONE waiting for: $route');
}

/// A drop-in replacement for [testWidgets] that configures the test
/// environment for SEO-related widget tests.
///
/// Automatically performs the following setup and teardown:
///
/// **Setup:**
/// - Suppresses Flutter overflow errors (common in test resolution mismatches).
/// - Sets a 1920x1080 physical size at 1.0 device pixel ratio.
/// - Opens a [JsonCacheInfoRepository] for cached image data.
///
/// **Teardown (guaranteed via `finally`):**
/// - Deletes the cache data file.
/// - Restores the original [FlutterError.onError] handler.
/// - Resets physical size and device pixel ratio.
///
/// ```dart
/// testSeoWidgets('renders SEO tags correctly', (tester) async {
///   await tester.pumpWidget(const MyApp());
///   expect(find.byKey(const ValueKey('/home')), findsOneWidget);
/// });
/// ```
@isTest
void testSeoWidgets(
    String description,
    Future<void> Function(WidgetTester tester) callback, {
      bool skip = false,
      Timeout? timeout,
    }) {
  // We leverage Flutter's native block under the hood
  testWidgets(
    description,
    (WidgetTester tester) async {
      // AUTOMATED SETUP
      // ignore overflowed error
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      // Set a 4K or Large Desktop resolution
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      final repo = JsonCacheInfoRepository(databaseName: 'libCachedImageData');
      await repo.open();

      try {
        // EXECUTE USER'S ACTUAL TEST CODE
        await callback(tester);
      } finally {
        // AUTOMATED TEARDOWN (Guaranteed to execute even if the test fails)
        await repo.deleteDataFile();
        // Reset error handling state cleanly when this specific test finishes
        FlutterError.onError = originalOnError;
        // reset to default when test finishes (good practice)
        tester.view.resetPhysicalSize;
        tester.view.resetDevicePixelRatio;
      }
    },
    skip: skip,
    timeout: timeout,
  );
}