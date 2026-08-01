import 'package:dio/dio.dart';
import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';

class ApiService {
  ApiService({
    required AuthSecureStorage secureStorage,
    Dio? dio,
    String? baseUrl,
  }) : _secureStorage = secureStorage,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl:
                   baseUrl ??
                   const String.fromEnvironment(
                     'API_BASE_URL',
                     defaultValue: 'http://10.0.2.2:8000/api/v1',
                   ),
               connectTimeout: requestTimeout,
               receiveTimeout: requestTimeout,
               sendTimeout: requestTimeout,
               headers: const {
                 'Accept': 'application/json',
                 'Content-Type': 'application/json',
               },
             ),
           ) {
    _dio.interceptors.add(_AuthInterceptor(_secureStorage));
  }

  final AuthSecureStorage _secureStorage;
  final Dio _dio;

  static const requestTimeout = Duration(seconds: 12);

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _send(
      () => _dio.get<Object?>(
        _normalizePath(path),
        queryParameters: queryParameters,
        options: _options(authenticated: authenticated),
      ),
    );

    return _decodeMap(response.data);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      () => _dio.post<Object?>(
        _normalizePath(path),
        data: body ?? const <String, dynamic>{},
        options: _options(authenticated: authenticated),
      ),
    );

    return _decodeMap(response.data);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      () => _dio.delete<Object?>(
        _normalizePath(path),
        options: _options(authenticated: authenticated),
      ),
    );

    return _decodeMap(response.data);
  }

  Options _options({required bool authenticated}) {
    return Options(extra: {'authenticated': authenticated});
  }

  String _normalizePath(String path) {
    return path.startsWith('/') ? path : '/$path';
  }

  Future<Response<Object?>> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException(_messageForDioError(error));
    }
  }

  Map<String, dynamic> _decodeMap(Object? data) {
    if (data == null || data == '') return <String, dynamic>{};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    throw const ApiException('Backend returned an unexpected response.');
  }

  String _messageForDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Backend is taking too long to respond. Check Docker and try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the backend. Make sure Docker is running.';
      default:
        return _backendErrorMessage(error.response?.data);
    }
  }

  String _backendErrorMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }

    return 'Backend request failed.';
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._secureStorage);

  final AuthSecureStorage _secureStorage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final authenticated = options.extra['authenticated'] != false;
    if (authenticated) {
      final token = await _secureStorage.readBackendToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;
}
