import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../operation/metrics.dart';
import 'office_native.dart' if (dart.library.js_interop) 'office_web.dart';

class OfficePage extends StatefulWidget {
  const OfficePage({super.key, required this.user, required this.active});

  final User user;
  final bool active;

  @override
  State<OfficePage> createState() => _OfficePageState();
}

class _OfficePageState extends State<OfficePage> {
  static const _meetingOrigins = {
    'https://ai-marketing-66997.web.app',
    'https://ai-marketing-66997.firebaseapp.com',
    'http://127.0.0.1:8000',
    'http://localhost:8000',
  };
  late final Future<String> _markup = rootBundle.loadString('assets/office/index.html');
  final _http = http.Client();
  bool get _canConnectMeeting => !kIsWeb || _meetingOrigins.contains(Uri.base.origin);

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<String?> _message(String message) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (!mounted || decoded is! Map || decoded['office'] != true || decoded['id'] is! int) return null;
    final id = decoded['id'];
    String reply(int status, {Object? data, String? error}) =>
        jsonEncode({'id': id, 'status': status, 'data': data, 'error': error});
    try {
      switch (decoded['route']) {
        case 'identity':
          return reply(200, data: {'email': _canConnectMeeting ? widget.user.email : null});
        case 'metrics':
          final range = decoded['body'];
          if (range is! Map || !_isDate(range['start']) || !_isDate(range['end'])) {
            return reply(400, error: '잘못된 날짜 범위입니다.');
          }
          final rows = await MetricsSource.fetch(range['start'] as String, range['end'] as String);
          return reply(
            200,
            data: [
              for (final row in rows)
                {'channel': row.channel, 'metric_date': row.date, 'metric_name': row.name, 'metric_value': row.value},
            ],
          );
        case 'skills':
        case 'meeting':
          if (decoded['route'] == 'meeting' && !_canConnectMeeting) {
            return reply(403, error: '이 주소에서는 AI 회의에 연결할 수 없습니다.');
          }
          final token = await widget.user.getIdToken();
          if (token == null) return reply(401, error: '로그인 후 이용해 주세요.');
          final name = decoded['route'] == 'skills' ? 'skill-runs' : 'office-live';
          final uri = Uri.parse('${MetricsSource.url}/functions/v1/$name');
          final body = decoded['body'];
          if (body != null && body is! Map) return reply(400, error: '잘못된 요청입니다.');
          final headers = {'Authorization': 'Bearer $token'};
          final response =
              await (body == null
                      ? _http.get(uri, headers: headers)
                      : _http.post(
                          uri,
                          headers: {...headers, 'Content-Type': 'application/json'},
                          body: jsonEncode(body),
                        ))
                  .timeout(const Duration(seconds: 15));
          Object? data;
          try {
            data = jsonDecode(utf8.decode(response.bodyBytes));
          } on FormatException {
            data = null;
          }
          if (response.statusCode >= 400) {
            return reply(
              response.statusCode,
              error: data is Map && data['error'] is String ? data['error'] as String : '작업 공간 서버에 연결하지 못했습니다.',
            );
          }
          return reply(response.statusCode, data: data);
        case 'open':
          final body = decoded['body'];
          final uri = body is String ? Uri.tryParse(body) : null;
          if (uri == null || uri.scheme != 'https' || uri.host != 'cloud.happier.dev' || uri.userInfo.isNotEmpty) {
            return reply(400, error: '열 수 없는 링크입니다.');
          }
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return reply(200);
        default:
          return reply(400, error: '지원하지 않는 요청입니다.');
      }
    } catch (_) {
      return reply(503, error: '작업 공간 데이터를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  bool _isDate(Object? value) =>
      value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) && DateTime.tryParse(value) != null;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _markup,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('작업 공간 화면을 불러오지 못했습니다.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return OfficeSurface(
          markup: snapshot.data!,
          active: widget.active,
          theme: Theme.of(context).brightness.name,
          onMessage: _message,
        );
      },
    );
  }
}
