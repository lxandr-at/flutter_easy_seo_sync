# flutter_easy_seo_sync

Testing mock suites, utility harnesses, and a REST sync service for the
[flutter_easy_seo](https://pub.dev/packages/flutter_easy_seo) ecosystem.

## Installation

```bash
flutter pub add flutter_easy_seo_sync
```

## Features

### SEO Sync Service

`SEOSyncService` pushes generated HTML pages and XML sitemaps to a backend API
(e.g. the [flutter_easy_seo_api](https://github.com/lxandr-at/flutter_easy_seo_api)
server) via multipart HTTP requests.

```dart
final service = SEOSyncService(
  apiKey: 'your-api-key',
  apiUrl: 'https://seo-api.example.com',
  appName: 'my-app',
);

// Send a rendered HTML page for a given route
await service.sendGeneratedData(
  html: '<html>...</html>',
  path: '/blog/post-1',
);

// Send an XML sitemap
await service.sendSitemap(
  sitemapXmlContent: '<urlset>...</urlset>',
  filename: 'sitemap.xml',
);
```

Set `forceIOClient: true` to bypass bad-certificate errors on `localhost` during
local development with self-signed certificates.

### Test Utilities

#### `testSeoWidgets`

A drop-in replacement for `testWidgets` that automatically configures the
test environment: suppresses overflow errors, sets a 1920x1080 viewport,
opens a JSON cache repository, and tears everything down afterward.

```dart
testSeoWidgets('renders SEO tags correctly', (tester) async {
  await tester.pumpWidget(const MyApp());
  expect(find.byKey(const ValueKey('/home')), findsOneWidget);
});
```

#### `waitForRoute`

Waits until a widget with `ValueKey(route)` exists in the tree **and**
`EasySEOManager.instance.seoPageIsReady()` returns `true`.

```dart
await waitForRoute('/blog/post-1', tester);
```

Pass an `extraCheck` callback for additional assertions:

```dart
await waitForRoute('/blog/post-1', tester, extraCheck: () {
  return EasySEOManager.instance.currentLang == 'en';
});
```

#### `setRouteBeforePumpWidget`

Injects a mock initial route before `pumpWidget` is called, simulating a
browser opening at a specific URL.

```dart
setRouteBeforePumpWidget(tester, '/blog/post-1');
await tester.pumpWidget(const MyApp());
```

#### `waitUntilReady`

Polls a condition function until it returns `true`, stepping out of the
fake-async zone on each iteration.

```dart
await waitUntilReady(tester, () => myService.isReady);
```

### Mock Defaults

#### `EasySEOMockPlatformChannels`

Registers all default mock platform channel handlers in a single call:

```dart
setUpAll(() {
  EasySEOMockPlatformChannels.useHeadlessDefaultMocks();
});
```

This mocks `path_provider`, `connectivity_plus`, and `shared_preferences`
channels, and unblocks real network requests.

#### `JsonCacheInfoRepository`

A JSON-backed cache used internally by `testSeoWidgets`. Operates in-memory
under `flutter test` to avoid left-over cached images on disk.

```dart
final repo = JsonCacheInfoRepository(databaseName: 'myCache');
await repo.open();
// ... run test ...
await repo.deleteDataFile();
```

## API Reference

| Class / Function | Description |
|---|---|
| `SEOSyncService` | REST client for syncing SEO pages and sitemaps to a backend API |
| `SEOSyncService.sendGeneratedData()` | Sends rendered HTML to the `/generatedSEOPage` endpoint |
| `SEOSyncService.sendSitemap()` | Sends an XML sitemap to the `/generatedSitemap` endpoint |
| `testSeoWidgets()` | Configured `testWidgets` replacement for SEO widget tests |
| `waitForRoute()` | Waits for a route widget and SEO readiness |
| `setRouteBeforePumpWidget()` | Injects a mock initial route before pumping |
| `waitUntilReady()` | Polls a condition with real-async support |
| `EasySEOMockPlatformChannels` | One-call setup for all default platform channel mocks |
| `JsonCacheInfoRepository` | File-backed (or in-memory) JSON cache for test image data to avoid left-over cached images on disk|

## License

This project is licensed under a custom
[Small Business License 1.0.0](https://lxandr.at/small_business_license.txt)
by [LX&R e.U.](https://lxandr.at).

Free for organizations with 5 or fewer employees and under $1M annual revenue.
See [LICENSE](LICENSE) for details.
