import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../strategy/blocks.dart' show Fold;
import '../theme.dart';
import 'metrics.dart';
import 'operation_store.dart';

TextStyle _sub(StudioColors colors) => TextStyle(fontSize: 13, height: 1.45, color: colors.sub);

/// Operation 채널 성과(웹의 #/operation).
/// 기간과 채널별 합계, 날짜별 성과 지도, 선택한 채널의 차트와 수집 기록.
class OperationView extends StatefulWidget {
  const OperationView({super.key, required this.store});

  final OperationStore store;

  @override
  State<OperationView> createState() => _OperationViewState();
}

class _OperationViewState extends State<OperationView> {
  final _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.store.ensureLoaded();
  }

  @override
  void didUpdateWidget(OperationView old) {
    super.didUpdateWidget(old);
    if (old.store != widget.store) widget.store.ensureLoaded();
  }

  void _pin(String channel, String date) {
    widget.store.selectChannel(channel, pinDate: date);
    final ctx = _chartKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store;
        final children = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('채널 성과', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text('선택한 기간의 채널별 지표와 앞 기간의 실적을 비교합니다.', style: _sub(colors)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _Controls(store: s),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(
                s.status == OpStatus.loading
                    ? '채널별 지표를 불러오고 있습니다.'
                    : s.status == OpStatus.error
                        ? s.error
                        : '새로고침은 저장된 지표를 다시 읽습니다. 새 지표 수집은 /channel-metrics에서 실행합니다.',
                style: TextStyle(fontSize: 13, height: 1.45, color: s.status == OpStatus.error ? colors.no : colors.sub),
              ),
            ),
          ),
        ];
        Widget box(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: child);
        if (s.status == OpStatus.error) {
          children.add(box(_Empty(
            title: '지표를 불러오지 못했습니다',
            body: s.error,
            action: OutlinedButton(
              onPressed: s.load,
              style: OutlinedButton.styleFrom(foregroundColor: colors.ink, side: BorderSide(color: colors.ruleStrong)),
              child: const Text('다시 시도'),
            ),
          )));
        } else if (s.status != OpStatus.ready) {
          children.add(box(const _Empty(title: '저장된 데이터를 확인하는 중입니다.')));
        } else if (!s.hasDataInRange) {
          children.add(box(const _Empty(title: '선택한 기간에 수집된 데이터가 없습니다', body: '기간을 바꾸거나 /channel-metrics로 지표를 수집해 주세요.')));
        } else {
          children
            ..add(box(_PerfMap(store: s, onPick: _pin)))
            ..add(box(_Cards(store: s)))
            ..add(box(_Detail(store: s, chartKey: _chartKey)));
        }
        children.add(const SizedBox(height: 48));
        return RefreshIndicator(
          color: colors.ink,
          backgroundColor: colors.sheet,
          onRefresh: s.load,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: children),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, this.body, this.action});

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(border: Border.all(color: colors.rule), borderRadius: studioControl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.ink)),
          if (body != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(body!, style: _sub(colors))),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 12), child: action),
        ]),
      );
  }
}

/// 값이 바뀌면 숫자가 부드럽게 올라간다(웹의 자리 넘김 숫자 대신).
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style, this.suffix = ''});

  final double? value;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return Text('—', style: style);
    final still = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: still ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutQuart,
      builder: (_, x, _) => Text('${numText(x == v ? v : x.roundToDouble())}$suffix', style: style, semanticsLabel: '${numText(v)}$suffix'),
    );
  }
}

// ───────────────────────────── 기간·새로고침

class _Controls extends StatelessWidget {
  const _Controls({required this.store});

  final OperationStore store;

  Future<void> _pickRange(BuildContext context) async {
    final colors = StudioColors.of(context);
    final s = store;
    final today = parseYmd(kstToday());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.utc(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(start: parseYmd(s.start), end: parseYmd(s.end)),
      helpText: '기간 직접 설정',
      saveText: '기간 적용',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: colors.ink, onPrimary: colors.sheet, surface: colors.sheet),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final msg = s.setCustom(ymd(picked.start), ymd(picked.end));
    if (msg != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = store;
    final loading = s.status == OpStatus.loading;
    Widget seg(String label, bool on, VoidCallback onTap) => Expanded(
          child: Semantics(
            selected: on,
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: studioControl,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? colors.ink : Colors.transparent, borderRadius: BorderRadius.circular(3)),
                child: Text(label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: on ? colors.sheet : colors.sub)),
              ),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: colors.sheet, border: Border.all(color: colors.rule), borderRadius: studioControl),
        child: Row(children: [
          for (final n in [7, 30, 90]) seg('$n일', !s.custom && s.days == n, () => s.setPreset(n)),
          seg('직접 설정', s.custom, () => _pickRange(context)),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Text(
            '${s.start.replaceAll('-', '.')} — ${s.end.replaceAll('-', '.')}\n${latest(s.rows) == null ? '수집 기록 없음' : '수집 ${short(latest(s.rows))}'}',
            style: _sub(colors),
          ),
        ),
        OutlinedButton.icon(
          onPressed: loading ? null : s.load,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.ink,
            side: BorderSide(color: colors.rule),
            shape: RoundedRectangleBorder(borderRadius: studioControl),
            minimumSize: const Size(0, 40),
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(loading ? '불러오는 중' : '새로고침'),
        ),
      ]),
    ]);
  }
}

// ───────────────────────────── 날짜별 성과 지도

class _Drop {
  _Drop(this.channel, this.date, this.value, this.avg, this.hot, this.x, this.y, this.r);
  final String channel;
  final String date;
  final double? value;
  final double avg;
  final bool hot;
  final double x;
  final double y;
  final double r;
}

class _PerfMap extends StatefulWidget {
  const _PerfMap({required this.store, required this.onPick});

  final OperationStore store;
  final void Function(String channel, String date) onPick;

  @override
  State<_PerfMap> createState() => _PerfMapState();
}

class _PerfMapState extends State<_PerfMap> with SingleTickerProviderStateMixin {
  static const lane = 50.0;
  late final AnimationController _drop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  String _key = '';
  _Drop? _hover;

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  List<_Drop> _layout(double w, List<String> ds) {
    final s = widget.store;
    final left = w < 500 ? 104.0 : 118.0;
    final colW = (w - left) / ds.length;
    final maxR = math.max(2.5, math.min(lane * .36, colW * .46));
    final out = <_Drop>[];
    for (var ci = 0; ci < Channel.all.length; ci++) {
      final c = Channel.all[ci];
      final vals = daily(s.subset(c.id, allAccounts: true), c.head, ds);
      final ok = vals.whereType<double>().toList();
      final mx = ok.fold<double>(1, math.max);
      final avg = ok.isEmpty ? 0.0 : ok.reduce((a, b) => a + b) / ok.length;
      for (var di = 0; di < ds.length; di++) {
        final v = vals[di];
        final hot = v != null && avg > 0 && v >= avg * 1.5;
        out.add(_Drop(c.id, ds[di], v, avg, hot, left + colW * di + colW / 2, ci * lane + lane / 2,
            v == null ? math.min(4, maxR * .6) : math.max(1.6, math.sqrt(math.max(0, v) / mx) * maxR)));
      }
    }
    return out;
  }

  _Drop? _nearest(List<_Drop> drops, Offset p) {
    _Drop? best;
    var bd = 1e9;
    for (final d in drops) {
      final dd = (Offset(d.x, d.y) - p).distance;
      if (dd < bd && dd < math.max(16, d.r + 8)) {
        bd = dd;
        best = d;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = widget.store;
    final ds = s.dates;
    final key = '${s.start}|${s.end}|${s.rows.length}';
    if (key != _key) {
      _key = key;
      _hover = null;
      if (MediaQuery.of(context).disableAnimations) {
        _drop.value = 1;
      } else {
        _drop.forward(from: 0);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, box) {
        final drops = _layout(box.maxWidth, ds);
        final hot = drops.where((d) => d.hot).length;
        final h = _hover;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('날짜별 성과 지도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.ink)),
          Text('${s.start.replaceAll('-', '.')} — ${s.end.replaceAll('-', '.')} · 평균의 1.5배를 넘은 날 $hot일', style: _sub(colors)),
          const SizedBox(height: 8),
          Semantics(
            label: '날짜별 성과 지도. 점을 누르면 그 채널과 날짜를 차트에서 봅니다.',
            child: GestureDetector(
              onTapDown: (e) {
                final d = _nearest(drops, e.localPosition);
                setState(() => _hover = d);
                if (d != null) widget.onPick(d.channel, d.date);
              },
              child: AnimatedBuilder(
                animation: _drop,
                builder: (_, _) => CustomPaint(
                  size: Size(box.maxWidth, lane * 3),
                  painter: _MapPainter(drops, s.selected, _drop.value, h, colors),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 22,
            child: h == null
                ? null
                : Text(
                    '${Channel.byId(h.channel).name} ${dot(h.date)} · ${h.value == null ? '아직 집계 전' : '${numText(h.value)}${Channel.byId(h.channel).metrics[Channel.byId(h.channel).head]!.$2}'}'
                    '${h.value != null && h.avg > 0 ? ' · 평균의 ${(h.value! / h.avg * 100).round()}%' : ''}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.ink),
                  ),
          ),
        ]);
      }),
      const Wrap(spacing: 12, runSpacing: 4, children: [
        _Legend(kind: 0, text: '점 하나 = 그 채널의 하루'),
        _Legend(kind: 1, text: '클수록 많이 본 날'),
        _Legend(kind: 2, text: '진한 점: 채널 평균의 1.5배 이상'),
        _Legend(kind: 3, text: '빈 원: 아직 집계 전'),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.kind, required this.text});

  final int kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final size = kind == 1 ? 12.0 : 8.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kind == 3 ? null : (kind == 2 ? colors.ink : colors.ink.withValues(alpha: 0.35)),
          border: kind == 3 ? Border.all(color: colors.no, width: 1.2) : null,
        ),
      ),
      const SizedBox(width: 5),
      Text(text, style: TextStyle(fontSize: 12, color: colors.sub)),
    ]);
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.drops, this.selected, this.t, this.hover, this.colors);

  final StudioColors colors;

  final List<_Drop> drops;
  final String selected;
  final double t;
  final _Drop? hover;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    const lane = _PerfMapState.lane;
    for (var ci = 0; ci < Channel.all.length; ci++) {
      final c = Channel.all[ci];
      final y = ci * lane + lane / 2;
      final sel = c.id == selected;
      if (sel) canvas.drawRect(Rect.fromLTWH(0, ci * lane + 2, size.width, lane - 4), Paint()..color = colors.wash);
      _text(canvas, c.name, Offset(8, y - 16), TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? colors.ink : colors.sub));
      _text(canvas, c.metrics[c.head]!.$1, Offset(8, y + 2), TextStyle(fontSize: 11, color: colors.sub));
    }
    final perLane = math.max(1, drops.length ~/ Channel.all.length);
    for (var i = 0; i < drops.length; i++) {
      final d = drops[i];
      // 왼쪽 날짜부터, 위 채널부터 차례로 떨어져 자리를 잡는다.
      final k = (t * 1.8 - (i % perLane) / perLane * 0.6 - (i ~/ perLane) * 0.1).clamp(0.0, 1.0);
      if (k == 0) continue;
      final e = 1 - math.pow(1 - k, 3) * math.cos(k * 7) * .6;
      final y = -12 + (d.y + 12) * math.min(1.04, e);
      final r = d.r * (d == hover ? 1.35 : 1);
      if (d.value == null) {
        canvas.drawCircle(Offset(d.x, y), r, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = colors.no);
        continue;
      }
      final a = d.hot ? 1.0 : (d.channel == selected ? .42 : .24);
      canvas.drawCircle(Offset(d.x, y), r, Paint()..color = colors.ink.withValues(alpha: a));
      if (d == hover) {
        canvas.drawCircle(Offset(d.x, y), r + 3, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.ink);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: s, style: style.copyWith(fontFamilyFallback: fontFallback)), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')
      ..layout(maxWidth: 100);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.t != t || old.selected != selected || old.hover != hover || old.drops != drops || old.colors != colors;
}

// ───────────────────────────── 채널 카드

class _Cards extends StatelessWidget {
  const _Cards({required this.store});

  final OperationStore store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final ds = s.dates;
    final pr = s.prevRange;
    return LayoutBuilder(builder: (context, limits) {
      final cards = [for (final c in Channel.all) _card(context, s, c, ds, pr)];
      return limits.maxWidth >= 780
          ? Row(spacing: 16, children: [for (final card in cards) Expanded(child: card)])
          : Column(children: cards);
    });
  }

  Widget _card(BuildContext context, OperationStore s, Channel c, List<String> ds, (String, String)? pr) {
    final colors = StudioColors.of(context);
    final all = s.subset(c.id, allAccounts: true);
    final now = metricValue(all, c.head);
    final before = pr == null ? null : metricValue(s.rows.where((r) => r.channel == c.id && s.within(r, pr.$1, pr.$2)).toList(), c.head);
    int? pct;
    if (before != null && before != 0 && now != null) pct = ((now - before) / before * 100).round();
    final on = c.id == s.selected;
    final primary = on ? colors.ground : colors.ink;
    final secondary = on ? Color.lerp(colors.ground, colors.ink, .29)! : colors.sub;
    final spark = daily(all, c.head, ds).whereType<double>().toList();
    final last = latest(all);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: on,
        button: true,
        label: '${c.name} 선택',
        child: Material(
          color: on ? colors.ink : colors.sheet,
          shape: RoundedRectangleBorder(
            borderRadius: studioCard,
          ),
          child: InkWell(
            borderRadius: studioCard,
            onTap: () => s.selectChannel(c.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c.name} · ${c.metrics[c.head]!.$1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondary)),
                    const SizedBox(height: 2),
                    // 숫자가 길면 증감은 다음 줄로 내려간다.
                    Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
                      CountUp(now, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: primary)),
                      if (pct != null) ...[
                        Tooltip(
                          message: '바로 앞 ${ds.length}일과 비교',
                          child: Text('${pct >= 0 ? '▲' : '▼'} ${pct.abs()}%',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? primary : colors.accentText)),
                        ),
                      ],
                    ]),
                    Text(last == null ? '수집 기록 없음' : '마지막 수집 ${short(last)} KST', style: TextStyle(fontSize: 12, color: secondary)),
                  ]),
                ),
                SizedBox(
                  width: 96,
                  height: 36,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('${s.start}${s.end}${spark.length}'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutQuart,
                    builder: (_, k, _) => CustomPaint(painter: _SparkPainter(spark, k, on ? colors.ground : colors.accentText)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.vals, this.k, this.color);

  final Color color;

  final List<double> vals;
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    if (vals.length < 2) return;
    final mx = vals.fold<double>(1, math.max);
    final path = Path();
    for (var i = 0; i < vals.length; i++) {
      final p = Offset(i / (vals.length - 1) * size.width, size.height - 2 - math.max(0, vals[i]) / mx * (size.height - 4));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final metric = path.computeMetrics().toList();
    final drawn = Path();
    for (final m in metric) {
      drawn.addPath(m.extractPath(0, m.length * k), Offset.zero);
    }
    canvas.drawPath(drawn, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.k != k || old.vals != vals || old.color != color;
}

// ───────────────────────────── 고른 채널의 지표, 차트, 상세 기록

class _Detail extends StatelessWidget {
  const _Detail({required this.store, required this.chartKey});

  final OperationStore store;
  final GlobalKey chartKey;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = store;
    final ch = s.channel;
    final rs = s.subset(s.selected);
    final accounts = s.accounts;
    final last = latest(rs);
    final m = s.metric;
    final note = m == 'avg_view_duration_sec'
        ? '조회수 가중 평균 · 조회수가 없으면 산출하지 않습니다.'
        : m == 'reach'
            ? '일별 도달 합계 · 기간 전체의 순수 도달 인원과 다릅니다.'
            : m == 'follower_count'
                ? '팔로워 증감 합계 · API에서 제공하지 않는 날짜는 미수집으로 표시합니다.'
                : '선택한 기간의 수집된 값 합계 · 미수집 날짜는 0으로 채우지 않습니다.';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Text(ch.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.ink)),
      Text('집계 지연 ${ch.delay} · 마지막 수집 ${last == null ? '없음' : '${short(last)} KST'}', style: _sub(colors)),
      if (accounts.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DropdownButton<String>(
            value: s.account,
            isExpanded: true,
            dropdownColor: colors.sheet,
            style: TextStyle(fontSize: 14, color: colors.ink),
            underline: Container(height: 1, color: colors.rule),
            items: [
              const DropdownMenuItem(value: '', child: Text('모든 계정')),
              for (final a in accounts) DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => s.selectAccount(v ?? ''),
          ),
        ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in ch.metrics.entries) _chip(context, s, e.key, e.value, metricValue(rs, e.key)),
        if (ch.id == 'google-search') _derivedCtr(context, rs),
      ]),
      Padding(padding: const EdgeInsets.only(top: 10), child: Text(note, style: _sub(colors))),
      const SizedBox(height: 12),
      KeyedSubtree(key: chartKey, child: _Chart(store: s)),
      const SizedBox(height: 16),
      Fold(label: '날짜별 상세 기록 펼쳐 보기', child: _LogTable(store: s)),
    ]);
  }

  Widget _chip(BuildContext context, OperationStore s, String key, (String, String) meta, double? v) {
    final colors = StudioColors.of(context);
    final on = s.metric == key;
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        onTap: () => s.selectMetric(key),
        borderRadius: studioControl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: on ? colors.ink : colors.sheet,
            border: Border.all(color: on ? colors.ink : colors.rule),
            borderRadius: studioControl,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meta.$1, style: TextStyle(fontSize: 12, color: on ? colors.sheet : colors.sub)),
            Text.rich(TextSpan(children: [
              TextSpan(text: numText(v), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (v != null) TextSpan(text: ' ${meta.$2}', style: const TextStyle(fontSize: 12)),
            ]), style: TextStyle(color: on ? colors.sheet : colors.ink)),
          ]),
        ),
      ),
    );
  }

  Widget _derivedCtr(BuildContext context, List<MetricRow> rs) {
    final colors = StudioColors.of(context);
    final im = metricValue(rs, 'impressions'), cl = metricValue(rs, 'clicks');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(border: Border.all(color: colors.rule, style: BorderStyle.solid), borderRadius: studioControl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('클릭률', style: TextStyle(fontSize: 12, color: colors.sub)),
        Text(im != null && im > 0 && cl != null ? '${numText(cl / im * 100)}%' : '—',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.ink)),
      ]),
    );
  }
}

/// 지표 차트. 손가락으로 끌거나 아래 슬라이더로 날짜별 값을 본다.
class _Chart extends StatefulWidget {
  const _Chart({required this.store});

  final OperationStore store;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  List<double?> _from = const [];
  List<double?> _to = const [];
  String _key = '';
  int? _at;
  int _pinSeen = 0;

  static const _pl = 44.0, _pr = 10.0, _pt = 14.0, _pb = 28.0, _h = 240.0;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _sync(List<String> ds, List<double?> vals) {
    final s = widget.store;
    final key = '${s.selected}|${s.account}|${s.metric}|${s.start}|${s.end}|${s.rows.length}';
    if (key == _key) return;
    // 지금 보이는 선에서 다음 모양으로 이어서 바뀐다.
    final k = Curves.easeOutQuart.transform(_anim.value);
    final shown = [for (var i = 0; i < _to.length; i++) _lerp(i < _from.length ? _from[i] : null, _to[i], k)];
    _from = [for (var i = 0; i < vals.length; i++) i < shown.length ? shown[i] : null];
    _to = vals;
    _key = key;
    _at = null;
    if (MediaQuery.of(context).disableAnimations) {
      _anim.value = 1;
    } else {
      _anim.forward(from: 0);
    }
  }

  static double? _lerp(double? a, double? b, double k) => b == null ? null : (a ?? 0) + (b - (a ?? 0)) * k;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = widget.store;
    final ch = s.channel;
    final u = ch.metrics[s.metric]!;
    final ds = s.dates;
    final vals = daily(s.subset(s.selected), s.metric, ds);
    _sync(ds, vals);
    if (s.pinSerial != _pinSeen) {
      _pinSeen = s.pinSerial;
      final i = s.pinnedDate == null ? -1 : ds.indexOf(s.pinnedDate!);
      if (i >= 0) _at = i;
    }
    final at = _at;
    final ok = vals.whereType<double>();
    final mn = math.min(0.0, ok.fold<double>(0, math.min));
    final mx = math.max(1.0, ok.fold<double>(1, math.max)) * 1.15;
    final readout = at == null
        ? '차트를 손가락으로 끌거나 슬라이더로 날짜별 값을 확인하세요'
        : '${dot(ds[at])} · ${u.$1} ${vals[at] == null ? '미수집' : '${numText(vals[at])}${u.$2}'}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${ch.name} · ${u.$1} 추이', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink)),
      Text('${s.start.replaceAll('-', '.')} — ${s.end.replaceAll('-', '.')} · 단위 ${u.$2} · 집계 지연 ${ch.delay}', style: _sub(colors)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        int idxAt(double x) => ds.length == 1 ? 0 : ((x - _pl) / (w - _pl - _pr) * (ds.length - 1)).round().clamp(0, ds.length - 1);
        return Semantics(
          label: '${ch.name} ${u.$1} 날짜별 차트. 정확한 수치는 아래 상세 기록에서 확인할 수 있습니다.',
          child: GestureDetector(
            onTapDown: (e) => setState(() => _at = idxAt(e.localPosition.dx)),
            onHorizontalDragUpdate: (e) => setState(() => _at = idxAt(e.localPosition.dx)),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, _) {
                final k = Curves.easeOutQuart.transform(_anim.value);
                final shown = [for (var i = 0; i < _to.length; i++) _lerp(i < _from.length ? _from[i] : null, _to[i], k)];
                // 채널을 바꾸는 동안 선이 예전 값에서 내려오므로, 눈금도 지금 보이는 값에 맞춰 함께 움직인다.
                final live = shown.whereType<double>();
                final top = math.max(mx, live.fold<double>(1, math.max) * 1.15);
                final bottom = math.min(mn, live.fold<double>(0, math.min));
                return CustomPaint(
                  size: Size(w, _h),
                  painter: _ChartPainter(ds: ds, vals: shown, real: vals, mn: bottom, mx: top, at: at, unit: u.$2, colors: colors),
                );
              },
            ),
          ),
        );
      }),
      Text(readout, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.ink)),
      if (ds.length > 1)
        Slider(
          value: (at ?? ds.length - 1).toDouble(),
          min: 0,
          max: (ds.length - 1).toDouble(),
          divisions: ds.length - 1,
          activeColor: colors.ink,
          inactiveColor: colors.rule,
          label: dot(ds[at ?? ds.length - 1]),
          semanticFormatterCallback: (v) => dot(ds[v.round()]),
          onChanged: (v) => setState(() => _at = v.round()),
        ),
    ]);
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.ds, required this.vals, required this.real, required this.mn, required this.mx, required this.at, required this.unit, required this.colors});

  final StudioColors colors;

  final List<String> ds;
  final List<double?> vals;
  final List<double?> real;
  final double mn;
  final double mx;
  final int? at;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    const pl = _ChartState._pl, pr = _ChartState._pr, pt = _ChartState._pt, pb = _ChartState._pb;
    canvas.clipRect(Offset.zero & size);  // 어떤 값이 와도 그래프 칸 밖으로 그리지 않는다.
    final n = ds.length;
    double x(int i) => pl + (size.width - pl - pr) * (n == 1 ? .5 : i / (n - 1));
    double y(double v) => pt + (size.height - pt - pb) * (1 - (v - mn) / ((mx - mn) == 0 ? 1 : (mx - mn)));
    final grid = Paint()
      ..color = colors.rule
      ..strokeWidth = 1;
    final label = TextStyle(fontSize: 10, color: colors.sub);
    for (var j = 0; j <= 4; j++) {
      final v = mn + (mx / 1.15 - mn) * j / 4;
      final yy = y(v);
      canvas.drawLine(Offset(pl, yy), Offset(size.width - pr, yy), grid);
      _text(canvas, numText(v.roundToDouble()), Offset(pl - 6, yy), label, alignRight: true);
    }
    final step = (n / (size.width < 500 ? 4 : 7)).ceil();
    for (var i = 0; i < n; i++) {
      if (i % step == 0 || i == n - 1) {
        _text(canvas, dot(ds[i]), Offset(x(i), size.height - 12), label, center: i != 0 && i != n - 1, alignRight: i == n - 1 && n > 1);
      }
    }
    // 수집된 날만 잇는다. 빈 날은 끊고 바닥에 빈 원을 둔다.
    final line = Path(), area = Path();
    var seg = <int>[];
    void flush() {
      if (seg.isEmpty) return;
      area.moveTo(x(seg.first), y(0));
      for (final i in seg) {
        area.lineTo(x(i), y(vals[i]!));
      }
      area.lineTo(x(seg.last), y(0));
      area.close();
      seg = [];
    }

    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v == null) {
        flush();
        continue;
      }
      seg.isEmpty ? line.moveTo(x(i), y(v)) : line.lineTo(x(i), y(v));
      seg.add(i);
    }
    flush();
    canvas.drawPath(area, Paint()..color = colors.accent.withValues(alpha: .16));
    canvas.drawPath(line, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = colors.accentText);
    for (var i = 0; i < vals.length; i++) {
      if (vals[i] == null) {
        canvas.drawCircle(Offset(x(i), y(0)), 3, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = colors.no);
      }
    }
    final a = at;
    if (a != null && a < n) {
      canvas.drawLine(Offset(x(a), pt), Offset(x(a), size.height - pb), Paint()
        ..color = colors.sub
        ..strokeWidth = 1);
      final v = real[a];
      if (v != null) {
        canvas.drawCircle(Offset(x(a), y(v)), 5, Paint()..color = colors.ink);
        canvas.drawCircle(Offset(x(a), y(v)), 5, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.ground);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at, TextStyle style, {bool alignRight = false, bool center = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    final dx = alignRight ? at.dx - tp.width : center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

/// 날짜별 상세 표(최근 날짜부터). — 는 미수집.
class _LogTable extends StatelessWidget {
  const _LogTable({required this.store});

  final OperationStore store;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final s = store;
    final ch = s.channel;
    final rs = s.subset(s.selected);
    final names = ch.metrics.keys.toList();
    final head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.sub);
    final cell = TextStyle(fontSize: 13, color: colors.ink);
    Widget pad(Widget w, {bool right = false}) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: w));
    final rows = s.dates.reversed.map((d) {
      final dr = rs.where((r) => r.date == d).toList();
      return TableRow(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.rule))),
        children: [
          pad(Text(d, style: cell.copyWith(fontWeight: FontWeight.w600))),
          for (final m in names) pad(Text(numText(metricValue(dr, m)), style: cell), right: true),
          pad(Text(fullTime(latest(dr)), style: TextStyle(fontSize: 12, color: colors.sub))),
        ],
      );
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.only(bottom: 6), child: Text('날짜별 상세 · — 미수집 · 옆으로 밀어 보세요', style: _sub(colors))),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(children: [
              pad(Text('날짜', style: head)),
              for (final m in names) pad(Text('${ch.metrics[m]!.$1} (${ch.metrics[m]!.$2})', style: head), right: true),
              pad(Text('수집 시각 (KST)', style: head)),
            ]),
            ...rows,
          ],
        ),
      ),
    ]);
  }
}
