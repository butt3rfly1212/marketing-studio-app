import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../strategy/viewers.dart';
import '../theme.dart';
import 'drive_store.dart';

/// 파일 미리보기. 이미지는 앱 안에서 크게, 영상은 앱 안에서 재생한다.
/// 그 밖의 파일(PDF, Google 문서 등)과 웹의 영상은 Drive 미리보기 화면으로 연다.
void showPreview(BuildContext context, DriveStore store, DriveFile f) {
  final inApp = f.kind == 'image' || (f.kind == 'video' && !kIsWeb);
  if (!inApp) {
    openExternal(context, f.kind == 'video' || f.kind == 'pdf' ? f.previewUrl : f.openUrl);
    return;
  }
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => PreviewPage(store: store, file: f),
  ));
}

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, required this.store, required this.file});

  final DriveStore store;
  final DriveFile file;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  Uint8List? _bytes;
  VideoPlayerController? _video;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = widget.file;
    try {
      if (f.kind == 'image') {
        final b = await widget.store.download(f);
        if (mounted) setState(() => _bytes = b);
      } else {
        final c = VideoPlayerController.networkUrl(Uri.parse(f.mediaUrl), httpHeaders: widget.store.authHeaders);
        await c.initialize();
        if (!mounted) {
          await c.dispose();
          return;
        }
        await c.play();
        setState(() => _video = c);
      }
    } on DriveExpired {
      if (mounted) setState(() => _error = '연결이 만료되었습니다. 닫은 뒤 ‘다시 연결’을 눌러 주세요.');
    } catch (_) {
      if (mounted) setState(() => _error = '앱에서 열지 못했습니다. Drive 미리보기로 열어 주세요.');
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final f = widget.file;
    final v = _video;
    Widget stage;
    if (_error != null) {
      stage = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.5, color: colors.ink)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => openExternal(context, f.previewUrl),
            style: OutlinedButton.styleFrom(foregroundColor: colors.ink, side: BorderSide(color: colors.ruleStrong)),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Drive 미리보기로 열기'),
          ),
        ]),
      );
    } else if (_bytes != null) {
      stage = InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(_bytes!, fit: BoxFit.contain, semanticLabel: f.name)));
    } else if (v != null) {
      stage = Center(
        child: AspectRatio(
          aspectRatio: v.value.aspectRatio,
          child: GestureDetector(
            onTap: () => setState(() => v.value.isPlaying ? v.pause() : v.play()),
            child: Stack(alignment: Alignment.bottomCenter, children: [
              VideoPlayer(v),
              VideoProgressIndicator(v, allowScrubbing: true, colors: VideoProgressColors(playedColor: colors.ink)),
              if (!v.value.isPlaying)
                Center(child: Icon(Icons.play_circle_outline, size: 64, color: colors.ink)),
            ]),
          ),
        ),
      );
    } else {
      stage = Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink)),
        SizedBox(width: 10),
        Text('불러오는 중입니다', style: TextStyle(fontSize: 14, color: colors.sub)),
      ]);
    }
    return Scaffold(
      backgroundColor: colors.ground,
      body: Column(children: [
        SheetHeader(
          title: f.name,
          subtitle: f.meta,
          close: true,
          actions: [
            IconButton(
              tooltip: 'Drive에서 열기',
              onPressed: () => openExternal(context, f.openUrl),
              icon: Icon(Icons.open_in_new, size: 20, color: colors.ink),
            ),
          ],
        ),
        Expanded(child: Center(child: stage)),
      ]),
    );
  }
}
