import 'package:dio/dio.dart';

import 'api_client.dart';

class FriendRequest {
  final String id; // 字符串 ID（H5 精度安全）
  final String fromUser;
  final String message;
  final int status;

  FriendRequest.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString() ?? '',
        fromUser = j['fromUser']?.toString() ?? '',
        message = j['message']?.toString() ?? '',
        status = (j['status'] as num?)?.toInt() ?? 0;
}

class FriendService {
  final Dio _dio = ApiClient.instance.dio;
  final _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> list() async {
    final r = await _dio.get('/api/v1/friend/list',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> search(String kw) async {
    final r = await _dio.get('/api/v1/user/search',
        queryParameters: {'kw': kw},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<FriendRequest>> incoming() async {
    final r = await _dio.get('/api/v1/friend/request/incoming',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 所有 ID 参数为 String（雪花精度安全）
  Future<bool> request(String toId, {String message = ''}) async {
    final r = await _dio.post('/api/v1/friend/request',
        data: {'toId': toId, 'message': message},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> handle(String reqId, bool agree) async {
    final r = await _dio.post('/api/v1/friend/request/$reqId/handle?agree=${agree ? 1 : 0}',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> delete(String friendId) async {
    final r = await _dio.delete('/api/v1/friend/$friendId',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> setRemark(String friendId, String remark) async {
    final r = await _dio.put('/api/v1/friend/$friendId/remark',
        data: {'remark': remark},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> blacklistAdd(String blockId) async {
    final r = await _dio.post('/api/v1/friend/blacklist',
        data: {'blockId': blockId},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<Map<String, dynamic>> profile() async {
    final r = await _dio.get('/api/v1/user/profile',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  /// 更新资料（昵称/签名/头像）
  Future<bool> updateProfile({String? nickname, String? bio, String? avatar}) async {
    final data = <String, dynamic>{};
    if (nickname != null && nickname.isNotEmpty) data['nickname'] = nickname;
    if (bio != null) data['bio'] = bio;
    if (avatar != null && avatar.isNotEmpty) data['avatar'] = avatar;
    final r = await _dio.put('/api/v1/user/profile',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }
}
