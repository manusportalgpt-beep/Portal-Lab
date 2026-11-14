import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'net.dart';

/// Microsoft / Xbox Live / Minecraft Services authentication.
///
/// Uses the OAuth 2.0 device-code flow with the public client ID published by
/// Prism Launcher (open-source launcher), exactly like Prism's own
/// "device code" login mode.
class MsaService {
  static const clientId = 'c36a9fb6-4f2a-41ff-90bd-ae7cc92031eb';
  static const tenant = 'consumers';
  static const scope = 'XboxLive.SignIn XboxLive.offline_access';

  static String get deviceCodeUrl =>
      'https://login.microsoftonline.com/$tenant/oauth2/v2.0/devicecode';
  static String get tokenUrl =>
      'https://login.microsoftonline.com/$tenant/oauth2/v2.0/token';

  static Future<DeviceCode> startDeviceCode() async {
    final r = await http.post(Uri.parse(deviceCodeUrl), body: {
      'client_id': clientId,
      'scope': scope,
    }).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw Exception('device code failed: ${r.statusCode}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return DeviceCode(
      deviceCode: j['device_code'] as String,
      userCode: j['user_code'] as String,
      verificationUrl: j['verification_uri'] as String,
      interval: (j['interval'] as num?)?.toInt() ?? 5,
      expiresAt: DateTime.now()
          .add(Duration(seconds: (j['expires_in'] as num).toInt())),
    );
  }

  /// Poll until the user authorizes, then run the full Xbox/MC chain.
  static Future<McAccount> login(DeviceCode dc) async {
    final tokens = await _pollTokens(dc);
    return await completeLogin(tokens['access_token'] as String,
        refreshToken: tokens['refresh_token'] as String?,
        expiresIn: (tokens['expires_in'] as num?)?.toInt() ?? 0);
  }

  static Future<Map<String, dynamic>> _pollTokens(DeviceCode dc) async {
    while (DateTime.now().isBefore(dc.expiresAt)) {
      await Future.delayed(Duration(seconds: dc.interval));
      final r = await http.post(Uri.parse(tokenUrl), body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'client_id': clientId,
        'device_code': dc.deviceCode,
      }).timeout(const Duration(seconds: 20));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 200) return j;
      final err = j['error'] as String?;
      if (err == 'authorization_pending' || err == 'slow_down') continue;
      throw Exception('MSA: ${j['error_description'] ?? err}');
    }
    throw Exception('MSA device code expired');
  }

  /// Refresh an access token with the stored refresh token.
  /// Returns null when the refresh token is no longer valid.
  static Future<McAccount?> refresh(McAccount acc) async {
    if (acc.refreshToken == null) return null;
    try {
      final r = await http.post(Uri.parse(tokenUrl), body: {
        'grant_type': 'refresh_token',
        'client_id': clientId,
        'refresh_token': acc.refreshToken,
        'scope': scope,
      }).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final fresh = await completeLogin(j['access_token'] as String,
          refreshToken: j['refresh_token'] as String?,
          expiresIn: (j['expires_in'] as num?)?.toInt() ?? 0);
      fresh.uuid = acc.uuid;
      return fresh;
    } catch (_) {
      return null;
    }
  }

  /// access_token -> XBL -> XSTS -> Minecraft services -> profile.
  static Future<McAccount> completeLogin(String accessToken,
      {String? refreshToken, int expiresIn = 0}) async {
    // 1. Xbox Live user token
    final xbl = await _postJson(
      'https://user.auth.xboxlive.com/user/authenticate',
      {
        'Properties': {
          'AuthMethod': 'RPS',
          'SiteName': 'user.auth.xboxlive.com',
          'RpsTicket': 'd=$accessToken',
        },
        'RelyingParty': 'http://auth.xboxlive.com',
        'TokenType': 'JWT',
      },
    );
    final xblToken = xbl['Token'] as String;
    final xblUhs =
        (((xbl['DisplayClaims'] as Map)['xui'] as List).first as Map)['uhs']
            as String;

    // 2. XSTS token
    final xsts = await _postJson(
      'https://xsts.auth.xboxlive.com/xsts/authorize',
      {
        'Properties': {
          'SandboxId': 'RETAIL',
          'UserTokens': [xblToken],
        },
        'RelyingParty': 'rp://api.minecraftservices.com/',
        'TokenType': 'JWT',
      },
    );
    final xstsToken = xsts['Token'] as String;

    // 3. Minecraft login with Xbox
    final mc = await _postJson(
      'https://api.minecraftservices.com/authentication/login_with_xbox',
      {'identityToken': 'XBL3.0 u=$xblUhs;$xstsToken'},
    );
    final mcToken = mc['access_token'] as String;

    // 4. Profile
    final prof = await Net.getJson(
        'https://api.minecraftservices.com/minecraft/profile',
        headers: {'Authorization': 'Bearer $mcToken'});

    String? skinUrl;
    String? skinModel;
    final skins = (prof['skins'] as List?) ?? const [];
    for (final s in skins) {
      final sm = s as Map<String, dynamic>;
      if (sm['state'] == 'ACTIVE') {
        skinUrl = sm['url'] as String?;
        final v = sm['variant'] as String?;
        skinModel = (v == null || v.isEmpty) ? null : v.toLowerCase();
        break;
      }
    }

    return McAccount(
      uuid: prof['id'] as String,
      username: prof['name'] as String,
      type: 'msa',
      accessToken: mcToken,
      refreshToken: refreshToken,
      tokenExpiresAt: DateTime.now()
          .add(Duration(seconds: expiresIn > 0 ? expiresIn : 86400))
          .millisecondsSinceEpoch,
      skinUrl: skinUrl,
      skinModel: skinModel,
      xuid: xblUhs,
    );
  }

  static Future<Map<String, dynamic>> _postJson(String url, Object body) async {
    final r = await http
        .post(Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) {
      throw Exception('auth step failed (${r.statusCode}): ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

class DeviceCode {
  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final int interval;
  final DateTime expiresAt;
  DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.interval,
    required this.expiresAt,
  });
}
