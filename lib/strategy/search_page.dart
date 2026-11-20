import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'blocks.dart';
import 'data.dart';
import 'product_page.dart';
import 'viewers.dart';

/// 근거·문서 제목·브랜드·상품 검색(웹의 Ctrl K 검색).
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.data, required this.strategyNav});

  final StudioData data;

  /// 결과를 열 Strategy 화면의 내비게이터.
  final GlobalKey<NavigatorState> strategyNav;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _Item {
  _Item({required this.kind, required this.title, required this.sub, required this.run, this.level, this.code, this.todo = false});
  final String kind;
  final String title;
  final String sub;
  final String? level;
  final String? code;
  final bool todo;
  final void Function(BuildContext context) run;
  late final String hay = '$kind $title $sub ${code ?? ''}'.toLowerCase();
}

class _SearchPageState extends State<SearchPage> {
  final _q = TextEditingController();
  late final List<_Item> _index = _build();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _openProduct(BuildContext context, Json b, Json p, String tab) {
    Navigator.of(context).pop();
    final nav = widget.strategyNav.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute<void>(builder: (_) => ProductPage(data: widget.data, brand: b, product: p, tab: tab)));
  }

  List<_Item> _build() {
    final d = widget.data;
    final items = <_Item>[];
    for (final b in d.brands) {
      final products = asMaps(b['products']);
      items.add(_Item(
        kind: '브랜드',
        title: [str(b['name']), str(b['nameEn'])].where((x) => x.isNotEmpty).join(' '),
        sub: '${products.length}개 상품${b['sample'] == true ? ' · 예시 데이터' : ''}',
        run: (context) {
          Navigator.of(context).pop();
          widget.strategyNav.currentState?.popUntil((r) => r.isFirst);
        },
      ));
      for (final p in products) {
        items.add(_Item(
          kind: '상품',
          title: str(p['name']),
          sub: [str(b['name']), str(p['fullName'])].where((x) => x.isNotEmpty).join(' · '),
          run: (context) => _openProduct(context, b, p, 'summary'),
        ));
        for (final f in StudioData.findings(d.view(b, p))) {
          final sec = str(f['section']);
          final tab = StrategyTab.all.any((t) => t.id == sec) ? sec : 'summary';
          final src = asMap(f['source']);
          items.add(_Item(
            kind: '근거',
            level: str(f['level']),
            code: str(f['ref']),
            todo: StudioData.needsCheck(f),
            title: str(f['text']) + (str(f['quote']).isEmpty ? '' : ' “${f['quote']}”'),
            sub: '${b['name']} ${p['name']} · ${str(src['label'])}',
            run: (context) {
              _openProduct(context, b, p, tab);
              final docKey = src['doc'] == null ? null : str(src['doc']);
              final path = d.docPath(docKey, d.view(b, p), b);
              final navContext = widget.strategyNav.currentContext;
              if (path != null && navContext != null) {
                showDoc(navContext, d, path, heading: src['heading'] == null ? null : str(src['heading']), url: src['url'] == null ? null : str(src['url']));
              }
            },
          ));
        }
      }
    }
    final headRe = RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$');
    for (final path in d.documents.keys) {
      var fence = false;
      for (final line in d.docBody(path).split('\n')) {
        if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) fence = !fence;
        if (fence) continue;
        final m = headRe.firstMatch(line);
        if (m == null) continue;
        final text = m[2]!.replaceAll(RegExp(r'[*_`]'), '').trim();
        items.add(_Item(
          kind: '문서',
          title: text,
          sub: '${d.docTitle(path)} · ${StudioData.fileName(path)}',
          run: (context) {
            Navigator.of(context).pop();
            final navContext = widget.strategyNav.currentContext;
            if (navContext != null) showDoc(navContext, d, path, heading: '^${RegExp.escape(text)}\$');
          },
        ));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final q = _q.text.trim().toLowerCase();
    final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final results = terms.isEmpty
        ? _index.where((i) => i.todo).toList()
        : _index.where((i) => terms.every(i.hay.contains)).take(80).toList();
    return Scaffold(
      body: Column(children: [
        SheetHeader(title: '검색', close: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 16, color: colors.ink),
            cursorColor: colors.ink,
            decoration: InputDecoration(
              hintText: '근거, 문서 제목, 브랜드, 상품 검색',
              hintStyle: TextStyle(color: colors.sub),
              prefixIcon: Icon(Icons.search, color: colors.sub),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '지우기',
                      onPressed: () => setState(_q.clear),
                      icon: Icon(Icons.close, color: colors.sub),
                    ),
              filled: true,
              fillColor: colors.sheet,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.rule), borderRadius: BorderRadius.circular(4)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.ink), borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(terms.isEmpty ? '확인이 필요한 근거 ${results.length}건' : '결과 ${results.length}건',
                style: TextStyle(fontSize: 13, color: colors.sub)),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('찾는 항목이 없습니다. 다른 낱말로 검색해 보세요.', style: TextStyle(fontSize: 14, color: colors.sub)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final it = results[i];
                    return InkWell(
                      onTap: () => it.run(context),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.rule))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(
                            width: 44,
                            child: Text(it.kind, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.sub)),
                          ),
                          if (it.level != null) Padding(padding: const EdgeInsets.only(right: 6, top: 1), child: Tick(it.level, size: 15)),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, height: 1.45, color: colors.ink)),
                              Text([if (it.code != null && it.code!.isNotEmpty) it.code!, it.sub].join(' · '),
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: colors.sub)),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
