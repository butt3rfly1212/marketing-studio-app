import 'dart:math';

import 'package:dashboard/skills/skill_runs_page.dart';
import 'package:flutter_test/flutter_test.dart';

RunTarget target(String id, {bool online = true, bool self = false, List<String> paths = const ['C:/repo', 'C:/work']}) =>
    RunTarget.fromJson({'machineId': id, 'host': id, 'online': online, 'self': self, 'root': self ? 'C:/repo' : null, 'paths': paths});

void main() {
  final office = target('office', self: true), laptop = target('laptop', paths: const ['/home/app']);

  test('직접 고른 PC·폴더가 가장 먼저', () {
    final pick = pickTarget([office, laptop], chosen: (machineId: 'laptop', path: '/home/app'), recent: (machineId: 'office', path: 'C:/work'));
    expect(pick?.target.machineId, 'laptop');
    expect(pick?.path, '/home/app');
  });

  test('고른 값이 없으면 최근 실행한 PC·폴더', () {
    final pick = pickTarget([office, laptop], recent: (machineId: 'office', path: 'C:/work'));
    expect((pick?.target.machineId, pick?.path), ('office', 'C:/work'));
  });

  test('꺼진 PC나 목록에 없는 폴더는 건너뛰고 중계기 PC의 최근 폴더', () {
    final off = target('laptop', online: false, paths: const ['/home/app']);
    final pick = pickTarget([office, off], chosen: (machineId: 'laptop', path: '/home/app'), recent: (machineId: 'office', path: 'D:/gone'));
    expect((pick?.target.machineId, pick?.path), ('office', 'C:/repo'));
  });

  test('기록이 없고 중계기 PC도 없으면 켜진 PC 중 무작위', () {
    final a = target('a'), b = target('b');
    final pick = pickTarget([a, b], random: Random(1));
    expect(['a', 'b'], contains(pick?.target.machineId));
    expect(pickTarget([target('x', online: false)]), isNull);
  });

  test('폴더 이름', () {
    expect(folderName(r'C:\Users\133\Desktop\butt3rfly-inc'), 'butt3rfly-inc');
    expect(folderName('/home/me/app/'), 'app');
  });
}
