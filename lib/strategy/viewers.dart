import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'data.dart';

/// 바깥 주소는 브라우저(앱 밖)에서 연다.
Future<void> openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 열지 못했습니다.')));
  }
}

/// 원문 문서를 화면 전체로 연다. heading이 있으면 그 부분만 먼저 보여 준다.
void showDoc(BuildContext context, StudioData data, String path, {String? heading, String? url}) {
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    builder: (_) => DocPage(data: data, path: path, heading: heading, url: url),
  ));
}

/// 그림을 화면 전체로 연다(두 손가락으로 확대).
void showAsset(BuildContext context, StudioData data, String logical, {String? alt}) {
  final src = data.asset(logical);
  if (src == null) return;
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => AssetPage(src: src, alt: alt ?? StudioData.fileName(logical)),
  ));
}

/// 화면 위 공통 머리줄: 뒤로 가기, 제목, 오른쪽 도구.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle, this.actions = const [], this.onBack, this.close = false});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Material(
      color: colors.ground,
      child: SafeArea(
        bottom: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.rule))),
          child: Row(children: [
            IconButton(
              tooltip: close ? '닫기' : '뒤로',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icon(close ? Icons.close : Icons.arrow_back, size: 20, color: colors.ink),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: colors.sub)),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall),
              ]),
            ),
            ...actions,
          ]),
        ),
      ),
    );
  }
}

class DocPage extends StatefulWidget {
  const DocPage({super.key, required this.data, required this.path, this.heading, this.url});

  final StudioData data;
  final String path;
  final String? heading;
  final String? url;

  @override
  State<DocPage> createState() => _DocPageState();
}

class _DocPageState extends State<DocPage> {
  late final String? _part = widget.heading == null ? null : widget.data.excerpt(widget.path, widget.heading);
  late bool _whole = _part == null;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final d = widget.data;
    final showPart = !_whole && _part != null;
    return Scaffold(
      body: Column(children: [
        SheetHeader(
          title: d.docTitle(widget.path),
          subtitle: widget.path,
          close: true,
          actions: [
            if (widget.url != null)
              IconButton(
                tooltip: '출처 링크 열기',
                onPressed: () => openExternal(context, widget.url!),
                icon: Icon(Icons.open_in_new, size: 20, color: colors.ink),
              ),
          ],
        ),
        if (_part != null)
          Container(
            width: double.infinity,
            color: colors.wash,
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(children: [
              Expanded(
                child: Text(showPart ? '‘${_clean(widget.heading!)}’ 부분만 보는 중' : '전체 문서',
                    style: TextStyle(fontSize: 13, color: colors.sub)),
              ),
              TextButton(
                onPressed: () => setState(() => _whole = !_whole),
                style: TextButton.styleFrom(foregroundColor: colors.ink),
                child: Text(showPart ? '전체 문서 보기' : '해당 부분만 보기'),
              ),
            ]),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: StudioMarkdown(data: d, text: showPart ? _part : d.docBody(widget.path), fromPath: widget.path),
          ),
        ),
      ]),
    );
  }

  static String _clean(String pattern) => pattern.replaceAll(RegExp(r'[\^\$\\]'), '').split('|').first;
}

class AssetPage extends StatelessWidget {
  const AssetPage({super.key, required this.src, required this.alt});

  final String src;
  final String alt;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Scaffold(
      backgroundColor: colors.ground,
      body: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.asset(src, fit: BoxFit.contain, semanticLabel: alt)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(backgroundColor: colors.sheet),
                icon: Icon(Icons.close, color: colors.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(alt, style: TextStyle(fontSize: 14, color: colors.sub)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// 원문 마크다운. 링크는 앱 안 문서·그림으로, 바깥 주소는 브라우저로 연다.
class StudioMarkdown extends StatelessWidget {
  const StudioMarkdown({super.key, required this.data, required this.text, this.fromPath});

  final StudioData data;
  final String? text;
  final String? fromPath;

  MarkdownStyleSheet _sheet(StudioColors colors) {
    final body = TextStyle(fontSize: 15, height: 1.6, color: colors.ink);
    return MarkdownStyleSheet(
    a: TextStyle(color: colors.ink, decoration: TextDecoration.underline, decorationColor: colors.sub),
    p: body,
    pPadding: EdgeInsets.zero,
    code: TextStyle(fontSize: 13, fontFamily: 'monospace', color: colors.ink, backgroundColor: colors.wash),
    h1: TextStyle(fontSize: 22, height: 1.35, fontWeight: FontWeight.w700, color: colors.ink),
    h1Padding: const EdgeInsets.only(top: 8),
    h2: TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w700, color: colors.ink),
    h2Padding: const EdgeInsets.only(top: 8),
    h3: TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w700, color: colors.ink),
    h3Padding: const EdgeInsets.only(top: 4),
    h4: TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700, color: colors.ink),
    h4Padding: EdgeInsets.zero,
    h5: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink),
    h5Padding: EdgeInsets.zero,
    h6: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.sub),
    h6Padding: EdgeInsets.zero,
    em: const TextStyle(fontStyle: FontStyle.italic),
    strong: const TextStyle(fontWeight: FontWeight.w700),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    blockquote: TextStyle(fontSize: 15, height: 1.6, color: colors.sub),
    img: body,
    checkbox: body,
    blockSpacing: 12,
    listIndent: 22,
    listBullet: body,
    listBulletPadding: const EdgeInsets.only(right: 4),
    tableHead: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink),
    tableBody: TextStyle(fontSize: 14, height: 1.5, color: colors.ink),
    tableHeadAlign: TextAlign.left,
    tablePadding: const EdgeInsets.only(bottom: 4),
    tableBorder: TableBorder.all(color: colors.rule),
    tableColumnWidth: const FixedColumnWidth(168),
    tableScrollbarThumbVisibility: false,
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    tableHeadCellsDecoration: BoxDecoration(color: colors.wash),
    tableVerticalAlignment: TableCellVerticalAlignment.top,
    blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
    blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: colors.ruleStrong, width: 3))),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(color: colors.wash, borderRadius: BorderRadius.circular(4)),
    horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: colors.rule))),
  );
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return MarkdownBody(
      data: text ?? '',
      styleSheet: _sheet(colors),
      styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
      onTapLink: (label, href, title) => _tap(context, href),
      imageBuilder: (uri, title, alt) {
        final target = data.resolveLink(Uri.decodeFull(uri.toString()), fromPath);
        if (target?.kind == 'asset') {
          final src = data.asset(target!.path)!;
          return GestureDetector(
            onTap: () => showAsset(context, data, target.path!, alt: alt),
            child: Image.asset(src, semanticLabel: alt),
          );
        }
        if (target?.kind == 'external') return Image.network(target!.url!, semanticLabel: alt, errorBuilder: (_, _, _) => Text(alt ?? ''));
        return Text(alt ?? '', style: TextStyle(color: colors.sub));
      },
    );
  }

  void _tap(BuildContext context, String? href) {
    final t = data.resolveLink(href, fromPath);
    if (t == null) return;
    switch (t.kind) {
      case 'external':
        openExternal(context, t.url!);
      case 'doc':
        showDoc(context, data, t.path!, heading: t.fragment == null || t.fragment!.isEmpty ? null : t.fragment);
      case 'asset':
        showAsset(context, data, t.path!);
      case 'fragment':
        if (fromPath != null) showDoc(context, data, fromPath!, heading: t.fragment);
    }
  }
}
