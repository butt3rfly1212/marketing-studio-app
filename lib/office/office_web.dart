import 'dart:convert';
import 'dart:js_interop';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

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
  web.HTMLIFrameElement? _frame;
  late final _receive = ((web.MessageEvent event) {
    final frame = _frame;
    if (frame == null || event.origin != 'null' || event.source?.strictEquals(frame.contentWindow).toDart != true) return;
    final data = event.data;
    if (data.isA<JSString>()) _reply(data as JSString, frame);
  }).toJS;
  late final _load = ((web.Event _) => _sendConfig()).toJS;

  @override
  void initState() {
    super.initState();
    web.window.addEventListener('message', _receive);
  }

  @override
  void didUpdateWidget(covariant OfficeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme != oldWidget.theme || widget.active != oldWidget.active) _sendConfig();
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _receive);
    _frame?.removeEventListener('load', _load);
    super.dispose();
  }

  Future<void> _reply(JSString data, web.HTMLIFrameElement frame) async {
    final response = await widget.onMessage(data.toDart);
    if (mounted && response != null && frame == _frame) {
      frame.contentWindow?.postMessage(response.toJS, '*'.toJS);
    }
  }

  void _sendConfig() {
    _frame?.contentWindow?.postMessage(
      jsonEncode({'type': 'config', 'theme': widget.theme, 'active': widget.active}).toJS,
      '*'.toJS,
    );
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      _frame = frame;
      frame.setAttribute('sandbox', 'allow-scripts');
      frame.title = '버추얼 오피스';
      frame.style.border = '0';
      frame.addEventListener('load', _load);
      frame.srcdoc = widget.markup.toJS;
    },
  );
}
