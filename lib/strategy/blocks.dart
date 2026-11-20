import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'data.dart';
import 'scope.dart';
import 'viewers.dart';

TextStyle _sub(StudioColors colors) => TextStyle(fontSize: 13, height: 1.45, color: colors.sub);

Color levelColor(BuildContext context, String? level) {
  final colors = StudioColors.of(context);
  return switch (level) {
    'confirmed' || 'final' => colors.ok,
    'hypothesis' || 'review' => colors.hy,
    'expired' => colors.no,
    _ => colors.sub,
  };
}

/// 근거 틱마크(웹의 tick()).
class Tick extends StatelessWidget {
  const Tick(this.level, {super.key, this.size = 16});

  final String? level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (level) {
      'confirmed' => Icons.check,
      'hypothesis' => Icons.question_mark,
      'expired' => Icons.outlined_flag,
      'draft' => Icons.edit_outlined,
      'review' => Icons.search,
      'final' => Icons.check_circle_outline,
      _ => Icons.radio_button_unchecked,
    };
    return Semantics(
      label: Level.labelOf(level ?? 'unconfirmed'),
      child: Icon(icon, size: size, color: levelColor(context, level)),
    );
  }
}

/// 비어 있을 때 안내.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.title, this.body, this.path});

  final String title;
  final String? body;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: colors.rule), borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink)),
        if (body != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(body!, style: _sub(colors))),
        if (path != null && path!.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('넣을 곳  $path', style: _sub(colors))),
      ]),
    );
  }
}

/// 제목이 있는 묶음(웹의 section()).
class Sec extends StatelessWidget {
  const Sec({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.sheet, borderRadius: studioCard),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          margin: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ?trailing,
          ]),
        ),
        child,
      ]),
    );
  }
}

/// 펼치는 한 줄(웹의 ev 행). body가 없으면 펼치지 않는다.
class EvRow extends StatefulWidget {
  const EvRow({super.key, this.level, required this.main, this.tail, this.body, this.flag = false, this.lead = false});

  final String? level;
  final Widget main;
  final Widget? tail;
  final List<Widget>? body;
  final bool flag;
  final bool lead;

  @override
  State<EvRow> createState() => _EvRowState();
}

class _EvRowState extends State<EvRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final body = widget.body?.where((w) => w is! SizedBox).toList() ?? const <Widget>[];
    final canOpen = body.isNotEmpty;
    final head = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 24, child: Padding(padding: const EdgeInsets.only(top: 3), child: widget.level == null ? null : Tick(widget.level))),
        Expanded(
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: widget.lead ? 19 : 15, height: 1.5, fontWeight: widget.lead ? FontWeight.w700 : null, color: colors.ink),
            child: widget.main,
          ),
        ),
        if (widget.tail != null) Padding(padding: const EdgeInsets.only(left: 8), child: widget.tail),
        if (canOpen)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: AnimatedRotation(
              turns: _open ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.chevron_right, size: 20, color: colors.sub),
            ),
          ),
      ]),
    );
    return Container(
      decoration: BoxDecoration(
        color: widget.lead ? colors.accentSoft : widget.flag ? colors.flagBg : null,
        borderRadius: widget.lead ? studioCard : null,
        border: widget.lead ? null : Border(bottom: BorderSide(color: colors.rule)),
      ),
      padding: EdgeInsets.symmetric(horizontal: widget.lead ? 16 : widget.flag ? 8 : 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (canOpen) InkWell(onTap: () => setState(() => _open = !_open), child: head) else head,
        if (canOpen && _open)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: body),
          ),
      ]),
    );
  }
}

/// W/P 코드 버튼: 누르면 출처 원문(또는 바깥 주소)을 연다.
class RefCode extends StatelessWidget {
  const RefCode(this.finding, {super.key});

  final Json finding;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final scope = StrategyScope.of(context);
    final src = asMap(finding['source']);
    final ref = str(finding['ref']);
    final doc = src['doc'] == null ? null : str(src['doc']);
    final url = src['url'] == null ? null : str(src['url']);
    final hasDoc = doc != null && scope.data.docPath(doc, scope.view, scope.brand) != null;
    if (!hasDoc && url == null) {
      return Text(ref.isEmpty ? '–' : ref, style: _sub(colors).copyWith(decoration: TextDecoration.lineThrough));
    }
    return OutlinedButton(
      onPressed: () {
        if (hasDoc) {
          scope.openDoc(context, doc, heading: src['heading'] == null ? null : str(src['heading']), url: url);
        } else {
          openExternal(context, url!);
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink,
        side: BorderSide(color: colors.ruleStrong),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text('$ref 원문'),
    );
  }
}

/// 조서 한 줄의 펼침 내용: 메모, 출처, 날짜, W/P 코드.
List<Widget> evBody(BuildContext context, Json? f, {String? note}) {
    final colors = StudioColors.of(context);
  final src = f == null ? '' : str(asMap(f['source'])['label']);
  return [
    if (note != null && note.isNotEmpty) Text(note, style: TextStyle(fontSize: 14, height: 1.5, color: colors.ink)),
    if (f != null)
      Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (src.isNotEmpty) Text(src, style: _sub(colors)),
        if (f['date'] != null) Text(fmtDate(f['date']), style: _sub(colors)),
        if (f['ref'] != null) RefCode(f),
      ]),
  ];
}

Widget dueTag(BuildContext context, Json f) {
    final colors = StudioColors.of(context);
    return f['level'] == 'expired'
    ? Text('기한 지남', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.no))
    : const SizedBox.shrink();
  }

class FindingRow extends StatelessWidget {
  const FindingRow(this.f, {super.key, this.preferQuote = false});

  final Json f;
  final bool preferQuote;

  @override
  Widget build(BuildContext context) {
    final quote = preferQuote && str(f['quote']).isNotEmpty;
    return EvRow(
      level: str(f['level']),
      main: quote
          ? Text('“${f['quote']}”', style: const TextStyle(fontStyle: FontStyle.italic))
          : Text(str(f['text'])),
      tail: f['level'] == 'expired' ? dueTag(context, f) : null,
      body: evBody(context, f, note: quote ? str(f['text']) : null),
      flag: f['level'] == 'expired',
    );
  }
}

/// 조서 목록. 근거 필터가 켜져 있으면 그 수준만 보인다.
class FindingsList extends StatelessWidget {
  const FindingsList(this.list, {super.key, this.quotes = false, this.emptyTitle});

  final List<Json> list;
  final bool quotes;
  final String? emptyTitle;

  @override
  Widget build(BuildContext context) {
    final scope = StrategyScope.of(context);
    if (list.isEmpty) {
      return EmptyNote(
        title: emptyTitle ?? '이 영역의 조서 항목이 없습니다',
        body: '프로필에 findings 항목을 추가하면 여기에 틱마크와 W/P 코드로 정리됩니다.',
      );
    }
    final shown = scope.filtered(list);
    if (shown.isEmpty) return FilterEmpty(scope.filter!);
    return Column(children: [for (final f in shown) FindingRow(f, preferQuote: quotes)]);
  }
}

class FilterEmpty extends StatelessWidget {
  const FilterEmpty(this.level, {super.key});

  final String level;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('${Level.labelOf(level)} 항목이 없습니다.', style: _sub(colors)),
      );
  }
}

/// 근거 수준별 개수. 누르면 그 수준만 보고, 다시 누르면 모두 본다.
class TallyStrip extends StatelessWidget {
  const TallyStrip(this.list, {super.key});

  final List<Json> list;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final scope = StrategyScope.of(context);
    final c = StudioData.count(list);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: colors.wash, borderRadius: studioControl),
      child: Row(children: [
        Text('근거', style: _sub(colors)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final lv in Level.findingLevels)
              Tooltip(
                message: '${Level.labelOf(lv)} ${c[lv]}건 · ${Level.all[lv]!.desc}',
                child: Semantics(
                  button: true,
                  selected: scope.filter == lv,
                  label: '${Level.labelOf(lv)} ${c[lv]}건, 이 항목만 보기',
                  child: InkWell(
                    borderRadius: studioControl,
                    onTap: () => scope.onFilter(scope.filter == lv ? null : lv),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36, minWidth: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: scope.filter == lv ? colors.ground : null,
                        border: Border.all(color: scope.filter == lv ? colors.ink : colors.rule),
                        borderRadius: studioControl,
                      ),
                      child: Opacity(
                        opacity: c[lv] == 0 ? 0.45 : 1,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Tick(lv, size: 15),
                          const SizedBox(width: 6),
                          Text('${c[lv]}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// 필터를 켰을 때 화면 위에 뜨는 안내.
class FilterNote extends StatelessWidget {
  const FilterNote({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final scope = StrategyScope.of(context);
    if (scope.filter == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: colors.markBg, borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        Tick(scope.filter, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text('${Level.labelOf(scope.filter)} 항목만 보는 중입니다.', style: TextStyle(fontSize: 14, color: colors.ink))),
        TextButton(
          onPressed: () => scope.onFilter(null),
          style: TextButton.styleFrom(foregroundColor: colors.ink),
          child: const Text('모두 보기'),
        ),
      ]),
    );
  }
}

/// 접었다 펴는 묶음(웹의 details.ds).
class Fold extends StatefulWidget {
  const Fold({super.key, required this.label, required this.child, this.count, this.alert = false, this.initiallyOpen = false});

  final String label;
  final Widget child;
  final String? count;
  final bool alert;
  final bool initiallyOpen;

  @override
  State<Fold> createState() => _FoldState();
}

class _FoldState extends State<Fold> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.rule))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.chevron_right, size: 20, color: colors.sub),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink))),
              if (widget.count != null)
                Text(widget.count!,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.alert ? colors.no : colors.sub)),
            ]),
          ),
        ),
        if (_open) Padding(padding: const EdgeInsets.only(bottom: 12), child: widget.child),
      ]),
    );
  }
}

/// 확인이 필요한 조서(기한 지남 → 미확인 → 가설 순).
class TodoBox extends StatelessWidget {
  const TodoBox(this.list, {super.key});

  final List<Json> list;

  @override
  Widget build(BuildContext context) {
    const order = {'expired': 0, 'unconfirmed': 1, 'hypothesis': 2, 'confirmed': 3};
    final todo = list.where(StudioData.needsCheck).toList()
      ..sort((a, b) => (order[a['level']] ?? 9).compareTo(order[b['level']] ?? 9));
    if (todo.isEmpty) return const SizedBox.shrink();
    final shown = StrategyScope.of(context).filtered(todo);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Fold(
        label: '확인 필요',
        count: '${todo.length}건',
        alert: true,
        initiallyOpen: StrategyScope.of(context).filter != null && shown.isNotEmpty,
        child: shown.isEmpty
            ? FilterEmpty(StrategyScope.of(context).filter!)
            : Column(children: [for (final f in shown) FindingRow(f)]),
      ),
    );
  }
}

/// 이름 · 값 표(웹의 table.facts). 가격 행은 값을 굵게, 수집일을 따로 적는다.
class FactsTable extends StatelessWidget {
  const FactsTable(this.facts, {super.key});

  final List<Json> facts;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final f in facts) _row(context, f),
    ]);
  }

  Widget _row(BuildContext context, Json f) {
    final colors = StudioColors.of(context);
    var label = str(f['label']);
    var when = '';
    final price = f['price'] == true;
    if (price && label.contains(' / ')) {
      final parts = label.split(' / ');
      label = parts.first;
      when = parts.skip(1).join(' / ');
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.rule))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 112, child: Text(label, style: TextStyle(fontSize: 14, height: 1.5, color: colors.sub))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(str(f['value']),
                style: TextStyle(fontSize: price ? 18 : 15, height: 1.45, fontWeight: price ? FontWeight.w700 : null, color: colors.ink)),
            if (when.isNotEmpty) Text('수집 $when', style: _sub(colors)),
          ]),
        ),
      ]),
    );
  }
}

/// 원문 문서에서 제목 기준으로 잘라 보여 주는 묶음(웹의 docSections).
class DocSections extends StatelessWidget {
  const DocSections(this.list, {super.key});

  final List<Json> list;

  @override
  Widget build(BuildContext context) {
    final scope = StrategyScope.of(context);
    return Column(children: [
      for (final s in list) _one(context, scope, s),
    ]);
  }

  Widget _one(BuildContext context, StrategyScope scope, Json s) {
    final colors = StudioColors.of(context);
    final key = str(s['document']);
    final heading = s['heading'] == null ? null : str(s['heading']);
    final path = scope.data.docPath(key, scope.view, scope.brand);
    final md = path == null ? null : scope.data.excerpt(path, heading);
    return Fold(
      label: str(s['label']),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (path != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => scope.openDoc(context, path, heading: heading),
              style: TextButton.styleFrom(foregroundColor: colors.sub),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('원문에서 보기'),
            ),
          ),
        if (md != null)
          StudioMarkdown(data: scope.data, text: md, fromPath: path)
        else
          EmptyNote(
            title: path != null ? '원문에서 이 제목을 찾지 못했습니다' : '연결된 문서가 없습니다',
            body: path != null ? '제목 이름이 바뀌었을 수 있습니다. 프로필의 heading 값을 원문 제목과 맞추세요.' : "상품의 documents 맵에 '$key' 키가 없습니다.",
            path: path,
          ),
      ]),
    );
  }
}

/// 상품 대표 이미지. 누르면 크게 본다.
class CoverPhoto extends StatelessWidget {
  const CoverPhoto(this.product, {super.key, this.summary = false});

  final Json product;
  final bool summary;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final scope = StrategyScope.of(context);
    final hero = product['hero'] == null ? null : str(product['hero']);
    final src = scope.data.asset(hero);
    if (src == null) {
      return EmptyNote(title: '대표 이미지가 없습니다', path: hero ?? '01-strategy/brand/{브랜드}/{상품}/assets/');
    }
    final alt = str(product['heroAlt']).isEmpty ? str(product['name']) : str(product['heroAlt']);
    final photo = Semantics(
      button: true,
      label: '$alt, 크게 보기',
      child: GestureDetector(
        onTap: () => showAsset(context, scope.data, hero!, alt: alt),
        child: ClipRRect(
          borderRadius: studioCard,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(color: colors.sheet, child: Image.asset(src, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
    if (!summary) return photo;
    final name = str(product['name']);
    final selected = asMaps(product['facts']).where((f) => f['price'] != true).take(3);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.sheet, borderRadius: studioCard),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
        Row(spacing: 16, children: [
          SizedBox(width: 96, child: photo),
          Expanded(child: Text(name.isNotEmpty ? name : alt, style: Theme.of(context).textTheme.headlineSmall)),
        ]),
        if (selected.isNotEmpty) FactsTable(selected.toList()),
      ]),
    );
  }
}
