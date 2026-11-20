import 'package:material_ui/material_ui.dart';

import 'data.dart';
import 'viewers.dart';

/// 상품 Strategy 화면 안에서 공통으로 쓰는 값: 자료, 지금 상품, 근거 필터.
class StrategyScope extends InheritedWidget {
  const StrategyScope({
    super.key,
    required this.data,
    required this.brand,
    required this.product,
    required this.view,
    required this.filter,
    required this.onFilter,
    required super.child,
  });

  final StudioData data;
  final Json brand;
  final Json product;
  final Json view;
  final String? filter;
  final ValueChanged<String?> onFilter;

  static StrategyScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StrategyScope>()!;

  /// 필터가 켜져 있으면 그 수준의 조서만 남긴다.
  List<Json> filtered(List<Json> list) => filter == null ? list : list.where((f) => f['level'] == filter).toList();

  void openDoc(BuildContext context, String? keyOrPath, {String? heading, String? url}) {
    final path = data.docPath(keyOrPath, view, brand);
    if (path == null) {
      if (url != null) openExternal(context, url);
      return;
    }
    showDoc(context, data, path, heading: heading, url: url);
  }

  @override
  bool updateShouldNotify(StrategyScope old) =>
      old.filter != filter || old.view != view || old.product != product || old.data != data;
}
