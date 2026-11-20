import 'dart:convert';

import 'package:flutter/services.dart';

/// 프로필 JSON을 그대로 다루기 위한 짧은 이름.
typedef Json = Map<String, dynamic>;

Json asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
List<Json> asMaps(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
List<dynamic> asList(Object? v) => v is List ? v : const [];
String str(Object? v) => v == null ? '' : '$v';

/// 근거 수준. 웹 대시보드(app.js LEVELS)와 같은 이름과 설명.
class Level {
  const Level(this.id, this.label, [this.desc]);
  final String id;
  final String label;
  final String? desc;

  static const all = {
    'confirmed': Level('confirmed', '확인', '출처 문서와 대조 완료'),
    'hypothesis': Level('hypothesis', '가설', '근거에서 도출, 검증 전'),
    'unconfirmed': Level('unconfirmed', '미확인', '근거 없음, 조사 필요'),
    'expired': Level('expired', '기한 지남', '시점 정보가 만료됨'),
    'draft': Level('draft', '초안'),
    'review': Level('review', '검토'),
    'final': Level('final', '확정'),
  };
  static const findingLevels = ['confirmed', 'hypothesis', 'unconfirmed', 'expired'];

  static String labelOf(String? id) => all[id]?.label ?? (id ?? '');
}

/// Strategy 탭. TAB_DOC: 탭마다 '원본 보기'로 여는 문서 키.
class StrategyTab {
  const StrategyTab(this.id, this.label, this.doc);
  final String id;
  final String label;
  final String doc;

  static const all = [
    StrategyTab('summary', '요약', 'messages'),
    StrategyTab('brand', '브랜드', 'brand'),
    StrategyTab('product', '상품', 'product'),
    StrategyTab('competitor', '경쟁', 'competitor'),
    StrategyTab('customer', '고객', 'customer'),
    StrategyTab('brief', '브리프', 'brief'),
  ];
  static int indexOf(String? id) {
    final i = all.indexWhere((t) => t.id == id);
    return i < 0 ? 0 : i;
  }
}

/// 마크다운 링크가 가리키는 곳.
class LinkTarget {
  const LinkTarget.external(this.url) : kind = 'external', path = null, fragment = null;
  const LinkTarget.doc(this.path, this.fragment) : kind = 'doc', url = null;
  const LinkTarget.asset(this.path) : kind = 'asset', url = null, fragment = null;
  const LinkTarget.fragment(this.fragment) : kind = 'fragment', url = null, path = null;
  final String kind;
  final String? url;
  final String? path;
  final String? fragment;
}

/// 앱에 묶인 Strategy 자료(assets/strategy/strategy.json). tool/export_strategy.py가 만든다.
class StudioData {
  StudioData(Json raw)
      : generatedAt = str(raw['generatedAt']),
        brands = asMaps(raw['brands']),
        products = asMap(raw['products']),
        documents = asMap(raw['documents']),
        assets = asMap(raw['assets']);

  final String generatedAt;
  final List<Json> brands;
  final Json products;
  final Json documents;
  final Json assets;

  static Future<StudioData>? _loading;
  static Future<StudioData> load() => _loading ??= rootBundle
      .loadString('assets/strategy/strategy.json')
      .then((text) => StudioData(asMap(jsonDecode(text))));

  // ───────── 조회
  Json? brand(String id) => brands.where((b) => b['id'] == id).firstOrNull;
  Json? product(Json brand, String id) => asMaps(brand['products']).where((p) => p['id'] == id).firstOrNull;
  Json? view(Json brand, Json product) {
    final v = products['${brand['id']}/${product['id']}'];
    return v is Map ? v.cast<String, dynamic>() : null;
  }

  static String normalizePath(String p) {
    final parts = <String>[];
    for (final part in p.replaceAll('\\', '/').split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }

  static String fileName(String? p) => p == null ? '' : p.split('/').last;

  static String? lookup(Json map, String? key) {
    if (key == null || key.isEmpty) return null;
    if (map.containsKey(key)) return key;
    final n = normalizePath(key);
    for (final k in map.keys) {
      if (normalizePath(k) == n) return k;
    }
    return null;
  }

  /// 그림의 앱 자산 경로. 없으면 null.
  String? asset(String? path) {
    final k = lookup(assets, path);
    return k == null ? null : str(assets[k]);
  }

  /// 문서 키('brand', 'product' …)나 경로를 실제 문서 경로로 바꾼다.
  String? docPath(String? keyOrPath, Json? view, [Json? brand]) {
    if (keyOrPath == null || keyOrPath.isEmpty) return null;
    final direct = lookup(documents, keyOrPath);
    if (direct != null) return direct;
    final mapped = asMap(view?['documents'])[keyOrPath];
    if (mapped != null) return lookup(documents, str(mapped));
    final bd = asMap(brand?['documents'])[keyOrPath];
    if (bd != null) return lookup(documents, str(bd));
    return null;
  }

  String docTitle(String path) => str(asMap(documents[path])['title']).isEmpty ? fileName(path) : str(asMap(documents[path])['title']);
  String docBody(String path) => str(asMap(documents[path])['body']);

  // ───────── 조서
  static List<Json> findings(Json? view) => asMaps(asMap(view?['strategy'])['findings']);
  static List<Json> sectionFindings(Json? view, String sec) => findings(view).where((f) => f['section'] == sec).toList();

  Json? findFinding(String? ref, Json? view) {
    if (ref == null) return null;
    for (final f in findings(view)) {
      if (f['ref'] == ref) return f;
    }
    for (final v in products.values) {
      for (final f in findings(asMap(v))) {
        if (f['ref'] == ref) return f;
      }
    }
    return null;
  }

  static bool needsCheck(Json f) {
    if (f['todo'] == false) return false;
    return f['todo'] == true || f['level'] == 'unconfirmed' || f['level'] == 'expired';
  }

  static Map<String, int> count(List<Json> list) {
    final c = {for (final l in Level.findingLevels) l: 0};
    for (final f in list) {
      final lv = str(f['level']);
      if (c.containsKey(lv)) c[lv] = c[lv]! + 1;
    }
    return c;
  }

  // ───────── 원문 발췌(app.js excerpt와 같은 규칙)
  static bool matchHeading(String text, String? pattern) {
    if (pattern == null || pattern.isEmpty) return false;
    if (text == pattern) return true;
    try {
      return RegExp(pattern).hasMatch(text);
    } catch (_) {
      return text.contains(pattern);
    }
  }

  String? excerpt(String path, String? pattern) {
    final body = docBody(path);
    if (body.isEmpty) return null;
    final lines = body.split('\n');
    final heads = <({int i, int level, String text})>[];
    var fence = false;
    final headRe = RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$');
    for (var i = 0; i < lines.length; i++) {
      if (RegExp(r'^\s*(```|~~~)').hasMatch(lines[i])) fence = !fence;
      if (fence) continue;
      final m = headRe.firstMatch(lines[i]);
      if (m != null) heads.add((i: i, level: m[1]!.length, text: m[2]!.replaceAll(RegExp(r'[*_`]'), '').trim()));
    }
    final parts = <({String head, String body})>[];
    var until = -1;
    for (var k = 0; k < heads.length; k++) {
      final hd = heads[k];
      if (hd.i < until || !matchHeading(hd.text, pattern)) continue;
      var end = lines.length;
      for (var j = k + 1; j < heads.length; j++) {
        if (heads[j].level <= hd.level) {
          end = heads[j].i;
          break;
        }
      }
      parts.add((head: lines[hd.i].replaceFirst(RegExp(r'^#{1,6}'), '####'), body: lines.sublist(hd.i + 1, end).join('\n')));
      until = end;
    }
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.first.body.trim();
    return parts.map((x) => '${x.head}\n${x.body}').join('\n\n').trim();
  }

  // ───────── 링크 해석(app.js resolveLink)
  LinkTarget? resolveLink(String? raw, String? fromPath) {
    var s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    if (RegExp(r'^(https?:|mailto:)', caseSensitive: false).hasMatch(s)) return LinkTarget.external(s);
    if (RegExp(r'^[a-z][a-z\d+.-]*:', caseSensitive: false).hasMatch(s)) return null;
    String decode(String x) {
      try {
        return Uri.decodeComponent(x);
      } catch (_) {
        return x;
      }
    }

    if (s.startsWith('#')) return LinkTarget.fragment(decode(s.substring(1)));
    final hashAt = s.indexOf('#');
    final frag = hashAt >= 0 ? decode(s.substring(hashAt + 1)) : '';
    final p = decode((hashAt >= 0 ? s.substring(0, hashAt) : s).split('?').first);
    final base = fromPath == null ? '' : fromPath.substring(0, fromPath.lastIndexOf('/') + 1);
    for (final cand in [normalizePath(base + p), normalizePath(p)]) {
      final d = lookup(documents, cand);
      if (d != null) return LinkTarget.doc(d, frag);
      final a = lookup(assets, cand);
      if (a != null) return LinkTarget.asset(a);
    }
    final name = fileName(normalizePath(p));
    final hits = documents.keys.where((k) => fileName(k) == name).toList();
    if (hits.length == 1) return LinkTarget.doc(hits.first, frag);
    return null;
  }
}

/// 날짜·범위 표기.
String fmtDate(Object? s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(str(s));
  if (m != null) return '${m[1]}-${m[2]}-${m[3]}';
  return str(s).isEmpty ? '–' : str(s);
}

String dateRange(Json product) {
  final r = asList(product['dateRange']);
  if (r.isEmpty) return '–';
  if (r.length < 2 || r[1] == null || r[0] == r[1]) return fmtDate(r[0]);
  return '${fmtDate(r[0])} ~ ${fmtDate(r[1])}';
}
