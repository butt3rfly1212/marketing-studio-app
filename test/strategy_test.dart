import 'package:dashboard/strategy/brands_page.dart';
import 'package:dashboard/strategy/data.dart';
import 'package:dashboard/strategy/product_page.dart';
import 'package:dashboard/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 휴대폰 크기에서 Strategy 화면과 여섯 탭이 오류 없이 그려지는지 본다.
void main() {
  late StudioData data;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    data = await StudioData.load();
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('브랜드 목록', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(theme: studioTheme(), home: Scaffold(body: BrandsPage(data: data))));
    await tester.pumpAndSettle();
    expect(find.text('브랜드'), findsOneWidget);
    expect(find.text('어나더 13'), findsOneWidget);
  });

  for (final b in ['le-labo', 'lg-43e03880cf']) {
    for (final tab in StrategyTab.all) {
      testWidgets('$b · ${tab.label} 탭', (tester) async {
        await phone(tester);
        final brand = data.brand(b)!;
        final product = asMaps(brand['products']).first;
        await tester.pumpWidget(MaterialApp(theme: studioTheme(), home: ProductPage(data: data, brand: brand, product: product, tab: tab.id)));
        await tester.pumpAndSettle();
        // 펼치는 묶음을 모두 열어 본다(원문 발췌·조서 내용까지 그려지게).
        for (var round = 0; round < 2; round++) {
          final folds = find.byIcon(Icons.chevron_right);
          for (var i = 0; i < folds.evaluate().length && i < 30; i++) {
            final f = folds.at(i);
            if (f.hitTestable().evaluate().isEmpty) continue;
            await tester.tap(f, warnIfMissed: false);
            await tester.pump();
          }
          await tester.drag(find.byType(ListView).first, const Offset(0, -600), warnIfMissed: false);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('근거 필터', (tester) async {
    await phone(tester);
    final brand = data.brand('le-labo')!;
    final product = asMaps(brand['products']).first;
    await tester.pumpWidget(MaterialApp(theme: studioTheme(), home: ProductPage(data: data, brand: brand, product: product)));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^미확인 \d+건')).first);
    await tester.pumpAndSettle();
    expect(find.text('미확인 항목만 보는 중입니다.'), findsOneWidget);
    await tester.tap(find.text('모두 보기'));
    await tester.pumpAndSettle();
    expect(find.text('미확인 항목만 보는 중입니다.'), findsNothing);
  });
}
