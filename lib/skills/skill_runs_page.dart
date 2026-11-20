import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../operation/metrics.dart';
import '../theme.dart';

/// 웹 대시보드와 같은 스킬 실행 경로를 쓴다.
/// 앱 → Supabase skill-runs(Firebase 토큰·대표 계정 확인) → PC 중계기 → Happier 세션(고른 PC·폴더).
/// Happier 인증 정보는 앱에 두지 않는다. PC를 Happier에 연결(Accept Connection)하는 일은 그 PC에서 한다.
class SkillRunsApi {
  SkillRunsApi(this.user, {http.Client? client}) : _http = client ?? http.Client();

  final User user;
  final http.Client _http;
  Uri get _uri => Uri.parse('${MetricsSource.url}/functions/v1/skill-runs');

  Future<Map<String, dynamic>> _send(Map<String, dynamic>? body) async {
    final token = await user.getIdToken();
    if (token == null) throw SkillRunsError('로그인 후 이용해 주세요.', 401);
    final headers = {'Authorization': 'Bearer $token', if (body != null) 'Content-Type': 'application/json'};
    final response = await (body == null
            ? _http.get(_uri, headers: headers)
            : _http.post(_uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 15));
    Object? data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      data = null;
    }
    if (response.statusCode >= 400) {
      final message = data is Map && data['error'] is String ? data['error'] as String : '실행 서버에 연결하지 못했습니다.';
      throw SkillRunsError(message, response.statusCode);
    }
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> load() => _send(null);
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) => _send(body);
  void close() => _http.close();
}

class SkillRunsError implements Exception {
  SkillRunsError(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}

/// 고를 수 있는 PC 하나(중계기가 Happier에서 읽어 온 목록).
class RunTarget {
  RunTarget.fromJson(Map<String, dynamic> json)
      : machineId = json['machineId'] as String? ?? '',
        host = json['host'] as String? ?? '',
        online = json['online'] == true,
        self = json['self'] == true,
        root = json['root'] as String?,
        paths = [for (final p in (json['paths'] as List? ?? const [])) if (p is String) p];

  final String machineId, host;
  final bool online, self;
  final String? root;
  final List<String> paths;
}

/// 기본 PC·폴더: 직접 고른 값 → 최근 실행 → 중계기 PC의 최근 폴더 → (그것도 없으면) 켜진 PC 중 무작위.
({RunTarget target, String path})? pickTarget(
  List<RunTarget> targets, {
  ({String machineId, String path})? chosen,
  ({String machineId, String path})? recent,
  Random? random,
}) {
  ({RunTarget target, String path})? valid(({String machineId, String path})? pick) {
    if (pick == null) return null;
    for (final t in targets) {
      if (t.machineId == pick.machineId && t.online && t.paths.contains(pick.path)) return (target: t, path: pick.path);
    }
    return null;
  }

  final online = targets.where((t) => t.online && t.paths.isNotEmpty).toList();
  if (online.isEmpty) return null;
  final fallback = online.firstWhere((t) => t.self, orElse: () => online[(random ?? Random()).nextInt(online.length)]);
  return valid(chosen) ?? valid(recent) ?? (target: fallback, path: fallback.paths.first);
}

String folderName(String path) {
  final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).toList();
  return parts.isEmpty ? path : parts.last;
}

const _status = {
  'queued': '실행 대기', 'checking': '연결 확인 중', 'creating': '세션 생성 중', 'running': '실행 중',
  'building': '대시보드 반영 중', 'publishing': '배포 중', 'done': '완료', 'error': '오류', 'uncertain': '확인 필요',
};
const _busy = {'queued', 'checking', 'creating', 'running', 'building', 'publishing'};

class SkillRunsPage extends StatefulWidget {
  const SkillRunsPage({super.key, required this.user, this.api});

  final User user;
  final SkillRunsApi? api;

  @override
  State<SkillRunsPage> createState() => _SkillRunsPageState();
}

class _SkillRunsPageState extends State<SkillRunsPage> {
  // 앱을 켜 둔 동안 직접 고른 PC·폴더를 기억한다. 다시 열면 서버의 최근 실행이 기본값이 된다.
  static ({String machineId, String path})? _chosen;

  late final SkillRunsApi _api = widget.api ?? SkillRunsApi(widget.user);
  final _instructions = TextEditingController();
  Timer? _timer;
  Map<String, dynamic> _state = const {};
  String? _notice, _skill, _model, _effort;
  bool _loading = true, _submitting = false, _denied = false, _publish = false;
  Map<String, dynamic>? _pending;

  @override
  void initState() {
    super.initState();
    _sync(announce: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.api == null) _api.close();
    _instructions.dispose();
    super.dispose();
  }

  List<RunTarget> get _targets => [
        for (final t in (_state['targets'] as List? ?? const []))
          if (t is Map<String, dynamic>) RunTarget.fromJson(t),
      ];
  List<Map<String, dynamic>> get _runs => [
        for (final r in (_state['runs'] as List? ?? const [])) if (r is Map<String, dynamic>) r,
      ];
  List<Map<String, dynamic>> _list(String key) => [
        for (final r in (_state[key] as List? ?? const [])) if (r is Map<String, dynamic>) r,
      ];

  ({String machineId, String path})? get _recent {
    final r = _state['recentTarget'];
    if (r is Map && r['machineId'] is String && r['path'] is String) {
      return (machineId: r['machineId'] as String, path: r['path'] as String);
    }
    return null;
  }

  ({RunTarget target, String path})? get _pick => pickTarget(_targets, chosen: _chosen, recent: _recent);
  bool get _home {
    final pick = _pick;
    return pick == null || (pick.target.self && pick.target.root == pick.path);
  }

  Future<void> _sync({bool announce = false}) async {
    _timer?.cancel();
    if (announce) setState(() => _notice = 'Happier Cloud 연결을 확인하고 있습니다.');
    try {
      final data = await _api.load();
      if (!mounted) return;
      setState(() {
        _state = data;
        _loading = false;
        if (announce) _notice = null;
        _fillDefaults();
      });
    } on SkillRunsError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _denied = e.status == 401 || e.status == 403;
        _notice = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notice = '실행 서버에 연결하지 못했습니다. 잠시 후 다시 확인해 주세요.';
      });
    }
    if (mounted && !_denied) _timer = Timer(const Duration(seconds: 5), _sync);
  }

  void _fillDefaults() {
    final skills = _list('skills'), models = _list('models');
    if (!skills.any((s) => s['id'] == _skill)) _skill = skills.isEmpty ? null : skills.first['id'] as String?;
    if (!models.any((m) => m['id'] == _model)) _model = models.isEmpty ? null : models.first['id'] as String?;
    final efforts = _efforts;
    if (!efforts.contains(_effort)) _effort = efforts.contains('medium') ? 'medium' : (efforts.isEmpty ? null : efforts.first);
    if (!_home) _publish = false;
  }

  List<String> get _efforts {
    final model = _list('models').where((m) => m['id'] == _model).firstOrNull;
    return [for (final e in (model?['efforts'] as List? ?? const [])) if (e is String) e];
  }

  String get _agent => _list('models').where((m) => m['id'] == _model).firstOrNull?['backend'] == 'claude' ? 'Claude' : 'Codex';

  bool get _canRun =>
      !_submitting &&
      (_pending != null ||
          (_state['ready'] == true && _pick != null && _skill != null && _model != null && _effort != null &&
              !_runs.any((r) => _busy.contains(r['status']))));

  Future<void> _submit() async {
    final pick = _pick;
    if (!_canRun || (pick == null && _pending == null)) return;
    final text = _instructions.text.trim();
    if (_pending == null && text.isEmpty) {
      setState(() => _notice = '스킬에 맡길 작업을 입력해 주세요.');
      return;
    }
    // 응답이 끊겨도 같은 요청 ID로 다시 보내 중복 실행을 막는다.
    _pending ??= {
      'action': 'create', 'id': _uuid(), 'skill': _skill, 'model': _model, 'effort': _effort,
      'instructions': text, 'publish': _publish, 'pcId': 'desktop',
      'machineId': pick!.target.machineId, 'path': pick.path,
    };
    setState(() {
      _submitting = true;
      _notice = '실행 요청을 등록하고 있습니다.';
    });
    try {
      await _api.create(_pending!);
      _pending = null;
      _instructions.clear();
      _notice = null;
    } on SkillRunsError catch (e) {
      if (e.status < 500) _pending = null;
      _notice = _pending != null ? '요청 접수 여부를 확인 중입니다. 다시 누르면 같은 요청으로 확인합니다.' : e.message;
    } catch (_) {
      _notice = '요청 접수 여부를 확인 중입니다. 다시 누르면 같은 요청으로 확인합니다.';
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    await _sync();
  }

  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('스킬 실행하기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _connection(colors),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_notice!, style: TextStyle(color: colors.sub, fontSize: 13)),
              ),
            const SizedBox(height: 16),
            if (!_denied) ...[
              _guide(colors),
              const SizedBox(height: 16),
              _form(colors),
              const SizedBox(height: 24),
              Text('최근 실행', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_runs.isEmpty)
                Text('스킬을 실행하면 이곳에 기록이 남습니다.', style: TextStyle(color: colors.sub))
              else
                for (final run in _runs.take(10)) _runCard(run, colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _connection(StudioColors colors) {
    final ready = _state['ready'] == true;
    final pick = _pick;
    final text = _loading
        ? '연결 확인 중'
        : ready
            ? '연결됨 · ${pick?.target.host ?? '중계기 PC'}'
            : 'Happier Cloud 준비 상태를 확인할 수 없습니다.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.sheet, borderRadius: studioCard),
      child: Row(
        children: [
          Icon(ready ? Icons.circle : Icons.circle_outlined, size: 12, color: ready ? colors.ink : colors.accentText),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => _sync(announce: true), child: const Text('연결 다시 확인')),
        ],
      ),
    );
  }

  Widget _guide(StudioColors colors) {
    const steps = [
      '실행할 PC에서 Happier를 설치하고 happier setup을 실행합니다.',
      '열린 화면에서 이 PC와 같은 Happier 계정으로 로그인한 뒤 Accept Connection을 누릅니다.',
      '앱으로 돌아와 연결 다시 확인을 누릅니다. 새 PC와 폴더는 최대 5분 안에 목록에 나타납니다.',
    ];
    return Container(
      decoration: BoxDecoration(color: colors.sheet, borderRadius: studioCard),
      child: ExpansionTile(
        initiallyExpanded: _targets.isEmpty && !_loading,
        shape: const Border(),
        title: const Text('새 PC 연결하기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 22, child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(child: Text(steps[i], style: TextStyle(color: colors.sub, height: 1.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _select<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey('$label:$value:${items.length}'),
      initialValue: items.any((i) => i.value == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: _pending != null || _submitting ? null : onChanged,
    );
  }

  Widget _form(StudioColors colors) {
    final pick = _pick;
    final targets = _targets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _select<String>(
          label: '실행 PC',
          value: pick?.target.machineId,
          items: [
            for (final t in targets)
              DropdownMenuItem(
                value: t.machineId,
                enabled: t.online && t.paths.isNotEmpty,
                child: Text('${t.host}${t.self ? ' · 중계기 PC' : ''}${t.online ? '' : ' · 꺼짐'}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            final t = targets.where((x) => x.machineId == id).firstOrNull;
            if (t != null) setState(() => _chosen = (machineId: t.machineId, path: t.paths.first));
          },
        ),
        _select<String>(
          label: '폴더',
          value: pick?.path,
          items: [
            for (final p in pick?.target.paths ?? const <String>[])
              DropdownMenuItem(value: p, child: Text('${folderName(p)} · $p', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (p) {
            if (pick != null && p != null) setState(() => _chosen = (machineId: pick.target.machineId, path: p));
          },
        ),
        if (!_home)
          Text('이 폴더에도 같은 스킬(.agents/skills)이 있어야 합니다. 대시보드 재생성·배포는 하지 않습니다.',
              style: TextStyle(color: colors.sub, fontSize: 13)),
        _select<String>(
          label: '스킬',
          value: _skill,
          items: [
            for (final s in _list('skills'))
              DropdownMenuItem(value: s['id'] as String, child: Text('${s['label'] ?? s['id']}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _skill = v),
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              flex: 2,
              child: _select<String>(
                label: '모델',
                value: _model,
                items: [
                  for (final m in _list('models'))
                    DropdownMenuItem(value: m['id'] as String, child: Text('${m['label'] ?? m['id']}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() {
                  _model = v;
                  _fillDefaults();
                }),
              ),
            ),
            Expanded(
              child: _select<String>(
                label: 'Effort',
                value: _effort,
                items: [for (final e in _efforts) DropdownMenuItem(value: e, child: Text(e))],
                onChanged: (v) => setState(() => _effort = v),
              ),
            ),
          ],
        ),
        TextField(
          controller: _instructions,
          enabled: _pending == null && !_submitting,
          maxLength: 4000,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: '작업 요청', hintText: '예: 어나더 13의 새 고객 후기를 조사해서 브리프를 갱신해 주세요.'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _publish,
          onChanged: _home && _pending == null ? (v) => setState(() => _publish = v ?? false) : null,
          title: const Text('산출물 변경 시 검증 후 Hosting 배포', style: TextStyle(fontSize: 15)),
        ),
        FilledButton(
          onPressed: _canRun ? _submit : null,
          child: Text(_submitting ? '요청 확인 중…' : _pending != null ? '같은 요청 확인' : '$_agent에서 실행'),
        ),
      ],
    );
  }

  Widget _runCard(Map<String, dynamic> run, StudioColors colors) {
    final status = run['status'] as String? ?? 'error';
    final session = run['session_id'] as String?;
    final label = status == 'running' && session == null ? _status['creating']! : _status[status] ?? _status['error']!;
    final host = _targets.where((t) => t.machineId == run['machine_id']).firstOrNull?.host;
    final where = run['path'] is String ? '${host ?? 'Happier PC'} · ${folderName(run['path'] as String)}' : null;
    final skill = _list('skills').where((s) => s['id'] == run['skill']).firstOrNull?['label'] ?? run['skill'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.sheet, borderRadius: studioCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            children: [
              Expanded(child: Text('$skill', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(label, style: TextStyle(color: _busy.contains(status) || status == 'error' ? colors.accentText : colors.sub)),
            ],
          ),
          Text([where, run['model'], run['effort']].whereType<String>().join(' · '),
              style: TextStyle(color: colors.sub, fontSize: 13)),
          if (run['detail'] is String) Text(run['detail'] as String, style: const TextStyle(fontSize: 13)),
          if (run['result'] is String) Text(run['result'] as String),
          if (session != null && RegExp(r'^[a-zA-Z0-9-]{8,100}$').hasMatch(session))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri.https('cloud.happier.dev', '/session/$session'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Happier 세션 열기'),
              ),
            ),
        ],
      ),
    );
  }
}
