import 'package:dashboard/contents/contents_page.dart';
import 'package:dashboard/contents/drive_store.dart';
import 'package:dashboard/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 휴대폰 크기에서 Contents 화면(연결 전, 폴더, 하위 폴더, 폴더 트리)이 오류 없이 그려지는지 본다.
/// 실제 Drive에 접속하지 않고, 불러온 결과만 흉내 낸다.
void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(DriveStore store) => MaterialApp(
        theme: studioTheme(),
        home: Scaffold(body: ContentsView(store: store, navKey: GlobalKey<NavigatorState>())),
      );

  DriveStore loaded() {
    final s = DriveStore();
    DriveFile add(String id, String name, String mime, String? parent, {int size = 0}) {
      final f = DriveFile({'id': id, 'name': name, 'mimeType': mime, 'size': '$size', 'modifiedTime': '2026-11-18T10:00:00Z'}, parent: parent);
      s.items[id] = f;
      if (parent != null) (s.children[parent] ??= []).add(id);
      return f;
    }

    s.root = add(rootFolderId, '02-contents', folderMime, null);
    add('a', '르라보 어나더 13 광고 이미지 아주 긴 폴더 이름이 들어가도 줄바꿈 확인', folderMime, rootFolderId);
    add('b', '릴스', folderMime, rootFolderId);
    add('c', 'brief.pdf', 'application/pdf', rootFolderId, size: 2400000);
    add('a1', 'ads-12.png', 'image/png', 'a', size: 830000);
    add('a2', 'reel-1-final-version-very-long-file-name.mp4', 'video/mp4', 'a', size: 48000000);
    add('a3', '카피 정리', 'application/vnd.google-apps.document', 'a');
    s.children['b'] = [];
    s.folders = 2;
    s.files = 4;
    s.status = DriveStatus.ready;
    s.loadedAt = DateTime(2026, 11, 19, 15, 4);
    return s;
  }

  testWidgets('연결 전 안내', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(DriveStore()));
    await tester.pumpAndSettle();
    expect(find.text('Google Drive를 연결해 주세요'), findsOneWidget);
    expect(find.text('Google Drive 연결'), findsOneWidget);
    expect(find.text('연결 안 됨'), findsOneWidget);
  });

  testWidgets('루트 폴더 → 하위 폴더 → 빈 폴더, 폴더 트리', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(loaded()));
    await tester.pumpAndSettle();
    expect(find.text('폴더'), findsOneWidget);
    expect(find.text('파일'), findsOneWidget);
    expect(find.text('brief.pdf'), findsOneWidget);
    expect(find.textContaining('파일 3'), findsOneWidget); // a 폴더 안 파일 수

    await tester.tap(find.textContaining('르라보 어나더 13'));
    await tester.pumpAndSettle();
    expect(find.text('ads-12.png'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byTooltip('폴더 트리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('릴스').last);
    await tester.pumpAndSettle();
    expect(find.text('이 폴더는 비어 있습니다'), findsOneWidget);

    await tester.tap(find.byTooltip('상위 폴더'));
    await tester.pumpAndSettle();
    expect(find.text('brief.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
