import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// HTTP 客户端封装：baseUrl 来自 .env，Token 安全存储
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  final Dio _dio = Dio(BaseOptions(
    // H5：默认空 → 请求走相对路径（同源反代）；native/直连：构建时 --dart-define=API_BASE_URL=http://IP:8080
    baseUrl: const String.fromEnvironment('API_BASE_URL',
        defaultValue: ''),
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'im_access_token';

  /// 公开 Dio 实例（供 service 层使用）
  Dio get dio => _dio;

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  static const _refreshKey = 'im_refresh_token';
  Future<void> saveRefresh(String t) => _storage.write(key: _refreshKey, value: t);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  /// 退出登录：调后端注销 + 清本地 token
  Future<void> logout() async {
    try {
      final t = await readToken();
      if (t != null) {
        await _dio.post('/api/v1/auth/logout',
            options: Options(headers: {'Authorization': 'Bearer $t'}));
      }
    } catch (_) {
      // 忽略网络错误，本地必清
    }
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    final token = await readToken();
    return _dio.get(path,
        queryParameters: query,
        options: Options(headers: {'Authorization': 'Bearer $token'}));
  }

  Future<Response> post(String path, {Object? data}) async {
    final token = await readToken();
    return _dio.post(path,
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}));
  }
}
