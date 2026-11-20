import 'package:dashboard/operation/metrics.dart';
import 'package:dashboard/operation/operation_page.dart';
import 'package:dashboard/operation/operation_store.dart';
import 'package:dashboard/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 실제 Supabase 대신 합성 지표로 Operation 화면과 집계 규칙을 확인한다.
void main() {
  List<MetricRow> synthetic(String start, String end) {
    final out = <MetricRow>[];
    var i = 0;
    for (final d in span(start, end)) {
      i++;
      if (i % 6 == 0) continue; // 하루씩 비워 '미수집'을 만든다
      MetricRow r(String c, String a, String m, double v) =>
          MetricRow(channel: c, account: a, date: d, name: m, value: v, collectedAt: '2026-11-18T00:00:00Z');
      out.addAll([
        r('youtube', 'UC1', 'views', 100.0 + i * 7),
        r('youtube', 'UC1', 'watch_minutes', 30.0 + i),
        r('youtube', 'UC1', 'avg_view_duration_sec', 40),
        r('google-search', 'site', 'impressions', 500.0 + (i % 4) * 300),
        r('google-search', 'site', 'clicks', 12.0 + i % 3),
        r('instagram', 'ig1', 'views', 800.0 + i * 3),
        r('instagram', 'ig2', 'views', 50),
        r('instagram', 'ig1', 'reach', 300),
        r('instagram', 'ig1', 'follower_count', i.isEven ? 2 : -1),
      ]);
    }
    return out;
  }

  test('평균 시청 시간은 조회수 가중 평균, 미수집은 null', () {
    const rows = [
      MetricRow(channel: 'youtube', account: 'a', date: '2026-11-01', name: 'views', value: 100),
      MetricRow(channel: 'youtube', account: 'a', date: '2026-11-01', name: 'avg_view_duration_sec', value: 10),
      MetricRow(channel: 'youtube', account: 'a', date: '2026-11-02', name: 'views', value: 300),
      MetricRow(channel: 'youtube', account: 'a', date: '2026-11-02', name: 'avg_view_duration_sec', value: 30),
    ];
    expect(metricValue(rows, 'avg_view_duration_sec'), 25);
    expect(metricValue(rows, 'views'), 400);
    expect(metricValue(rows, 'clicks'), isNull);
    expect(numText(1234567.25), '1,234,567.3');
  });

  // 채널 카드(위 합계에도 같은 글이 있어서 카드의 Semantics 이름으로 찾는다).
  Finder card(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('채널 성과 화면: 지도, 카드, 지표, 차트, 상세 기록', (tester) async {
    await phone(tester);
    final store = OperationStore(loader: (a, b) async => synthetic(a, b));
    await tester.pumpWidget(MaterialApp(theme: studioTheme(), home: Scaffold(body: OperationView(store: store))));
    await tester.pump(const Duration(seconds: 2)); // 궤도 그림은 계속 돌아서 pumpAndSettle을 쓰지 않는다
    expect(store.status, OpStatus.ready);
    expect(find.text('날짜별 성과 지도'), findsOneWidget);

    // 30일로 바꾸기
    await tester.tap(find.text('30일'));
    await tester.pump(const Duration(seconds: 2));
    expect(store.dates.length, 30);

    // Instagram 카드 → 계정 고르기와 지표 칩이 나온다
    await tester.scrollUntilVisible(card('Instagram 선택'), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(card('Instagram 선택'));
    await tester.pump();
    await tester.tap(card('Instagram 선택'));
    await tester.pump(const Duration(seconds: 2));
    expect(store.selected, 'instagram');
    await tester.scrollUntilVisible(find.text('팔로워 증감'), 200);
    await tester.tap(find.text('팔로워 증감'));
    await tester.pump(const Duration(seconds: 2));
    expect(store.metric, 'follower_count');
    expect(find.text('모든 계정'), findsOneWidget);

    // Google Search는 클릭률이 붙는다
    await tester.scrollUntilVisible(card('Google Search 선택'), -200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(card('Google Search 선택'));
    await tester.pump();
    await tester.tap(card('Google Search 선택'));
    await tester.pump(const Duration(seconds: 2));
    await tester.scrollUntilVisible(find.text('클릭률'), 200);

    // 슬라이더로 날짜 보기, 상세 기록 펼치기
    await tester.scrollUntilVisible(find.byType(Slider), 200);
    await tester.ensureVisible(find.byType(Slider));
    await tester.pump();
    await tester.drag(find.byType(Slider), const Offset(-120, 0));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('노출수'), findsWidgets);
    await tester.scrollUntilVisible(find.text('날짜별 상세 기록 펼쳐 보기'), 200);
    await tester.tap(find.text('날짜별 상세 기록 펼쳐 보기'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('수집 시각 (KST)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('불러오기 실패와 빈 기간', (tester) async {
    await phone(tester);
    final failing = OperationStore(loader: (a, b) async => throw Exception('x'));
    await tester.pumpWidget(MaterialApp(theme: studioTheme(), home: Scaffold(body: OperationView(store: failing))));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('지표를 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    final empty = OperationStore(loader: (a, b) async => const []);
    await tester.pumpWidget(MaterialApp(theme: studioTheme(), home: Scaffold(body: OperationView(store: empty))));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('선택한 기간에 수집된 데이터가 없습니다'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
