
import 'package:dio/dio.dart';

import 'api_client.dart';

class AuthConfig {
  final String authMode; // none / sms / email
  final bool inviteCodeOn;
  final bool registerOn;
  // 品牌信息（后端 /auth/config 提供，前端用于登录/注册页 logo + 名称展示）
  final String appName;
  final String appLogo;
  final String brandName;
  final String brandLogo;

  AuthConfig.fromJson(Map<String, dynamic> j)
      : authMode = j['authMode'] ?? 'none',
        inviteCodeOn = j['inviteCodeOn'] ?? false,
        registerOn = j['registerOn'] ?? true,
        appName = (j['appName'] ?? j['app_name'] ?? 'ChatPulse').toString(),
        appLogo = (j['appLogo'] ?? j['app_logo'] ?? '').toString(),
        brandName = (j['brandName'] ?? j['brand_name'] ?? j['appName'] ?? 'ChatPulse').toString(),
        brandLogo = (j['brandLogo'] ?? j['brand_logo'] ?? j['appLogo'] ?? '').toString();
}

class Captcha {
  final String captchaId;
  final String imageBase64;

  Captcha.fromJson(Map<String, dynamic> j)
      : captchaId = j['captchaId'],
        imageBase64 = j['image'];
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  AuthResult.fromJson(Map<String, dynamic> j)
      : accessToken = j['accessToken'],
        refreshToken = j['refreshToken'],
        user = j['user'] ?? {};
}

class AuthService {
  final Dio _dio = ApiClient.instance.dio;
  final _api = ApiClient.instance;

  Future<AuthConfig> getConfig() async {
    final r = await _api.get('/api/v1/auth/config');
    return AuthConfig.fromJson(r.data['data']);
  }

  Future<Captcha> getCaptcha() async {
    final r = await _api.get('/api/v1/auth/captcha');
    return Captcha.fromJson(r.data['data']);
  }

  Future<void> sendCode(String account, String captchaId, String captchaCode,
      {String countryCode = '+86'}) async {
    await _dio.post('/api/v1/auth/send-code',
        data: {
          'account': account,
          'countryCode': countryCode,
          'captchaId': captchaId,
          'captchaCode': captchaCode,
        });
  }

  Future<AuthResult> login(String account, String password,
      {String deviceId = ''}) async {
    final r = await _dio.post('/api/v1/auth/login',
        data: {
          'account': account,
          'password': password,
          'deviceType': 1,
          'deviceId': deviceId,
        });
    _check(r);
    return AuthResult.fromJson(r.data['data']);
  }

  Future<AuthResult> register({
    required String account,
    required String password,
    String nickname = '',
    String? code,
    String? inviteCode,
    String? captchaId,
    String? captchaCode,
  }) async {
    final data = <String, dynamic>{
      'account': account,
      'password': password,
      'nickname': nickname,
      'code': code,
      'inviteCode': inviteCode,
      'deviceType': 1,
    };
    // 图形验证码（后端若启用则传，UI 已不再收集）
    if (captchaId != null && captchaId.isNotEmpty) {
      data['captchaId'] = captchaId;
      data['captchaCode'] = captchaCode ?? '';
    }
    final r = await _dio.post('/api/v1/auth/register', data: data);
    _check(r);
    return AuthResult.fromJson(r.data['data']);
  }

  void _check(Response r) {
    final code = r.data['code'];
    if (code != 0) {
      throw Exception(r.data['message'] ?? '请求失败');
    }
  }
}
