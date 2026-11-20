import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 프로젝트와 공개용(publishable) 키. channel_metrics는 공개 읽기만 열려 있다(쓰기 불가).
class MetricsSource {
  static const url = 'https://pqsyvrohxostuearjeqp.supabase.co';
  static const publishableKey = 'sb_publishable_Hvc19Qg-Vjiq1_dh7ylIUw_Vb-8-yQ5';

  /// start ~ end 사이의 지표를 모두 읽는다(1000줄씩 나눠 받는다).
  static Future<List<MetricRow>> fetch(String start, String end) async {
    final client = Supabase.instance.client;
    final out = <MetricRow>[];
    const page = 1000;
    for (var from = 0;; from += page) {
      final List<dynamic> data = await client
          .from('channel_metrics')
          .select('channel,account_id,metric_date,metric_name,metric_value,collected_at')
          .gte('metric_date', start)
          .lte('metric_date', end)
          .order('metric_date')
          .order('id')
          .range(from, from + page - 1)
          .timeout(const Duration(seconds: 20));
      out.addAll(data.map((e) => MetricRow.fromJson((e as Map).cast<String, dynamic>())));
      if (data.length < page) break;
    }
    return out;
  }
}

class MetricRow {
  const MetricRow({required this.channel, required this.account, required this.date, required this.name, this.value, this.collectedAt});

  factory MetricRow.fromJson(Map<String, dynamic> j) => MetricRow(
        channel: '${j['channel'] ?? ''}',
        account: '${j['account_id'] ?? ''}',
        date: '${j['metric_date'] ?? ''}',
        name: '${j['metric_name'] ?? ''}',
        value: j['metric_value'] == null ? null : num.tryParse('${j['metric_value']}')?.toDouble(),
        collectedAt: j['collected_at'] as String?,
      );

  final String channel;
  final String account;
  final String date;
  final String name;
  final double? value;
  final String? collectedAt;
}

/// 채널과 지표 이름(웹 operation.js와 같다). [이름, 단위]
class Channel {
  const Channel(this.id, this.name, this.delay, this.metrics, this.head);
  final String id;
  final String name;
  final String delay;
  final Map<String, (String, String)> metrics;
  final String head;

  static const all = [
    Channel('youtube', 'YouTube', '1–3일', {
      'views': ('조회수', '회'),
      'watch_minutes': ('시청 시간', '분'),
      'avg_view_duration_sec': ('평균 시청 시간', '초'),
    }, 'views'),
    Channel('google-search', 'Google Search', '2–3일', {
      'impressions': ('노출수', '회'),
      'clicks': ('클릭수', '회'),
    }, 'impressions'),
    Channel('instagram', 'Instagram', '최대 48시간', {
      'views': ('조회수', '회'),
      'reach': ('도달', '명'),
      'profile_views': ('프로필 방문', '회'),
      'website_clicks': ('웹사이트 클릭', '회'),
      'total_interactions': ('반응 합계', '회'),
      'follower_count': ('팔로워 증감', '명'),
    }, 'views'),
  ];

  static Channel byId(String id) => all.firstWhere((c) => c.id == id);
}

// ───────── 날짜(한국 시간 기준 YYYY-MM-DD)

String kstToday() => ymd(DateTime.now().toUtc().add(const Duration(hours: 9)));
String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseYmd(String s) => DateTime.utc(int.parse(s.substring(0, 4)), int.parse(s.substring(5, 7)), int.parse(s.substring(8, 10)));
String offset(String s, int n) => ymd(parseYmd(s).add(Duration(days: n)));
List<String> span(String a, String b) => [for (var d = a; d.compareTo(b) <= 0; d = offset(d, 1)) d];
String dot(String s) => s.substring(5).replaceFirst('-', '.');

/// 수집 시각을 한국 시간 "MM.DD HH:MM"으로.
String short(String? iso) {
  if (iso == null) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final k = t.toUtc().add(const Duration(hours: 9));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(k.month)}.${two(k.day)} ${two(k.hour)}:${two(k.minute)}';
}

String fullTime(String? iso) {
  if (iso == null) return '수집 기록 없음';
  final t = DateTime.tryParse(iso);
  if (t == null) return '수집 기록 없음';
  final k = t.toUtc().add(const Duration(hours: 9));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${k.year}. ${k.month}. ${k.day}. ${two(k.hour)}:${two(k.minute)}:${two(k.second)} KST';
}

/// 1,234.5 꼴. 값이 없으면 —.
String numText(double? n) {
  if (n == null) return '—';
  final r = (n * 10).round() / 10;
  final neg = r < 0;
  final whole = r.abs().truncate();
  final frac = ((r.abs() - whole) * 10).round();
  final s = whole.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '${neg ? '-' : ''}$s${frac > 0 ? '.$frac' : ''}';
}

// ───────── 집계(웹과 같은 규칙)

/// 기간의 지표 합계. 평균 시청 시간은 조회수로 가중 평균한다. 수집된 값이 없으면 null(0과 구분).
double? metricValue(List<MetricRow> rs, String m) {
  final a = rs.where((r) => r.name == m && r.value != null).toList();
  if (a.isEmpty) return null;
  if (m == 'avg_view_duration_sec') {
    var total = 0.0, weights = 0.0;
    for (final r in a) {
      final v = rs.where((x) => x.name == 'views' && x.date == r.date && x.account == r.account && x.value != null).firstOrNull;
      if (v != null && v.value! > 0) {
        total += r.value! * v.value!;
        weights += v.value!;
      }
    }
    return weights > 0 ? total / weights : null;
  }
  return a.fold<double>(0, (s, r) => s + r.value!);
}

List<double?> daily(List<MetricRow> rs, String m, List<String> ds) {
  final byDate = <String, List<MetricRow>>{};
  for (final r in rs) {
    (byDate[r.date] ??= []).add(r);
  }
  return [for (final d in ds) metricValue(byDate[d] ?? const [], m)];
}

String? latest(Iterable<MetricRow> rs) {
  String? best;
  for (final r in rs) {
    final c = r.collectedAt;
    if (c != null && (best == null || c.compareTo(best) > 0)) best = c;
  }
  return best;
}
