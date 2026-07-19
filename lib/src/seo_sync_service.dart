import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart'; // Required for setting explicit MediaType

/// A REST client that synchronizes generated SEO data with a backend API.
///
/// Use this service to push rendered HTML pages and XML sitemaps to the
/// server-side rendering pipeline provided by
/// [flutter_easy_seo_api](https://github.com/lxandr-at/flutter_easy_seo_api).
///
/// ```dart
/// final service = SEOSyncService(
///   apiKey: 'your-api-key',
///   apiUrl: 'https://seo-api.example.com',
///   appName: 'my-app',
/// );
///
/// await service.sendGeneratedData(html: renderedHtml, path: '/blog/post-1');
/// await service.sendSitemap(sitemapXmlContent: sitemapXml);
/// ```
class SEOSyncService {
  /// Creates an [SEOSyncService].
  ///
  /// [apiKey] is sent in the `X-API-Key` request header.
  /// [apiUrl] is the base URL of the backend API (without a trailing slash).
  /// [appName] is an optional identifier included in every request payload.
  SEOSyncService({
    required this.apiKey,
    required this.apiUrl,
    this.appName = "",
  });

  /// The API key sent in the `X-API-Key` header of every request.
  final String apiKey;

  /// The base URL of the SEO backend API (no trailing slash).
  ///
  /// For example: `https://seo-api.example.com`.
  final String apiUrl;

  /// An optional application identifier included in multipart request fields.
  ///
  /// Defaults to an empty string. When provided, it is sent as the `app_name`
  /// field alongside the file payload.
  final String appName;

  Future<void> _sendMultipart({
    required Uri url,
    required http.MultipartFile file,
    required Map<String, String> fields,
    required String context,
    bool forceIOClient = false,
  }) async {
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll({
      'Accept': 'application/json',
      'X-API-Key': apiKey,
    });
    request.fields.addAll(fields);
    request.files.add(file);

    IOClient? ioClient;
    try {
      final http.StreamedResponse streamedResponse;

      if (forceIOClient) {
        // Create the base HttpClient
        final baseHttpClient = HttpClient();

        // Configure bad certificate bypass strictly for local environments
        if (kDebugMode) {
          baseHttpClient.badCertificateCallback =
              (X509Certificate cert, String host, int port) {
            final isLocal = host == 'localhost' ||
                host == '127.0.0.1' ||
                host.startsWith('10.0.2.'); // Android emulator fallback
            return isLocal;
          };
        }

        ioClient = IOClient(baseHttpClient);
        streamedResponse = await ioClient.send(request);
      } else {
        streamedResponse = await request.send();
      }

      final response = await http.Response.fromStream(streamedResponse);
      _logResponse(context, response);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Network Error during $context: $e');
      }
      rethrow;
    } finally {
      ioClient?.close();
    }
  }

  /// Sends a rendered HTML page to the backend for SEO processing.
  ///
  /// The [html] string is uploaded as a multipart file named `index.html`
  /// to the `{apiUrl}/generatedSEOPage` endpoint.
  ///
  /// The [path] is the URL path the page will be served at (e.g. `/blog/post`).
  /// If [path] is empty, `/` is used instead.
  ///
  /// When [forceIOClient] is `true`, a custom [IOClient] is created that
  /// bypasses bad-certificate errors for `localhost`, `127.0.0.1`, and
  /// Android emulator addresses (`10.0.2.*`) in debug mode. Use this for
  /// local development with self-signed certificates.
  Future<void> sendGeneratedData({
    required String html,
    required String path,
    bool forceIOClient = false,
  }) async {
    final url = Uri.parse('$apiUrl/generatedSEOPage');
    final file = http.MultipartFile.fromString(
      'file',
      html,
      filename: 'index.html',
      contentType: MediaType('text', 'html'),
    );
    await _sendMultipart(
      url: url,
      file: file,
      fields: {'path': path.isEmpty ? '/' : path, 'app_name': appName},
      context: 'SEO Sync',
      forceIOClient: forceIOClient,
    );
  }

  /// Sends an XML sitemap to the backend for indexing.
  ///
  /// The [sitemapXmlContent] string is uploaded as a multipart file to
  /// the `{apiUrl}/generatedSitemap` endpoint.
  ///
  /// [filename] defaults to `sitemap.xml` but can be overridden for
  /// localized sitemaps (e.g. `sitemap_de.xml`).
  ///
  /// When [forceIOClient] is `true`, a custom [IOClient] is created that
  /// bypasses bad-certificate errors for `localhost`, `127.0.0.1`, and
  /// Android emulator addresses (`10.0.2.*`) in debug mode. Use this for
  /// local development with self-signed certificates.
  Future<void> sendSitemap({
    required String sitemapXmlContent,
    String filename = 'sitemap.xml',
    bool forceIOClient = false,
  }) async {
    final url = Uri.parse('$apiUrl/generatedSitemap');
    final file = http.MultipartFile.fromString(
      'file',
      sitemapXmlContent,
      filename: filename,
      contentType: MediaType('application', 'xml'),
    );
    await _sendMultipart(
      url: url,
      file: file,
      fields: {'app_name': appName},
      context: 'Sitemap Sync',
      forceIOClient: forceIOClient,
    );
  }

  /// Centralized logging helper for consistent response management
  void _logResponse(String context, http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (kDebugMode) {
        print('✅ $context Successful: ${response.body}');
      }
    } else {
      if (kDebugMode) {
        print('❌ $context Failed: ${response.statusCode} - ${response.body}');
      }
      throw HttpException('$context failed with status code ${response.statusCode}');
    }
  }
}
