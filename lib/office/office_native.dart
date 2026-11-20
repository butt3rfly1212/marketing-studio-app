import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

class OfficeSurface extends StatefulWidget {
  const OfficeSurface({
    super.key,
    required this.markup,
    required this.theme,
    required this.active,
    required this.onMessage,
  });

  final String markup;
  final String theme;
  final bool active;
  final Future<String?> Function(String) onMessage;

  @override
  State<OfficeSurface> createState() => _OfficeSurfaceState();
}

class _OfficeSurfaceState extends State<OfficeSurface> {
  WebViewController? _controller;
  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if ({TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}.contains(defaultTargetPlatform)) {
      _setup();
    }
  }

  Future<void> _setup() async {
    try {
      final controller = WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'OfficeBridge',
        onMessageReceived: (message) async {
          final response = await widget.onMessage(message.message);
          if (mounted && response != null) await controller.runJavaScript('window.officeFromHost($response)');
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _loaded = true;
            _sendConfig();
          },
          onNavigationRequest: (request) => request.url == 'about:blank' || request.url.startsWith('data:text/html')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame != false) setState(() => _error = true);
          },
        ),
      );
      if (mounted) {
        await controller.loadHtmlString(widget.markup);
        if (mounted) setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(covariant OfficeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme != oldWidget.theme || widget.active != oldWidget.active) _sendConfig();
  }

  Future<void> _sendConfig() async {
    if (!_loaded || !mounted) return;
    final config = jsonEncode({'type': 'config', 'theme': widget.theme, 'active': widget.active});
    await _controller?.runJavaScript('window.officeFromHost($config)');
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const Center(child: Text('작업 공간 화면을 불러오지 못했습니다.'));
    final controller = _controller;
    if (controller == null) return const Center(child: Text('작업 공간은 웹, iOS, Android에서 열 수 있습니다.'));
    return WebViewWidget(controller: controller);
  }
}
