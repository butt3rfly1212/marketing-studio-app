import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'contents/contents_page.dart';
import 'contents/drive_store.dart';
import 'office/office_page.dart';
import 'operation/operation_page.dart';
import 'operation/operation_store.dart';
import 'skills/skill_runs_page.dart';
import 'strategy/brands_page.dart';
import 'strategy/data.dart';
import 'strategy/search_page.dart';
import 'theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.user, this.onToggleTheme});

  final User user;
  final VoidCallback? onToggleTheme;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _signingOut = false;
  final _strategyNav = GlobalKey<NavigatorState>();
  final _contentsNav = GlobalKey<NavigatorState>();
  late final Future<StudioData> _data = StudioData.load();
  final _drive = DriveStore();
  final _operation = OperationStore();
  int _stage = 0;
  bool _operationOpened = false;
  bool _officeOpened = false;

  @override
  void dispose() {
    _drive.dispose();
    _operation.dispose();
    super.dispose();
  }

  void _selectStage(int i) {
    if (i == _stage) {
      if (i < 2) {
        (i == 0 ? _strategyNav : _contentsNav).currentState?.popUntil((r) => r.isFirst);
      }
      return;
    }
    setState(() {
      _stage = i;
      if (i == 2) _operationOpened = true;
      if (i == 3) _officeOpened = true;
    });
  }

  void _openSearch(StudioData data) {
    setState(() => _stage = 0);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SearchPage(data: data, strategyNav: _strategyNav),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await _drive.disconnect();
      _operation.reset();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그아웃하지 못했습니다. 네트워크를 확인하고 다시 시도해 주세요.')));
    }
  }

  Widget _header(StudioColors colors) {
    final address = widget.user.email ?? '';
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.rule)),
        ),
        child: Row(
          spacing: 8,
          children: [
            ClipRRect(
              borderRadius: studioControl,
              child: Image.asset('assets/office/studio-mark.png', width: 30, height: 30),
            ),
            Expanded(child: Text('Marketing Studio', style: Theme.of(context).textTheme.titleMedium)),
            FutureBuilder<StudioData>(
              future: _data,
              builder: (context, snapshot) => IconButton.outlined(
                tooltip: '검색',
                onPressed: snapshot.hasData ? () => _openSearch(snapshot.data!) : null,
                icon: const Icon(Icons.search, size: 20),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '계정 메뉴',
              enabled: !_signingOut,
              onSelected: (choice) {
                if (choice == 'theme') {
                  widget.onToggleTheme?.call();
                } else if (choice == 'skills') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SkillRunsPage(user: widget.user)),
                  );
                } else if (choice == 'signOut') {
                  _signOut();
                }
              },
              itemBuilder: (_) => [
                if (address.isNotEmpty)
                  PopupMenuItem(
                    enabled: false,
                    child: Text(address, style: TextStyle(color: colors.sub)),
                  ),
                if (widget.onToggleTheme != null)
                  PopupMenuItem(value: 'theme', child: Text(colors.brightness == Brightness.dark ? '라이트 테마' : '다크 테마')),
                const PopupMenuItem(value: 'skills', child: Text('스킬 실행하기')),
                const PopupMenuItem(value: 'signOut', child: Text('로그아웃')),
              ],
              child: CircleAvatar(
                radius: 20,
                backgroundColor: colors.ink,
                foregroundColor: colors.ground,
                child: Text(address.isEmpty ? 'M' : address.characters.first.toUpperCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigation(StudioColors colors) {
    const items = [
      ('Strategy', Icons.explore_outlined),
      ('Contents', Icons.grid_view_rounded),
      ('Operation', Icons.bar_chart_rounded),
      ('작업 공간', Icons.auto_awesome_outlined),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.ground,
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == _stage,
                      button: true,
                      child: InkWell(
                        onTap: () => _selectStage(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 3,
                            children: [
                              Icon(items[i].$2, size: 22, color: i == _stage ? colors.ink : colors.sub),
                              Text(
                                items[i].$1,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: i == _stage ? colors.ink : colors.sub,
                                  fontWeight: i == _stage ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    return Scaffold(
      bottomNavigationBar: _navigation(colors),
      body: Column(
        children: [
          _header(colors),
          Expanded(
            child: IndexedStack(
              index: _stage,
              children: [
                FutureBuilder<StudioData>(
                  future: _data,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Strategy 자료를 읽지 못했습니다. 앱 자료를 다시 만든 뒤 실행해 주세요.', textAlign: TextAlign.center),
                        ),
                      );
                    }
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    return NavigatorPopHandler(
                      enabled: _stage == 0,
                      onPopWithResult: (_) => _strategyNav.currentState?.maybePop(),
                      child: Navigator(
                        key: _strategyNav,
                        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => BrandsPage(data: snap.data!)),
                      ),
                    );
                  },
                ),
                ContentsView(store: _drive, navKey: _contentsNav, active: _stage == 1),
                _operationOpened ? OperationView(store: _operation) : const SizedBox.shrink(),
                if (_officeOpened) OfficePage(user: widget.user, active: _stage == 3) else const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
