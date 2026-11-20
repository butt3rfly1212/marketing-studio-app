import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'blocks.dart';
import 'data.dart';
import 'scope.dart';
import 'viewers.dart';

TextStyle _sub(StudioColors colors) => TextStyle(fontSize: 13, height: 1.45, color: colors.sub);
TextStyle _ink(StudioColors colors) => TextStyle(fontSize: 15, height: 1.5, color: colors.ink);

/// 탭 하나의 스크롤 화면.
class TabList extends StatelessWidget {
  const TabList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
      children: [const FilterNote(), ...children],
    );
  }
}

Json _strategy(StrategyScope s) => asMap(s.view['strategy']);

// ───────────────────────────── 요약

class SummaryTab extends StatelessWidget {
  const SummaryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StrategyScope.of(context);
    final st = _strategy(s);
    final sum = asMap(st['summary']);
    final p = asMap(st['product']);
    final all = StudioData.findings(s.view);
    final message = asMap(sum['message']);
    final mf = s.data.findFinding(message['ref'] == null ? null : str(message['ref']), s.view);
    final priceFact = asMaps(p['facts']).where((f) => f['price'] == true).firstOrNull;
    final rows = asMaps(sum['rows']);
    final shownRows = s.filter == null
        ? rows
        : rows.where((r) => (s.data.findFinding(str(r['ref']), s.view)?['level'] ?? r['level']) == s.filter).toList();
    final cust = StudioData.sectionFindings(s.view, 'customer');
    return TabList(children: [
      const SizedBox(height: 16),
      TallyStrip(all),
      const SizedBox(height: 12),
      CoverPhoto(p, summary: true),
      const SizedBox(height: 12),
      if (message.isNotEmpty)
        EvRow(
          level: mf?['level'] == null ? null : str(mf!['level']),
          main: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
            const Text('핵심 메시지', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text('“${message['text']}”'),
          ]),
          body: evBody(context, mf),
          lead: true,
        )
      else
        EmptyNote(title: '채택한 메시지가 없습니다', body: '브리프의 메시지를 프로필 summary.message에 적으면 여기에 보입니다.', path: str(asMap(s.view['documents'])['messages'])),
      if (priceFact != null) FactsTable([priceFact]),
      TodoBox(all),
      if (rows.isNotEmpty)
        Sec(
          title: '메시지 근거',
          child: shownRows.isEmpty
              ? FilterEmpty(s.filter!)
              : Column(children: [
                  for (final r in shownRows) _messageRow(context, s, r),
                ]),
        ),
      const Sec(title: '경쟁 가격', child: PriceList()),
      if (cust.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Fold(
            label: '고객 근거',
            count: '${cust.length}건',
            child: FindingsList(cust, quotes: true),
          ),
        ),
    ]);
  }

  Widget _messageRow(BuildContext context, StrategyScope s, Json r) {
    final colors = StudioColors.of(context);
    final rf = s.data.findFinding(str(r['ref']), s.view);
    return EvRow(
      level: rf != null ? str(rf['level']) : (r['level'] == null ? null : str(r['level'])),
      main: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(str(r['label']), style: _sub(colors).copyWith(fontWeight: FontWeight.w600)),
        Text(str(r['text'])),
      ]),
      body: rf == null ? null : evBody(context, rf),
    );
  }
}

/// 요약 탭의 경쟁 가격 목록(웹의 competitorPriceTable).
class PriceList extends StatelessWidget {
  const PriceList({super.key});

  static ({String price, String date, String source}) priceInfo(Object? cell) {
    final lines = str(cell).split('\n');
    final rest = lines.skip(1).join(' ');
    final dm = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(rest);
    return (
      price: lines.first.trim(),
      date: dm?[1] ?? '',
      source: rest.replaceFirst(RegExp(r'\s*/?\s*\d{4}-\d{2}-\d{2}\s*'), '').replaceFirst(RegExp(r'\s*/\s*$'), '').trim(),
    );
  }

  static String? priceDigits(Object? s) => RegExp(r'(\d{1,3}(?:,\d{3})+|\d{4,})\s*원').firstMatch(str(s))?[1];

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = StrategyScope.of(context);
    final comp = asMap(_strategy(s)['competitor']);
    final names = asList(comp['names']);
    final rows = asList(comp['rows']).map(asList).toList();
    final priceRows = asList(comp['priceRows']);
    final priceRow = priceRows.isEmpty || priceRows.first is! int || (priceRows.first as int) >= rows.length ? null : rows[priceRows.first as int];
    if (names.isEmpty || priceRow == null) {
      return EmptyNote(title: '경쟁 가격 자료가 없습니다', body: '경쟁 비교 문서에 가격 행이 생기면 여기에 정리됩니다.', path: str(asMap(s.view['documents'])['competitor']));
    }
    final sizeRow = rows.where((r) => r.skip(1).any((v) => RegExp(r'\d+\s?ml', caseSensitive: false).hasMatch(str(v)))).firstOrNull;
    final pool = StudioData.findings(s.view).where((f) => f['section'] == 'competitor' || f['section'] == 'product').toList();
    final items = <({String? level, Widget row})>[];
    for (var i = 0; i < names.length; i++) {
      final info = priceInfo(i + 1 < priceRow.length ? priceRow[i + 1] : '');
      final digits = priceDigits(info.price);
      final f = digits == null ? null : pool.where((x) => x['level'] != 'expired' && str(x['text']).contains(digits)).firstOrNull;
      final size = sizeRow == null || i + 1 >= sizeRow.length ? '' : RegExp(r'\d+\s?ml', caseSensitive: false).firstMatch(str(sizeRow[i + 1]))?[0] ?? '';
      final ours = i == 0;
      final amount = RegExp(r'[\d,]+\s*원').firstMatch(info.price)?[0] ?? info.price;
      final extra = amount != info.price ? info.price.replaceFirst(amount, '').replaceFirst(RegExp(r'^[\s,·]+'), '') : '';
      final level = f == null ? null : str(f['level']);
      items.add((
        level: level,
        row: EvRow(
          level: level,
          main: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(str(names[i]).replaceAll('\n', ' '), style: TextStyle(fontWeight: ours ? FontWeight.w700 : null)),
            if (ours) const OursTag(),
          ]),
          tail: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amount.isEmpty ? '–' : amount,
                style: TextStyle(fontSize: 15, fontWeight: ours ? FontWeight.w700 : FontWeight.w600, color: colors.ink)),
            if (size.isNotEmpty) Text(size, style: _sub(colors)),
          ]),
          body: [
            Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (extra.isNotEmpty) Text(extra, style: _sub(colors)),
              if (info.source.isNotEmpty) Text(info.source, style: _sub(colors)),
              if (info.date.isNotEmpty) Text('수집 ${info.date}', style: _sub(colors)),
              if (f != null) RefCode(f),
            ]),
          ],
        ),
      ));
    }
    for (final f in pool.where((f) => f['level'] == 'expired' && priceDigits(f['text']) != null)) {
      items.add((
        level: 'expired',
        row: EvRow(
          level: 'expired',
          main: Text(str(f['text'])),
          tail: Text('${priceDigits(f['text'])}원',
              style: TextStyle(fontSize: 15, color: colors.sub, decoration: TextDecoration.lineThrough)),
          body: evBody(context, f),
          flag: true,
        ),
      ));
    }
    final shown = s.filter == null ? items : items.where((x) => x.level == s.filter).toList();
    if (shown.isEmpty) return FilterEmpty(s.filter!);
    return Column(children: [for (final x in shown) x.row]);
  }
}

class OursTag extends StatelessWidget {
  const OursTag({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: colors.ink), borderRadius: BorderRadius.circular(3)),
        child: Text('우리 상품', style: TextStyle(fontSize: 12, height: 1.2, color: colors.ink)),
      );
  }
}

// ───────────────────────────── 브랜드

class BrandTab extends StatelessWidget {
  const BrandTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = StrategyScope.of(context);
    final b = asMap(_strategy(s)['brand']);
    final list = StudioData.sectionFindings(s.view, 'brand');
    final logo = asMap(b['logo']);
    final logoPath = str(logo['dark']).isNotEmpty ? str(logo['dark']) : str(logo['light']);
    final logoSrc = s.data.asset(logoPath);
    final palette = asMaps(b['palette']);
    final t = asMap(b['typography']);
    final images = asMaps(b['images']);
    final guidelines = asMap(b['guidelines']).values.map(asMap).toList();
    final notes = asMaps(b['notes']);
    final character = b['character'];
    final audio = b['audio'];
    return TabList(children: [
      TallyStrip(list),
      TodoBox(list),
      Sec(title: '브랜드 조서', child: FindingsList(list)),
      if (logo.isNotEmpty || palette.isNotEmpty || t.isNotEmpty)
        Sec(
          title: '아이덴티티',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (logo.isNotEmpty) ...[
              const SizedBox(height: 12),
              logoSrc == null
                  ? EmptyNote(title: '로고 파일이 없습니다', path: logoPath)
                  : GestureDetector(
                      onTap: () => showAsset(context, s.data, logoPath, alt: str(logo['alt'])),
                      child: Container(
                        height: 120,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(border: Border.all(color: colors.rule), borderRadius: BorderRadius.circular(4)),
                        child: Image.asset(logoSrc, fit: BoxFit.contain, semanticLabel: str(logo['alt'])),
                      ),
                    ),
              Padding(padding: EdgeInsets.only(top: 6), child: Text('로고 · 어두운 배경용', style: _sub(colors))),
            ],
            if (palette.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('색상', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink)),
              for (final c in palette)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _hex(str(c['hex'])),
                        border: Border.all(color: colors.ruleStrong),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(c['hex']), style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: colors.ink)),
                        Text(str(c['name']), style: _sub(colors)),
                      ]),
                    ),
                  ]),
                ),
            ],
            if (t.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('서체', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink)),
              const SizedBox(height: 6),
              Text(str(t['sample']).isEmpty ? '가나다라 ABC 0123' : str(t['sample']),
                  style: TextStyle(fontSize: 22, color: colors.ink, fontFamily: str(t['family']), fontFamilyFallback: fontFallback)),
              Text(str(t['family']), style: _sub(colors)),
              if (asList(t['weights']).isNotEmpty)
                Text(asList(t['weights']).map((w) => w is Map ? str(w['label'] ?? w['value']) : str(w)).join(' · '), style: _sub(colors)),
            ],
          ]),
        ),
      if (character != null)
        Sec(title: '캐릭터', child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(_textOf(character), style: _ink(colors)))),
      if (audio != null)
        Sec(title: '사운드', child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(_textOf(audio), style: _ink(colors)))),
      if (images.isNotEmpty)
        Sec(
          title: '이미지 ${images.length}점',
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 560 ? 3 : 2;
              final w = (box.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(spacing: 12, runSpacing: 16, children: [
                for (final im in images) SizedBox(width: w, child: _thumb(context, s, im)),
              ]);
            }),
          ),
        ),
      if (guidelines.isNotEmpty) Sec(title: '가이드라인', child: DocSections(guidelines)),
      if (notes.isNotEmpty) Sec(title: '참고', child: DocSections(notes)),
    ]);
  }

  Widget _thumb(BuildContext context, StrategyScope s, Json im) {
    final colors = StudioColors.of(context);
    final path = str(im['asset']);
    final src = s.data.asset(path);
    final alt = str(im['alt']).isEmpty ? StudioData.fileName(path) : str(im['alt']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
        aspectRatio: 1,
        child: src == null
            ? Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: colors.rule), borderRadius: BorderRadius.circular(4)),
                child: Text('파일 없음', style: _sub(colors)),
              )
            : GestureDetector(
                onTap: () => showAsset(context, s.data, path, alt: alt),
                child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset(src, fit: BoxFit.cover, semanticLabel: alt)),
              ),
      ),
      const SizedBox(height: 6),
      Text(alt, maxLines: 2, overflow: TextOverflow.ellipsis, style: _sub(colors)),
    ]);
  }

  static String _textOf(Object? v) => v is Map ? str(v['text'] ?? v['label']) : str(v);

  static Color _hex(String hex) {
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h.length == 3 ? h.split('').map((c) => '$c$c').join() : h, radix: 16);
    return v == null ? Colors.transparent : Color(0xFF000000 | v);
  }
}

// ───────────────────────────── 상품

class ProductTab extends StatelessWidget {
  const ProductTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = StrategyScope.of(context);
    final p = asMap(_strategy(s)['product']);
    final list = StudioData.sectionFindings(s.view, 'product');
    final facts = asMaps(p['facts']);
    final sections = asMaps(p['sections']);
    return TabList(children: [
      const SizedBox(height: 16),
      CoverPhoto(p),
      if (str(p['name']).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(str(p['name']), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.ink)),
        ),
      if (facts.isNotEmpty) FactsTable(facts) else const EmptyNote(title: '상품 정보가 없습니다'),
      TallyStrip(list),
      TodoBox(list),
      Sec(title: '상품 조서', child: FindingsList(list)),
      if (sections.isNotEmpty) Sec(title: '원문 발췌', child: DocSections(sections)),
    ]);
  }
}

// ───────────────────────────── 경쟁

class CompetitorTab extends StatelessWidget {
  const CompetitorTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = StrategyScope.of(context);
    final c = asMap(_strategy(s)['competitor']);
    final names = asList(c['names']).map(str).toList();
    final rows = asList(c['rows']).map(asList).toList();
    final priceRows = asList(c['priceRows']);
    final list = StudioData.sectionFindings(s.view, 'competitor');
    final criteria = asMap(c['criteria']);
    final critPath = criteria.isEmpty ? null : s.data.docPath(str(criteria['document']), s.view, s.brand);
    final sections = asMaps(c['sections']);
    return TabList(children: [
      TallyStrip(list),
      TodoBox(list),
      Sec(
        title: '경쟁 비교',
        trailing: critPath == null
            ? null
            : TextButton(
                onPressed: () => s.openDoc(context, critPath, heading: str(criteria['heading'])),
                style: TextButton.styleFrom(foregroundColor: colors.sub, minimumSize: const Size(0, 36)),
                child: Text(str(criteria['label']).isEmpty ? '비교 기준' : str(criteria['label'])),
              ),
        child: names.isEmpty
            ? EmptyNote(title: '경쟁 비교 표가 없습니다', body: '경쟁 비교 문서를 만들고 프로필 competitor.names / rows를 채우세요.', path: str(asMap(s.view['documents'])['competitor']))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < names.length; i++) _nameChip(context, names[i], i == 0),
                ]),
                for (var ri = 0; ri < rows.length; ri++) _criterion(context, rows[ri], names, priceRows.contains(ri)),
              ]),
      ),
      Sec(title: '경쟁 조서', child: FindingsList(list)),
      if (sections.isNotEmpty) Sec(title: '원문 발췌', child: DocSections(sections)),
    ]);
  }

  Widget _nameChip(BuildContext context, String name, bool ours) {
    final colors = StudioColors.of(context);
    final nm = name.split('\n');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ours ? colors.wash : null,
        border: Border.all(color: ours ? colors.ink : colors.rule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nm.first, style: _sub(colors)),
        Text(nm.length > 1 ? nm.skip(1).join(' ') : nm.first,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink)),
      ]),
    );
  }

  /// 비교 기준 하나: 상품마다 한 줄씩. 첫 상품(우리 상품)은 왼쪽 선으로 표시한다.
  Widget _criterion(BuildContext context, List<dynamic> row, List<String> names, bool isPrice) {
    final colors = StudioColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(str(row.isEmpty ? '' : row.first), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.sub)),
        const SizedBox(height: 6),
        for (var i = 0; i < names.length; i++)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            decoration: BoxDecoration(
              color: i == 0 ? colors.sheet : null,
              border: Border(
                left: BorderSide(color: i == 0 ? colors.ink : colors.rule, width: i == 0 ? 2 : 1),
                bottom: BorderSide(color: colors.rule),
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 96,
                child: Text(names[i].split('\n').skip(names[i].contains('\n') ? 1 : 0).join(' '),
                    style: TextStyle(fontSize: 13, height: 1.5, fontWeight: i == 0 ? FontWeight.w700 : null, color: colors.sub)),
              ),
              const SizedBox(width: 8),
              Expanded(child: _value(context, i + 1 < row.length ? row[i + 1] : '', isPrice)),
            ]),
          ),
      ]),
    );
  }

  Widget _value(BuildContext context, Object? val, bool isPrice) {
    final colors = StudioColors.of(context);
    final lines = str(val).split('\n');
    if (!isPrice) return Text(lines.join('\n'), style: TextStyle(fontSize: 14, height: 1.5, color: colors.ink));
    final pi = PriceList.priceInfo(val);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lines.first, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.ink)),
      Text([pi.source, pi.date].where((x) => x.isNotEmpty).join(' · '), style: _sub(colors)),
    ]);
  }
}

// ───────────────────────────── 고객

class CustomerTab extends StatelessWidget {
  const CustomerTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = StrategyScope.of(context);
    final c = asMap(_strategy(s)['customer']);
    final tiles = asMaps(c['tiles']);
    final list = StudioData.sectionFindings(s.view, 'customer');
    final sections = asMaps(c['sections']);
    return TabList(children: [
      TallyStrip(list),
      TodoBox(list),
      if (tiles.isNotEmpty)
        Sec(
          title: '고객 유형',
          child: Column(children: [
            for (final t in tiles) Fold(label: str(t['label']), child: FactsTable(asMaps(t['facts']))),
          ]),
        ),
      Sec(title: '고객 근거', trailing: Text('인용은 원문 그대로', style: _sub(colors)), child: FindingsList(list, quotes: true)),
      if (sections.isNotEmpty) Sec(title: '분석', child: DocSections(sections)),
    ]);
  }
}

// ───────────────────────────── 브리프

class BriefTab extends StatefulWidget {
  const BriefTab({super.key});

  @override
  State<BriefTab> createState() => _BriefTabState();
}

class _BriefTabState extends State<BriefTab> {
  int _idx = 0;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = StrategyScope.of(context);
    final b = asMap(_strategy(s)['brief']);
    final msgs = asMaps(b['messages']);
    final list = StudioData.sectionFindings(s.view, 'brief');
    final idx = msgs.isEmpty ? 0 : _idx.clamp(0, msgs.length - 1);
    final facts = asMaps(b['facts']);
    final structure = asList(b['structure']);
    final sections = asMaps(b['sections']);
    return TabList(children: [
      TallyStrip(list),
      TodoBox(list),
      Sec(
        title: '메시지 시안 ${msgs.isEmpty ? '' : '${msgs.length}개'}'.trim(),
        child: msgs.isEmpty
            ? EmptyNote(title: '메시지 시안이 없습니다', body: '마케팅 메시지 문서를 만들고 프로필 brief.messages를 채우세요.', path: str(asMap(s.view['documents'])['messages']))
            : _message(context, s, msgs, idx),
      ),
      if (facts.isNotEmpty) Sec(title: '브리프 요약', child: FactsTable(facts)),
      if (structure.isNotEmpty)
        Sec(
          title: '구성',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < structure.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('${i + 1}. ${_structText(structure[i])}', style: _ink(colors)),
              ),
          ]),
        ),
      Sec(title: '브리프 조서', child: FindingsList(list)),
      if (sections.isNotEmpty) Sec(title: '원문 발췌', child: DocSections(sections)),
    ]);
  }

  static String _structText(Object? x) {
    if (x is Map) return [str(x['label']), str(x['text'] ?? x['value'])].where((e) => e.isNotEmpty).join(' ');
    return str(x);
  }

  Widget _message(BuildContext context, StrategyScope s, List<Json> msgs, int idx) {
    final colors = StudioColors.of(context);
    final m = msgs[idx];
    final text = str(m['adcopy']).isNotEmpty ? str(m['adcopy']) : str(m['text']);
    List<Json> rowsOf(List<(String, String)> keys) => [
          for (final k in keys)
            if (str(m[k.$1]).isNotEmpty) {'label': k.$2, 'value': str(m[k.$1])},
        ];
    final factRows = rowsOf([('audience', '대상'), ('channel', '채널'), ('action', '목표 행동')]);
    final moreRows = rowsOf([('reason', '이유'), ('format', '형식')]);
    final proofLinks = asMaps(m['proofLinks']);
    final flow = asList(m['flow']);
    final cuts = asList(m['cuts']).map(asList).toList();
    final extra = asMaps(m['sections']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(spacing: 8, children: [
          for (var i = 0; i < msgs.length; i++)
            ChoiceChip(
              selected: i == idx,
              showCheckmark: false,
              onSelected: (_) => setState(() {
                _idx = i;
                _copied = false;
              }),
              label: Text('${i + 1}  ${str(msgs[i]['name'] ?? msgs[i]['label'] ?? '시안')}'),
              labelStyle: TextStyle(fontSize: 14, color: i == idx ? colors.sheet : colors.ink, fontWeight: FontWeight.w600),
              selectedColor: colors.ink,
              backgroundColor: colors.sheet,
              side: BorderSide(color: i == idx ? colors.ink : colors.rule),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      Text('“$text”', style: TextStyle(fontSize: 22, height: 1.4, fontWeight: FontWeight.w700, color: colors.ink)),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (mounted) setState(() => _copied = true);
          },
          style: TextButton.styleFrom(foregroundColor: colors.ink, padding: EdgeInsets.zero),
          icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
          label: Text(_copied ? '복사됨' : '복사'),
        ),
      ),
      if (factRows.isNotEmpty) FactsTable(factRows),
      if (moreRows.isNotEmpty || str(m['proof']).isNotEmpty || proofLinks.isNotEmpty)
        Fold(
          label: '이유와 근거',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FactsTable(moreRows.where((r) => r['label'] == '이유').toList()),
            if (str(m['proof']).isNotEmpty || proofLinks.isNotEmpty) _proof(context, s, m, proofLinks),
            FactsTable(moreRows.where((r) => r['label'] == '형식').toList()),
          ]),
        ),
      if (flow.isNotEmpty)
        Fold(
          label: '흐름',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < flow.length; i++)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('${i + 1}. ${str(flow[i])}', style: _ink(colors))),
          ]),
        ),
      if (cuts.isNotEmpty)
        Fold(
          label: '구성',
          child: Column(children: [
            for (final c in cuts)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.rule))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 32, child: Text(str(c.isNotEmpty ? c[0] : ''), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(str(c.length > 1 ? c[1] : ''), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink)),
                      Text(str(c.length > 2 ? c[2] : ''), style: TextStyle(fontSize: 14, height: 1.5, color: colors.sub)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      if (extra.isNotEmpty) DocSections(extra),
    ]);
  }

  Widget _proof(BuildContext context, StrategyScope s, Json m, List<Json> links) {
    final colors = StudioColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.rule))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 112, child: Text('근거', style: TextStyle(fontSize: 14, height: 1.5, color: colors.sub))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (str(m['proof']).isNotEmpty) Text(str(m['proof']), style: _ink(colors)),
            if (links.isNotEmpty)
              Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final l in links)
                  if (l['url'] != null)
                    TextButton.icon(
                      onPressed: () => openExternal(context, str(l['url'])),
                      style: TextButton.styleFrom(foregroundColor: colors.ink, padding: const EdgeInsets.symmetric(horizontal: 4)),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text(str(l['text'])),
                    )
                  else if (l['document'] != null && s.data.docPath(str(l['document']), s.view, s.brand) != null)
                    TextButton(
                      onPressed: () => s.openDoc(context, str(l['document']), heading: l['heading'] == null ? null : str(l['heading'])),
                      style: TextButton.styleFrom(foregroundColor: colors.ink, padding: const EdgeInsets.symmetric(horizontal: 4)),
                      child: Text(str(l['text']), style: const TextStyle(decoration: TextDecoration.underline)),
                    )
                  else if (!RegExp(r'^\s*[·,/]\s*$').hasMatch(str(l['text'])))
                    Text(str(l['text']), style: _ink(colors)),
              ]),
          ]),
        ),
      ]),
    );
  }
}
