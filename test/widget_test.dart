import 'package:dashboard/login_page.dart';
import 'package:dashboard/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('로그인 화면: 제목, 입력칸, 회원가입 전환', (tester) async {
    // 기본 시험 화면(800x600)은 작아서 회원가입 링크가 화면 밖에 놓인다. PC 크기로 맞춘다.
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: studioTheme(), home: const LoginPage()));
    expect(find.text('Marketing\nStudio'), findsOneWidget);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('비밀번호 확인'), findsNothing);

    await tester.tap(find.text('회원가입'));
    await tester.pump();
    expect(find.text('비밀번호 확인'), findsOneWidget);
    expect(find.text('이미 계정이 있으신가요?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '회원가입'));
    await tester.pump();
    expect(find.text('이메일과 비밀번호를 입력해 주세요.'), findsOneWidget);
  });
}
