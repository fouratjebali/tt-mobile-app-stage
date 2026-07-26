/// Responsible for making actual HTTP requests to the backend API.
abstract class ApiService {
  Future<dynamic> get(String path, {Map<String, String>? headers});

  Future<dynamic> post(
      String path, {
        Object? body,
        Map<String, String>? headers,
      });
}

/// Thrown when the backend returns a non-2xx response.
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
