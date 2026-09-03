import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import 'keep_alive_service.dart';
import 'local_store.dart';
import 'push_service.dart';

/// HTTP 客户端封装：baseUrl 来自 AppConfig（编译期 dart-define → 运行时 json → 默认值）

/// 静默刷新结果三态：
/// - ok：拿到新 access token
/// - invalid：服务端明确拒绝（rt 作废/过期）→ 应清登录态回登录页
/// - network：网络不通/超时/存储读取失败 → **绝不能清登录态**，
///   重试即可。之前把网络错误也当 invalid，杀进程重开 App 时
///   网络还没就绪，一次刷新失败就把 token 全删了 → 用户被强制重新登录。
enum AuthRefreshResult { ok, invalid, network }

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
          final r = await _tryRefresh();
          if (r == AuthRefreshResult.ok) {
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
          } else if (r == AuthRefreshResult.invalid) {
            await _clearAuth();
            onUnauthorized?.call();
          }
          // network：不动登录态（网络恢复后重试即可），原错误透传，
          // 页面各自显示失败态/重试按钮
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

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  /// 内存缓存：flutter_secure_storage 在部分安卓机型上偶发读取慢/失败/挂起，
  /// 每个请求都现读一次会放大该问题（表现为聊天页等页面转圈后空白，重进恢复）。
  /// 读一次后走内存，写/清时同步维护缓存。
  String? _cachedToken;

  Future<String?> readToken() async {
    final c = _cachedToken;
    if (c != null && c.isNotEmpty) return c;
    final t = await _storage.read(key: _tokenKey);
    if (t != null && t.isNotEmpty) _cachedToken = t;
    return t;
  }

  static const _refreshKey = 'im_refresh_token';
  Future<void> saveRefresh(String t) =>
      _storage.write(key: _refreshKey, value: t);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  /// 轻量本地偏好（非敏感 UI 状态，如公告关闭记录）
  Future<String?> readPref(String key) => _storage.read(key: 'pref_$key');
  Future<void> writePref(String key, String? v) => v == null || v.isEmpty
      ? _storage.delete(key: 'pref_$key')
      : _storage.write(key: 'pref_$key', value: v);

  /// 用 refreshToken 刷新 accessToken。
  /// 三态返回：ok / invalid（服务端拒绝，清登录态）/ network（网络故障，保留登录态）。
  Future<AuthRefreshResult> refreshSession() => _tryRefresh();

  Future<AuthRefreshResult> _tryRefresh() async {
    // secure storage 在部分安卓机型上偶发读取失败/挂起：
    // 重试 3 次（每次 5s 封顶），都读不到按 network 处理 ——
    // "读不到 refresh token" ≠ "没登录过"，不能因此清凭据。
    String? rt;
    for (var i = 0; i < 3; i++) {
      try {
        rt = await _storage
            .read(key: _refreshKey)
            .timeout(const Duration(seconds: 5));
        break;
      } catch (_) {
        if (i == 2) return AuthRefreshResult.network;
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    if (rt == null || rt.isEmpty) return AuthRefreshResult.invalid;
    final refreshToken = rt; // 固定为非空局部量，闭包内可安全使用
    try {
      final r = await _withTransientRetry(() => _dio.post(
          '/api/v1/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(extra: {'_skipAuth': true})));
      final data = (r.data as Map<String, dynamic>);
      if ((data['code'] as num?)?.toInt() == 0) {
        final d = data['data'] as Map<String, dynamic>? ?? {};
        final access = d['accessToken']?.toString() ?? '';
        if (access.isNotEmpty) {
          await saveToken(access);
          return AuthRefreshResult.ok;
        }
      }
      // 服务端有响应但拒绝：rt 确实作废
      return AuthRefreshResult.invalid;
    } catch (_) {
      // 网络不通/超时：瞬时故障，不能当"token 作废"
      return AuthRefreshResult.network;
    }
  }

  Future<void> _clearAuth() async {
    await clearAuth();
  }

  /// 清空本地登录态（access + refresh）。
  /// 公开给 AuthGate 用：启动静默续期失败说明 refresh token 已被服务端
  /// 作废（多端登录挤掉 / Redis 白名单过期），留着只会让下次启动再空跑一次。
  Future<void> clearAuth() async {
    _cachedToken = null;
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
    // 清 UI 缓存（我的资料/通讯录/发现列表/会话列表/关于页配置）：
    // 换账号登录时不能闪现上一个账号的资料
    unawaited(writePref('profile', null));
    unawaited(writePref('contacts', null));
    unawaited(writePref('discoverApps', null));
    unawaited(writePref('assistantAvatar', null));
    // 会话列表 + 每会话最近消息（Hive）：换账号必须清，否则能看到上一个人的聊天
    unawaited(LocalStore.clearUserData());
    unawaited(writePref('authConfig', null));
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

  /// 瞬时故障判定：连接/读/发超时、连接错误、服务端 5xx。
  /// HTTP 200 + code!=0（业务失败）不在此列，由各 service 层自行处理。
  /// 公开给调用方做友好错误提示（如登录页把超时转成「网络连接失败」而不是 dump 原始异常）。
  static bool isTransient(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          return (e.response?.statusCode ?? 0) >= 500;
        default:
          return false;
      }
    }
    return false;
  }

  /// 瞬时失败自动重试（最多 2 次，退避 500ms/1s）。
  /// 登录后首页一批 GET 并发打出去，网络/服务端抖一下就直接失败——
  /// 表现为"通讯录加载失败/头像不显示，点重新加载又好了"。
  /// 自动重试把这类瞬时故障消化在客户端。只用于幂等请求（GET/refresh），
  /// POST/PUT 不重试，避免消息重复提交。
  Future<Response<T>> _withTransientRetry<T>(
      Future<Response<T>> Function() run) async {
    var attempt = 0;
    while (true) {
      try {
        return await run();
      } catch (e) {
        if (!isTransient(e) || attempt >= 2) rethrow;
        attempt++;
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    final token = await readToken();
    return _withTransientRetry(() => _dio.get(path,
        queryParameters: query,
        options: Options(headers: {'Authorization': 'Bearer $token'})));
  }

  Future<Response> post(String path, {Object? data}) async {
    final token = await readToken();
    return _dio.post(path,
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}));
  }

  /// 幂等安全 POST 的瞬时重试版本。登录时无 token；其他幂等 POST
  /// （如扫码进群 join，重复调用服务端按"已是成员"跳过）需传 headers 带 token。
  /// 服务端偶发响应慢 >10s（登录/进群首请求冷启动），自动重试（最多 2 次，
  /// 退避 500ms/1s）把这类瞬时故障消化在客户端。
  Future<Response> postIdempotent(String path,
      {Object? data, Map<String, dynamic>? headers}) async {
    return _withTransientRetry(
        () => _dio.post(path, data: data, options: Options(headers: headers)));
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
