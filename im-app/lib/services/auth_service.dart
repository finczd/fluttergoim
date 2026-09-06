import 'package:dio/dio.dart';

import 'api_client.dart';
import '../l10n/app_locale.dart';

class AuthConfig {
  final String authMode; // none / sms / email
  final bool inviteCodeOn;
  final bool registerOn;
  final bool guestOn;

  /// 图形验证码开关（后端未部署该字段时缺失 → 兜底 false，不会崩）
  final bool captchaOn;
  // 品牌信息（后端 /auth/config 提供，前端用于登录/注册页 logo + 名称展示）
  final String appName;
  final String appLogo;
  final String brandName;
  final String brandLogo;

  AuthConfig.fromJson(Map<String, dynamic> j)
      : authMode = j['authMode'] ?? 'none',
        inviteCodeOn = j['inviteCodeOn'] ?? false,
        registerOn = j['registerOn'] ?? true,
        guestOn = j['guestOn'] ?? false,
        captchaOn = j['captchaOn'] ?? false,
        appName = (j['appName'] ?? j['app_name'] ?? 'ChatPulse').toString(),
        appLogo = (j['appLogo'] ?? j['app_logo'] ?? '').toString(),
        brandName =
            (j['brandName'] ?? j['brand_name'] ?? j['appName'] ?? 'ChatPulse')
                .toString(),
        brandLogo = (j['brandLogo'] ?? j['brand_logo'] ?? j['appLogo'] ?? '')
            .toString();
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
  final bool isNewGuest;

  AuthResult.fromJson(Map<String, dynamic> j)
      : accessToken = j['accessToken'],
        refreshToken = j['refreshToken'],
        user = j['user'] ?? {},
        isNewGuest = j['isNewGuest'] ?? false;
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

  /// 发送验证码。channel: sms(短信) / email(邮箱)，为空时由后端按 AUTH_MODE 决定。
  /// 返回实际发送渠道（'sms' / 'email'），供 UI 提示"已发送至短信/邮箱"。
  /// 注意：必须检查响应 code，否则短信发送失败会被静默吞掉（用户看到"已发送"却收不到码）。
  Future<String> sendCode(String account, String captchaId, String captchaCode,
      {String countryCode = '+86', String channel = 'sms'}) async {
    final r = await _dio.post('/api/v1/auth/send-code', data: {
      'account': account,
      'countryCode': countryCode,
      'captchaId': captchaId,
      'captchaCode': captchaCode,
      'channel': channel,
    });
    _check(r);
    final data = r.data['data'];
    return (data is Map && data['channel'] is String)
        ? data['channel'] as String
        : channel;
  }

  Future<AuthResult> login(String account, String password,
      {String deviceId = ''}) async {
    // 登录 POST 幂等（重复提交无害）：走瞬时重试，服务端冷启动/首连慢时
    // 第一次 receive timeout 自动再试，不再让用户手动登第二次
    final r = await _api.postIdempotent('/api/v1/auth/login', data: {
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
    String? channel,
  }) async {
    final data = <String, dynamic>{
      'account': account,
      'password': password,
      'nickname': nickname,
      'inviteCode': inviteCode,
      'deviceType': 1,
    };
    // 认证模式为 none 时不要带 channel/code：
    // 后端 `req.Channel != ""` 会强制走短信分支，拿空 code 去 Redis 比对必然报 2002
    // 「验证码错误或过期」，而这个报错与图形验证码开关无关。
    if (channel != null && channel.isNotEmpty) {
      data['channel'] = channel;
    }
    if (code != null && code.isNotEmpty) {
      data['code'] = code;
    }
    // 图形验证码（需要时才传）
    if (captchaId != null && captchaId.isNotEmpty) {
      data['captchaId'] = captchaId;
      data['captchaCode'] = captchaCode ?? '';
    }
    final r = await _dio.post('/api/v1/auth/register', data: data);
    _check(r);
    return AuthResult.fromJson(r.data['data']);
  }

  /// 绑定手机号：发送短信验证码（需登录 + 图形验证码）
  Future<void> sendBindPhoneCode(String phone, String countryCode,
      String captchaId, String captchaCode) async {
    final r = await _dio.post('/api/v1/user/bind-phone/send-code', data: {
      'phone': phone,
      'countryCode': countryCode,
      'captchaId': captchaId,
      'captchaCode': captchaCode,
    });
    _check(r);
  }

  /// 绑定手机号：校验短信验证码后写入
  Future<void> bindPhone(
      String phone, String countryCode, String code) async {
    final r = await _dio.post('/api/v1/user/bind-phone', data: {
      'phone': phone,
      'countryCode': countryCode,
      'code': code,
    });
    _check(r);
  }

  /// 游客注册/登录：按设备号幂等（后端处理）。返回登录态，用法同 login。
  Future<AuthResult> guestRegister(
      {required String deviceId, int deviceType = 1}) async {
    final r = await _dio.post('/api/v1/auth/guest', data: {
      'deviceId': deviceId,
      'deviceType': deviceType,
    });
    _check(r);
    return AuthResult.fromJson(r.data['data']);
  }

  /// 登录后补填邀请码（游客/普通用户通用），复用后端现有邀请码逻辑自动加好友。
  Future<void> bindInviteCode(String code) async {
    final r = await _api.post('/api/v1/invite/bind', data: {
      'code': code,
    });
    _check(r);
  }

  void _check(Response r) {
    final code = r.data['code'];
    if (code != 0) {
      throw Exception(
          r.data['message'] ?? AppLocalizations.instance.t('svcRequestFailed'));
    }
  }
}
