import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Wraps the default HTTP client and prints request/response lines in debug builds.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sw = Stopwatch()..start();
    final uri = request.url;
    final path = uri.path.isNotEmpty ? uri.path : uri.toString();

    debugPrint('[API] → ${request.method} $path');

    try {
      final response = await _inner.send(request);
      sw.stop();
      debugPrint(
        '[API] ← ${request.method} $path '
        '${response.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      return response;
    } catch (e, st) {
      sw.stop();
      debugPrint(
        '[API] ✗ ${request.method} $path '
        'failed (${sw.elapsedMilliseconds}ms): $e',
      );
      Error.throwWithStackTrace(e, st);
    }
  }

  @override
  void close() => _inner.close();
}
