import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'blocks.dart';
import 'data.dart';
import 'scope.dart';
import 'tabs.dart';
import 'viewers.dart';

/// 상품 하나의 Strategy 화면: 요약 · 브랜드 · 상품 · 경쟁 · 고객 · 브리프.
class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.data, required this.brand, required this.product, this.tab});

  final StudioData data;
  final Json brand;
  final Json product;
  final String? tab;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: StrategyTab.all.length,
    vsync: this,
    initialIndex: StrategyTab.indexOf(widget.tab),
  );
  String? _filter;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openSource(BuildContext context, Json view) {
    final key = StrategyTab.all[_tabs.index].doc;
    final d = widget.data;
    final path = d.docPath(key, view, widget.brand) ??
        asMap(view['documents']).keys.map((k) => d.docPath(k, view, widget.brand)).nonNulls.firstOrNull;
    if (path != null) showDoc(context, d, path);
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final b = widget.brand, p = widget.product;
    final view = widget.data.view(b, p);
    final sample = b['sample'] == true;
    return Scaffold(
      body: Column(children: [
        SheetHeader(
          title: '${str(b['name'])} · ${str(p['name'])}',
          subtitle: ['Strategy', '자료 기준일 ${dateRange(p)}', if (sample) '예시 데이터'].join(' · '),
          actions: [
            if (view != null)
              Builder(builder: (context) => IconButton(
                    tooltip: '이 탭의 원문 문서 보기',
                    onPressed: () => _openSource(context, view),
                    icon: Icon(Icons.description_outlined, size: 20, color: colors.ink),
                  )),
          ],
        ),
        Material(
          color: colors.ground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: colors.ground,
              unselectedLabelColor: colors.sub,
              labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              indicator: BoxDecoration(color: colors.ink, borderRadius: studioControl),
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              dividerColor: Colors.transparent,
              tabs: [for (final t in StrategyTab.all) Tab(text: t.label, height: 44)],
            ),
          ),
        ),
        Expanded(
          child: view == null || asMap(view['strategy']).isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyNote(
                    title: view == null ? '이 상품의 화면 자료가 없습니다' : 'Strategy 자료가 없습니다',
                    body: '프로필을 채운 뒤 tool/export_strategy.py로 앱 자료를 다시 만드세요.',
                    path: 'dashboard/profiles/${b['id']}/${p['id']}.json',
                  ),
                )
              : StrategyScope(
                  data: widget.data,
                  brand: b,
                  product: p,
                  view: view,
                  filter: _filter,
                  onFilter: (lv) => setState(() => _filter = lv),
                  child: TabBarView(
                    controller: _tabs,
                    children: const [SummaryTab(), BrandTab(), ProductTab(), CompetitorTab(), CustomerTab(), BriefTab()],
                  ),
                ),
        ),
      ]),
    );
  }
}
