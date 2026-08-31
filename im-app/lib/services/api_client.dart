import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import 'keep_alive_service.dart';
import 'push_service.dart';

/// HTTP 客户端封装：baseUrl 来自 AppConfig（编译期 dart-define → 运行时 json → 默认值）
class ApiClient {
  ApiClient._() {
    // 401 统一处理：用 refreshToken 换新 access → 重试原请求；刷新失败清登录态并回调跳登录
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) async {
        final status = e.response?.statusCode;
        final retried = e.requestOptions.extra['_retried'] == true;
        // _skipAuth：刷新 token / 退出登录这类"本来就不需要登录态"的请求，
        // 401 属于预期结果，不能再走刷新 + 踢登录页那一套
        // （否则退出登录的通知请求会把刚登录的新账号一起踢掉，B-18）
        final skipAuth = e.requestOptions.extra['_skipAuth'] == true;
        if (status == 401 && !retried && !skipAuth) {
          final ok = await _tryRefresh();
          if (ok) {
            final token = await readToken();
            final opts = e.requestOptions;
            opts.extra['_retried'] = true;
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final resp = await _dio.fetch(opts);
              return handler.resolve(resp);
            } catch (_) {
              return handler.next(e);
            }
          } else {
            await _clearAuth();
            onUnauthorized?.call();
          }
        }
        handler.next(e);
      },
    ));
  }

  static final ApiClient instance = ApiClient._();
  final Dio _dio = Dio(BaseOptions(
    // 需求5：接口地址统一走 AppConfig（支持 config/app_config.json 运行时配置）
    baseUrl: AppConfig.instance.apiBase,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'im_access_token';

  /// 公开 Dio 实例（供 service 层使用）
  Dio get dio => _dio;

  /// 401 且刷新失败 → 由 main 注册回调跳转登录页
  void Function()? onUnauthorized;

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  static const _refreshKey = 'im_refresh_token';
  Future<void> saveRefresh(String t) =>
      _storage.write(key: _refreshKey, value: t);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  /// 用 refreshToken 刷新 accessToken（成功返回 true；无 refresh / 已过期返回 false）
  Future<bool> refreshAccess() => _tryRefresh();

  Future<bool> _tryRefresh() async {
    final rt = await readRefresh();
    if (rt == null || rt.isEmpty) return false;
    try {
      final r = await _dio.post('/api/v1/auth/refresh',
          data: {'refreshToken': rt},
          options: Options(extra: {'_skipAuth': true}));
      final data = (r.data as Map<String, dynamic>);
      if ((data['code'] as num?)?.toInt() == 0) {
        final d = data['data'] as Map<String, dynamic>? ?? {};
        final access = d['accessToken']?.toString() ?? '';
        if (access.isNotEmpty) {
          await saveToken(access);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearAuth() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
  }

  /// 退出登录：调后端注销 + 清本地 token
  /// 退出登录：**先清本地登录态，再通知服务端**。
  ///
  /// 之前是"先发请求、成功后再清本地"，dio 的 connect 5s + receive 10s，
  /// 服务器慢或不可达时最多要等 15s —— 用户点了"退出登录"却半天没反应（B-18）。
  /// 本地 token 必须先清（这是退出登录唯一必须成功的事），
  /// 服务端通知失败不影响本地已登出，且整段调用 4s 封顶。
  Future<void> logout() async {
    final t = await readToken();
    await _clearAuth(); // 先清本地：access + refresh 一起删
    // 极光推送解绑 alias：避免注销后仍收到该账号的离线推送
    unawaited(PushService.instance.stop());
    // 停掉保活前台服务：通知栏消失，进程可被正常回收
    unawaited(KeepAliveService.instance.stop());
    if (t == null || t.isEmpty) return;
    try {
      await _dio
          .post(
            '/api/v1/auth/logout',
            options: Options(
              headers: {'Authorization': 'Bearer $t'},
              // 这个请求 401 是预期结果（token 已清），别触发"踢登录页"
              extra: {'_skipAuth': true},
            ),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // 忽略网络错误，本地已清
    }
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

  Future<Response> put(String path, {Object? data}) async {
    final token = await readToken();
    return _dio.put(path,
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}));
  }

  /// 上传文件到 MinIO，返回 URL（需求3：图片发送）
  Future<Map<String, dynamic>> uploadFile(String filePath, String fileName,
      {String dir = 'chat/'}) async {
    final token = await readToken();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'dir': dir,
    });
    final r = await _dio.post('/api/v1/upload',
        data: form,
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }
}
