/// Support package for the [flutter_easy_seo](https://pub.dev/packages/flutter_easy_seo)
/// ecosystem.
///
/// Provides two main capabilities:
///
/// - **SEO sync service** ([SEOSyncService]) — a REST client that pushes
///   generated HTML pages and XML sitemaps to a backend API.
/// - **Test utilities** — mock defaults, widget-test wrappers, and helper
///   functions for writing reliable tests against projects that use
///   `flutter_easy_seo`.
library;

export 'src/test_functions.dart';
export 'src/test_mock_defaults.dart';
export 'src/seo_sync_service.dart';