import 'dart:async';

import 'package:flutter/foundation.dart';

import 'metrics.dart';

typedef MetricsLoader = Future<List<MetricRow>> Function(String start, String end);

enum OpStatus { idle, loading, ready, error }

/// Operation 화면 상태: 기간, 고른 채널·계정·지표, 불러온 지표.
/// 대시보드가 들고 있어서 Strategy·Contents로 갔다 와도 그대로다.
class OperationStore extends ChangeNotifier {
  OperationStore({MetricsLoader? loader}) : _loader = loader ?? MetricsSource.fetch {
    end = kstToday();
    start = offset(end, -6);
  }

  final MetricsLoader _loader;
  int _generation = 0;

  List<MetricRow> rows = [];
  OpStatus status = OpStatus.idle;
  String error = '';
  late String start;
  late String end;
  int days = 7;
  bool custom = false;
  String selected = 'youtube';
  String account = '';
  String metric = 'views';

  /// 지도에서 날짜를 누르면 차트가 그 날짜를 가리킨다.
  String? pinnedDate;
  int pinSerial = 0;

  List<String> get dates => span(start, end);
  Channel get channel => Channel.byId(selected);

  /// 바로 앞 같은 길이 기간(비교용). 너무 길면 비교하지 않는다.
  (String, String)? get prevRange {
    final n = dates.length;
    return n * 2 <= 732 ? (offset(start, -n), offset(start, -1)) : null;
  }

  bool within(MetricRow r, String a, String b) => r.date.compareTo(a) >= 0 && r.date.compareTo(b) <= 0;

  List<MetricRow> subset(String c, {bool allAccounts = false}) =>
      rows.where((r) => r.channel == c && within(r, start, end) && (allAccounts || account.isEmpty || r.account == account)).toList();

  List<String> get accounts => rows.where((r) => r.channel == selected && r.account.isNotEmpty).map((r) => r.account).toSet().toList()..sort();

  bool get hasDataInRange => rows.any((r) => within(r, start, end));

  Future<void> load() async {
    final id = ++_generation;
    status = OpStatus.loading;
    error = '';
    notifyListeners();
    final pr = prevRange;
    try {
      final data = await _loader(pr?.$1 ?? start, end);
      if (id != _generation) return;
      rows = data;
      status = OpStatus.ready;
    } on TimeoutException {
      if (id != _generation) return;
      rows = [];
      status = OpStatus.error;
      error = '응답이 지연되고 있습니다. 잠시 후 새로고침해 주세요.';
    } catch (_) {
      if (id != _generation) return;
      rows = [];
      status = OpStatus.error;
      error = '지표 서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    notifyListeners();
  }

  void ensureLoaded() {
    if (status == OpStatus.idle) unawaited(load());
  }

  void setPreset(int n) {
    days = n;
    custom = false;
    end = kstToday();
    start = offset(end, 1 - n);
    unawaited(load());
  }

  /// 직접 설정한 기간. 문제가 있으면 안내 문구를 돌려준다.
  String? setCustom(String a, String b) {
    final today = kstToday();
    if (a.compareTo(b) > 0) return '시작일이 종료일보다 늦습니다.';
    if (b.compareTo(today) > 0) return '오늘 이후 날짜는 고를 수 없습니다.';
    if (parseYmd(b).difference(parseYmd(a)).inDays > 365) return '최대 366일까지 고를 수 있습니다.';
    custom = true;
    days = 0;
    start = a;
    end = b;
    unawaited(load());
    return null;
  }

  void selectChannel(String c, {String? pinDate}) {
    selected = c;
    account = '';
    metric = Channel.byId(c).head;
    if (pinDate != null) {
      pinnedDate = pinDate;
      pinSerial++;
    }
    notifyListeners();
  }

  void selectAccount(String a) {
    account = a;
    notifyListeners();
  }

  void selectMetric(String m) {
    metric = m;
    notifyListeners();
  }

  /// 로그아웃하면 지운다.
  void reset() {
    _generation++;
    rows = [];
    status = OpStatus.idle;
    notifyListeners();
  }
}
