import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiClient(storage);
});

class ApiClient {
  final StorageService _storage;
  late final Dio _dio;

  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final serverUrl = await _storage.getServerUrl();
          if (!options.path.startsWith('http')) {
            options.baseUrl = serverUrl;
          }

          final token = await _storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Gestion du rafraîchissement automatique de token en cas de 401
          if (error.response?.statusCode == 401 && !error.requestOptions.path.contains('/auth/')) {
            try {
              final refreshToken = await _storage.getRefreshToken();
              final serverUrl = await _storage.getServerUrl();
              if (refreshToken != null) {
                final refreshResponse = await Dio().post(
                  '$serverUrl/api/v1/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                final newToken = refreshResponse.data['accessToken'];
                if (newToken != null) {
                  await _storage.saveAccessToken(newToken);
                  error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                  final retryResponse = await _dio.fetch(error.requestOptions);
                  return handler.resolve(retryResponse);
                }
              }
            } catch (_) {
              // Échec du refresh, l'utilisateur devra ressaisir son PIN
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return _dio.post<T>(path, data: data);
  }
}
