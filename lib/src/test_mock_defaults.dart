import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:path/path.dart' as p; // Pure Dart package, no Flutter dependency

/// Provides mock platform channel handlers for running Flutter widget tests
/// in a headless environment.
///
/// Call [useHeadlessDefaultMocks] once at the start of a test suite or
/// individual test to register all default mocks. This eliminates
/// `MissingPluginException` errors caused by native plugin channels
/// that are unavailable outside a real device.
///
/// The following channels are mocked:
///
/// | Channel | Behavior |
/// |---|---|
/// | `plugins.flutter.io/path_provider` | Returns `.` for all directories |
/// | `dev.fluttercommunity.plus/connectivity` | Returns `['wifi']` |
/// | `plugins.flutter.io/shared_preferences` | Stores values in memory |
///
/// Real network requests are also unblocked by resetting
/// [HttpOverrides.global] to `null`.
class EasySEOMockPlatformChannels {
  /// Registers all default mock platform channel handlers.
  ///
  /// Call this once before any widget is pumped:
  ///
  /// ```dart
  /// void main() {
  ///   setUpAll(() {
  ///     EasySEOMockPlatformChannels.useHeadlessDefaultMocks();
  ///   });
  ///
  ///   testWidgets('renders correctly', (tester) async {
  ///     await tester.pumpWidget(const MyApp());
  ///   });
  /// }
  /// ```
  static void useHeadlessDefaultMocks() {
    _allowRealNetWorkRequests();
    _mockPathProvider();
    _mockConnectivityPlugin();
    _mockSharedPreferences();
  }

  static void _allowRealNetWorkRequests() {
    HttpOverrides.global = null;
  }

  static void _mockConnectivityPlugin({String initialResult = 'wifi'}) {
    // 1. Establish a reference to the exact channel name from the exception
    const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/connectivity');

    // 2. Set the mock method call handler using the modern TestDefaultBinaryMessenger API
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {

      // 3. Robust route handling based on the channel's API contract
      switch (methodCall.method) {
        case 'check':
        // Returns a string or a list of strings representing the active connection type
        // For connectivity_plus v6+, it typically expects a List<String> or a String matching enum names
          return <String>[initialResult];

        default:
        // Fail gracefully for unexpected methods to maintain test safety
          throw MissingPluginException(
            'No implementation found for method ${methodCall.method} on channel ${channel.name}',
          );
      }
    });
  }

  static void _mockPathProvider() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getApplicationSupportDirectory': // Maps to getApplicationSupportPath()
            return '.';
          case 'getTemporaryDirectory':
            return '.';
          case 'getApplicationDocumentsDirectory':
            return '.';
          default:
            return null;
        }
      },
    );
  }

  static void _mockSharedPreferences({Map<String, Object> initialValues = const {}}) {
    // 1. Target the exact internal channel string for SharedPreferences
    const MethodChannel channel = MethodChannel('plugins.flutter.io/shared_preferences');

    // 2. Register the mock handler on the test binary messenger
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {

      switch (methodCall.method) {
        case 'getAll':
        // The shared_preferences plugin expects a prefixed key-value map
        // containing your initial testing states
          return initialValues;

        case 'setBool':
        case 'setString':
        case 'setInt':
        case 'setDouble':
        case 'setStringList':
        case 'remove':
        case 'clear':
        // Return true to simulate a successful disk write operation
          return true;

        default:
          throw MissingPluginException(
            'No implementation found for method ${methodCall.method} on channel ${channel.name}',
          );
      }
    });
  }
}

/// A lightweight JSON-backed cache for storing image metadata during tests.
///
/// When running under the `FLUTTER_TEST` environment variable (i.e. inside
/// `flutter test`), the repository operates entirely in memory with no
/// file system side effects. Outside of tests it persists data to a JSON
/// file in the system temp directory.
///
/// This class is used internally by [testSeoWidgets] to manage cached
/// image data across test setup and teardown.
class JsonCacheInfoRepository {
  /// The logical name for this cache instance.
  ///
  /// Maps to `{databaseName}.json` on disk when running outside of tests.
  final String databaseName;
  File? _targetFile;
  bool _isInitialized = false;
  final Map<String, dynamic> _memoryStorage = {};

  /// Creates a [JsonCacheInfoRepository] with the given [databaseName].
  ///
  /// Call [open] after construction to initialize the cache.
  JsonCacheInfoRepository({required this.databaseName});

  bool get _isUnderTest => Platform.environment.containsKey('FLUTTER_TEST');

  /// Initializes the cache.
  ///
  /// Under the `FLUTTER_TEST` environment, this sets up an in-memory store
  /// with no file system interaction. Outside of tests it creates a
  /// directory at `{systemTemp}/flutter_easy_seo_cache/` and targets
  /// `{databaseName}.json` inside it.
  ///
  /// This method is idempotent and returns immediately if already
  /// initialized.
  Future<void> open() async {
    if (_isInitialized) return;

    if (!_isUnderTest) {
      // NATIVE REPLACEMENT: Grabs the OS system temp directory directly
      final Directory systemTempDir = Directory.systemTemp;

      // Namespace it so it is cleanly siloed on the user's host file system
      final String directoryPath = p.join(systemTempDir.path, 'flutter_easy_seo_cache');
      await Directory(directoryPath).create(recursive: true);

      _targetFile = File(p.join(directoryPath, '$databaseName.json'));
    }

    _isInitialized = true;
  }

  /// Clears the cache.
  ///
  /// Under the `FLUTTER_TEST` environment, this clears the in-memory map.
  /// Outside of tests it deletes the JSON file from disk if it exists.
  Future<void> deleteDataFile() async {
    if (_isUnderTest) {
      _memoryStorage.clear();
    } else if (_targetFile != null && await _targetFile!.exists()) {
      await _targetFile!.delete();
    }
  }
}