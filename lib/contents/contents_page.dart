import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../strategy/viewers.dart';
import '../theme.dart';
import 'drive_store.dart';
import 'preview_page.dart';

TextStyle _sub(StudioColors colors) => TextStyle(fontSize: 13, height: 1.45, color: colors.sub);

/// Contents 화면: Google Drive 제작물 폴더의 하위 폴더와 파일을 모두 보여 준다(웹의 #/contents).
/// 폴더를 누르면 본문 안에서 다음 화면으로 넘어가고, 뒤로 가기로 돌아온다.
class ContentsView extends StatefulWidget {
  const ContentsView({super.key, required this.store, required this.navKey, this.active = true});

  final DriveStore store;
  final GlobalKey<NavigatorState> navKey;

  /// 이 화면이 보일 때만 휴대폰 뒤로 가기를 받는다.
  final bool active;

  @override
  State<ContentsView> createState() => _ContentsViewState();
}

class _ContentsViewState extends State<ContentsView> {
  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      enabled: widget.active,
      onPopWithResult: (_) => widget.navKey.currentState?.maybePop(),
      child: Navigator(
        key: widget.navKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => FolderPage(store: widget.store, folderId: rootFolderId)),
      ),
    );
  }
}

/// 폴더 하나의 화면. 연결 전이면 연결 안내를, 불러오는 중이면 진행 상황을 보여 준다.
class FolderPage extends StatelessWidget {
  const FolderPage({super.key, required this.store, required this.folderId});

  final DriveStore store;
  final String folderId;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store;
        final isRoot = folderId == rootFolderId;
        final body = <Widget>[
          _StatusBar(store: s),
          const SizedBox(height: 16),
          Text(isRoot ? 'Contents' : s.items[folderId]?.name ?? '제작물', style: Theme.of(context).textTheme.headlineLarge),
          if (isRoot) Text('Google Drive 제작물', style: _sub(colors)),
        ];
        if (s.root == null && s.status != DriveStatus.loading) {
          body.add(_ConnectCard(store: s));
        } else if (s.status == DriveStatus.loading && s.root == null) {
          body.add(_Loading(store: s));
        } else {
          if (s.status == DriveStatus.loading) body.add(_Loading(store: s));
          body.addAll(_folder(context, s));
        }
        return Scaffold(
          body: RefreshIndicator(
            color: colors.ink,
            backgroundColor: colors.sheet,
            onRefresh: () async {
              if (s.connected) await s.refresh();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
              children: body,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _folder(BuildContext context, DriveStore s) {
    final colors = StudioColors.of(context);
    final id = s.items.containsKey(folderId) ? folderId : rootFolderId;
    final f = s.items[id];
    final crumbs = s.pathTo(id);
    final kids = s.kids(id);
    final folders = kids.where((k) => k.isFolder).toList();
    final files = kids.where((k) => !k.isFolder).toList();
    return [
      const SizedBox(height: 16),
      Row(children: [
        if (id != rootFolderId)
          IconButton(
            tooltip: '상위 폴더',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, size: 20, color: colors.ink),
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(children: [
              for (var i = 0; i < crumbs.length; i++) ...[
                if (i > 0) Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('/', style: TextStyle(color: colors.ruleStrong))),
                if (i == crumbs.length - 1)
                  Text(crumbs[i].name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink))
                else
                  InkWell(
                    onTap: () => _goTo(context, s, crumbs[i].id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(crumbs[i].name, style: TextStyle(fontSize: 15, color: colors.sub)),
                    ),
                  ),
              ],
            ]),
          ),
        ),
        IconButton(
          tooltip: '폴더 트리',
          onPressed: () => _showTree(context, s, id),
          icon: Icon(Icons.account_tree_outlined, size: 20, color: colors.ink),
        ),
        if (f != null)
          IconButton(
            tooltip: 'Drive에서 폴더 열기',
            onPressed: () => openExternal(context, f.openUrl),
            icon: Icon(Icons.open_in_new, size: 20, color: colors.ink),
          ),
      ]),
      if (folders.isNotEmpty) ...[
        _head(context, '폴더', folders.length),
        for (final d in folders) _FolderTile(store: s, folder: d, onTap: () => _open(context, s, d.id)),
      ],
      if (files.isNotEmpty) ...[
        _head(context, '파일', files.length),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 720 ? 4 : box.maxWidth >= 520 ? 3 : 2;
          const gap = 10.0;
          final w = (box.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final file in files) SizedBox(width: w, child: _FileCard(store: s, file: file)),
          ]);
        }),
      ],
      if (folders.isEmpty && files.isEmpty && s.status != DriveStatus.loading)
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: colors.rule), borderRadius: BorderRadius.circular(4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('이 폴더는 비어 있습니다', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink)),
            SizedBox(height: 6),
            Text('Drive에 파일을 올린 뒤 새로고침을 누르면 바로 보입니다.', style: _sub(colors)),
          ]),
        ),
    ];
  }

  Widget _head(BuildContext context, String title, int n) {
    final colors = StudioColors.of(context);
    return Container(
        margin: const EdgeInsets.only(top: 24, bottom: 10),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.ruleStrong))),
        child: Row(children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.ink)),
          const SizedBox(width: 8),
          Text('$n개', style: _sub(colors)),
        ]),
      );
  }

  void _open(BuildContext context, DriveStore s, String id) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FolderPage(store: s, folderId: id)));
  }

  /// 경로의 폴더로 바로 간다: 루트부터 그 폴더까지 화면을 다시 쌓는다.
  void _goTo(BuildContext context, DriveStore s, String id) {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    for (final c in s.pathTo(id).skip(1)) {
      nav.push(MaterialPageRoute<void>(builder: (_) => FolderPage(store: s, folderId: c.id)));
    }
  }

  void _showTree(BuildContext context, DriveStore s, String currentId) {
    final colors = StudioColors.of(context);
    final open = {for (final f in s.pathTo(currentId)) f.id};
    final rows = <Widget>[];
    void node(String id, int depth) {
      final f = s.items[id];
      if (f == null) return;
      final sub = s.kids(id).where((k) => k.isFolder).toList();
      final c = s.countDeep(id);
      final current = id == currentId;
      rows.add(InkWell(
        onTap: () {
          Navigator.of(context, rootNavigator: true).pop();
          _goTo(context, s, id);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.fromLTRB(12 + depth * 16.0, 6, 16, 6),
          decoration: BoxDecoration(
            color: current ? colors.wash : null,
            border: current ? Border(left: BorderSide(color: colors.ink, width: 2)) : null,
          ),
          child: Row(children: [
            SizedBox(
              width: 16,
              child: Text(sub.isEmpty ? '·' : (open.contains(id) || depth == 0 ? '▾' : '▸'), style: TextStyle(color: colors.sub)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(depth == 0 ? (f.name.isEmpty ? 'Contents' : f.name) : f.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: current ? FontWeight.w700 : null, color: colors.ink)),
            ),
            Text('${c.files}', style: TextStyle(fontSize: 12, color: colors.sub)),
          ]),
        ),
      ));
      if (open.contains(id) || depth == 0) {
        for (final k in sub) {
          node(k.id, depth + 1);
        }
      }
    }

    node(rootFolderId, 0);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colors.sheet,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scroll) => ListView(controller: scroll, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('폴더', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.sub)),
          ),
          ...rows,
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

/// 위 상태 줄: 연결 상태, 불러온 시각, 새로고침, 연결 해제.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.store});

  final DriveStore store;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = store;
    final (label, dot, color) = s.connected
        ? ('Google Drive 연결됨', colors.ok, colors.ink)
        : s.expired
            ? ('연결이 만료되었습니다', colors.hy, colors.hy)
            : ('연결 안 됨', colors.ruleStrong, colors.sub);
    final loaded = s.loadedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: colors.sheet, border: Border.all(color: colors.rule), borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
          if (s.connected) ...[
            IconButton(
              tooltip: s.status == DriveStatus.loading ? '불러오는 중' : '새로고침',
              onPressed: s.status == DriveStatus.loading ? null : s.refresh,
              icon: Icon(Icons.refresh, size: 20, color: colors.ink),
            ),
            TextButton(
              onPressed: s.disconnect,
              style: TextButton.styleFrom(foregroundColor: colors.sub),
              child: const Text('연결 해제'),
            ),
          ] else if (s.root != null)
            TextButton.icon(
              onPressed: s.connecting ? null : s.connect,
              style: TextButton.styleFrom(foregroundColor: colors.ink),
              icon: const _DriveMark(),
              label: const Text('다시 연결'),
            ),
        ]),
        if (loaded != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Text('불러온 시각 ${two(loaded.hour)}:${two(loaded.minute)} · 폴더 ${s.folders} · 파일 ${s.files}', style: _sub(colors)),
          ),
        // 연결 안내 카드가 보일 때는 카드 안에만 오류를 적는다(같은 문구를 두 번 보이지 않게).
        if (s.message.isNotEmpty && s.root != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6, bottom: 4),
            child: Semantics(liveRegion: true, child: Text(s.message, style: TextStyle(fontSize: 13, height: 1.45, color: colors.no))),
          ),
      ]),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.store});

  final DriveStore store;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = store;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.sheet, borderRadius: studioCard),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.expired ? 'Google Drive 연결이 만료되었습니다' : 'Google Drive를 연결해 주세요',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.ink)),
        const SizedBox(height: 8),
        Text('콘텐츠 제작물은 Google Drive 폴더에서 관리합니다. 연결하면 하위 폴더와 파일을 모두 불러오고, 이미지와 영상을 바로 미리 볼 수 있습니다.',
            style: TextStyle(fontSize: 14, height: 1.55, color: colors.sub)),
        const SizedBox(height: 6),
        Text('연결 정보는 앱을 켜 둔 동안에만 머물고 따로 저장하지 않습니다. 앱을 새로 열면 다시 연결해 주세요.',
            style: TextStyle(fontSize: 14, height: 1.55, color: colors.sub)),
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: s.connecting ? null : s.connect,
            style: FilledButton.styleFrom(
              backgroundColor: colors.ink,
              foregroundColor: colors.sheet,
              disabledBackgroundColor: colors.ink.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            icon: const _DriveMark(),
            label: Text(s.connecting ? '연결하는 중' : (s.expired ? 'Google Drive 다시 연결' : 'Google Drive 연결')),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => openExternal(context, rootFolderUrl),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.ink,
              side: BorderSide(color: colors.rule),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Drive에서 폴더 열기'),
          ),
        ),
        if (s.message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(s.message, style: TextStyle(fontSize: 13, height: 1.45, color: colors.no)),
        ],
      ]),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.store});

  final DriveStore store;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Semantics(
          liveRegion: true,
          child: Row(children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink)),
            const SizedBox(width: 10),
            Expanded(child: Text('Drive 폴더를 불러오는 중입니다 · 폴더 ${store.folders}개, 파일 ${store.files}개', style: _sub(colors))),
          ]),
        ),
      );
  }
}

/// Google Drive 표시(웹과 같은 여섯 색 삼각형을 단순화한 점).
class _DriveMark extends StatelessWidget {
  const _DriveMark();

  @override
  Widget build(BuildContext context) => const Icon(Icons.add_to_drive, size: 18);
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.store, required this.folder, required this.onTap});

  final DriveStore store;
  final DriveFile folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final c = store.countDeep(folder.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.sheet,
        shape: RoundedRectangleBorder(side: BorderSide(color: colors.rule), borderRadius: BorderRadius.circular(4)),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(children: [
              Icon(Icons.folder_outlined, size: 22, color: colors.sub),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink)),
                  Text('${c.folders > 0 ? '폴더 ${c.folders} · ' : ''}파일 ${c.files}', style: _sub(colors)),
                ]),
              ),
              Icon(Icons.chevron_right, color: colors.sub),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.store, required this.file});

  final DriveStore store;
  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final t = file.thumb(480);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: colors.sheet, borderRadius: studioCard),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          label: '${file.name} 미리보기',
          child: InkWell(
            onTap: () => showPreview(context, store, file),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: colors.wash),
                if (t != null)
                  Image.network(
                    t,
                    fit: BoxFit.cover,
                    headers: kIsWeb ? null : store.authHeaders,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: colors.sheet, border: Border.all(color: colors.rule), borderRadius: BorderRadius.circular(3)),
                    child: Text(file.kindName, style: TextStyle(fontSize: 11, color: colors.sub)),
                  ),
                ),
                if (file.kind == 'video')
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: colors.ground.withValues(alpha: .86), shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow, color: colors.ink),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: colors.ink)),
            const SizedBox(height: 2),
            Text(file.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.sub)),
          ]),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => openExternal(context, file.openUrl),
            style: TextButton.styleFrom(foregroundColor: colors.sub, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 40)),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('Drive에서 열기', style: TextStyle(fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}
