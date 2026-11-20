import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'blocks.dart';
import 'data.dart';
import 'product_page.dart';

TextStyle _sub(StudioColors colors) => TextStyle(fontSize: 13, height: 1.45, color: colors.sub);

void openProduct(BuildContext context, StudioData data, Json brand, Json product, {String? tab}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ProductPage(data: data, brand: brand, product: product, tab: tab),
  ));
}

/// Strategy 첫 화면: 브랜드별 상품 목록(웹의 #/brands).
class BrandsPage extends StatelessWidget {
  const BrandsPage({super.key, required this.data});

  final StudioData data;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text('브랜드', style: Theme.of(context).textTheme.headlineLarge)),
          if (data.generatedAt.isNotEmpty) Text('생성 ${fmtDate(data.generatedAt)}', style: _sub(colors)),
        ]),
        const SizedBox(height: 8),
        if (data.brands.isEmpty)
          const EmptyNote(title: '등록된 브랜드가 없습니다', body: '브랜드 조사 문서를 만들고 앱 자료를 다시 만드세요.', path: '01-strategy/brand/{브랜드}/brand.md'),
        for (final b in data.brands) _BrandBlock(data: data, brand: b),
      ],
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.data, required this.brand});

  final StudioData data;
  final Json brand;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final products = asMaps(brand['products']);
    final logo = asMap(brand['logo']);
    final preferred = str(logo[colors.brightness.name]);
    final fallback = str(logo[colors.brightness == Brightness.dark ? 'light' : 'dark']);
    final logoSrc = data.asset(preferred.isNotEmpty ? preferred : fallback);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      decoration: BoxDecoration(color: colors.sheet, borderRadius: studioCard),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.ruleStrong))),
          child: Row(children: [
            if (logoSrc != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(height: 22, width: 72, child: Image.asset(logoSrc, fit: BoxFit.contain, alignment: Alignment.centerLeft)),
              ),
            Expanded(
              child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(str(brand['name']), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.ink)),
                if (str(brand['nameEn']).isNotEmpty) Text(str(brand['nameEn']), style: _sub(colors)),
                if (brand['sample'] == true) const _SampleTag(),
              ]),
            ),
          ]),
        ),
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('상품 자료가 없습니다 · 01-strategy/brand/${brand['name']}/{상품}/product.md', style: _sub(colors)),
          ),
        for (final p in products) _ProductRow(data: data, brand: brand, product: p),
      ]),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.data, required this.brand, required this.product});

  final StudioData data;
  final Json brand;
  final Json product;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final c = StudioData.count(StudioData.findings(data.view(brand, product)));
    final total = c.values.fold(0, (a, b) => a + b);
    return InkWell(
      onTap: () => openProduct(context, data, brand, product),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.rule))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
              Text(str(product['name']), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.ink)),
              if (str(product['fullName']).isNotEmpty && product['fullName'] != product['name'])
                Text(str(product['fullName']), style: _sub(colors)),
              Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (total == 0)
                  Text('조서 없음', style: _sub(colors))
                else
                  Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
                    for (final lv in Level.findingLevels)
                      if (c[lv]! > 0)
                        Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [
                          Tick(lv, size: 14),
                          Text('${c[lv]}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.ink)),
                        ]),
                  ]),
                Text(dateRange(product), style: _sub(colors)),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right, color: colors.sub),
        ]),
      ),
    );
  }
}

class _SampleTag extends StatelessWidget {
  const _SampleTag();

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: colors.markBg, borderRadius: BorderRadius.circular(3)),
        child: Text('예시 데이터', style: TextStyle(fontSize: 12, color: colors.hy)),
      );
  }
}
