import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Google OAuth 클라이언트(Firebase 프로젝트 ai-marketing-66997의 Marketing Dashboard 클라이언트).
/// 클라이언트 ID는 비밀값이 아니다. 앱을 알아보는 이름일 뿐이다.
class DriveClients {
  /// 웹(기존 대시보드와 같은 클라이언트). Android에서는 serverClientId로 쓴다.
  static const web = '590483114270-tcr2tmg3rltgjs6navvu0lre2fpijdfq.apps.googleusercontent.com';

  /// iOS 클라이언트(번들 ID com.butt3rfly.dashboard).
  static const ios = '590483114270-1l7puie5l49kto8rnhkbceh6b7povejn.apps.googleusercontent.com';
}

const rootFolderId = '1U4VK0MZQD3YQHEf7UDj3nxdIJArtxTeO';
const rootFolderUrl = 'https://drive.google.com/drive/folders/$rootFolderId';
const _scopes = ['https://www.googleapis.com/auth/drive'];
const _api = 'https://www.googleapis.com/drive/v3/files';
const _fields =
    'id,name,mimeType,size,modifiedTime,webViewLink,iconLink,thumbnailLink,hasThumbnail,videoMediaMetadata(durationMillis,width,height),imageMediaMetadata(width,height)';
const folderMime = 'application/vnd.google-apps.folder';

/// Drive 파일 한 개.
class DriveFile {
  DriveFile(Map<String, dynamic> j, {this.parent})
      : id = '${j['id']}',
        name = '${j['name'] ?? ''}',
        mimeType = '${j['mimeType'] ?? ''}',
        size = int.tryParse('${j['size'] ?? ''}') ?? 0,
        modifiedTime = '${j['modifiedTime'] ?? ''}',
        webViewLink = j['webViewLink'] as String?,
        thumbnailLink = j['thumbnailLink'] as String?;

  final String id;
  final String name;
  final String mimeType;
  final int size;
  final String modifiedTime;
  final String? webViewLink;
  final String? thumbnailLink;
  String? parent;

  bool get isFolder => mimeType == folderMime;

  /// 종류(웹 drive.js의 kind와 같다).
  String get kind {
    if (isFolder) return 'folder';
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('audio/')) return 'audio';
    if (mimeType == 'application/pdf') return 'pdf';
    if (mimeType.startsWith('application/vnd.google-apps.')) return 'gdoc';
    return 'file';
  }

  static const kindLabel = {
    'folder': '폴더', 'image': '이미지', 'video': '영상', 'audio': '오디오', 'pdf': 'PDF', 'gdoc': 'Google 문서', 'file': '파일',
  };
  String get kindName => kindLabel[kind]!;

  String get openUrl => webViewLink ?? 'https://drive.google.com/open?id=$id';
  String get previewUrl => 'https://drive.google.com/file/d/$id/preview';
  String get mediaUrl => '$_api/$id?alt=media&supportsAllDrives=true';
  String? thumb([int size = 480]) => thumbnailLink?.replaceFirst(RegExp(r'=s\d+$'), '=s$size');

  String get meta => [kindName, bytes(size), modifiedTime.length >= 10 ? modifiedTime.substring(0, 10) : ''].where((x) => x.isNotEmpty).join(' · ');

  static String bytes(int n) {
    if (n <= 0) return '';
    if (n >= 1073741824) return '${(n / 1073741824).toStringAsFixed(1)} GB';
    if (n >= 1048576) return '${(n / 1048576).toStringAsFixed(1)} MB';
    return '${max(1, (n / 1024).round())} KB';
  }
}

class DriveExpired implements Exception {}

enum DriveStatus { idle, loading, ready }

/// Contents 화면의 상태: 연결, 폴더 전체 불러오기, 미디어 받기.
/// 접근 토큰은 이 객체의 메모리에만 둔다(기기 저장소에 쓰지 않는다).
class DriveStore extends ChangeNotifier {
  String? _token;
  Timer? _tokenTimer;
  bool _initialized = false;
  int _run = 0;

  DriveStatus status = DriveStatus.idle;
  String message = '';
  bool expired = false;
  bool connecting = false;
  DriveFile? root;
  final Map<String, DriveFile> items = {};
  final Map<String, List<String>> children = {};
  int folders = 0;
  int files = 0;
  DateTime? loadedAt;
  final List<String> failed = [];

  bool get connected => _token != null;
  Map<String, String> get authHeaders => {if (_token != null) 'Authorization': 'Bearer $_token'};

  Future<void> _init() async {
    if (_initialized) return;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? DriveClients.web : (isIos ? DriveClients.ios : null),
      serverClientId: kIsWeb ? null : DriveClients.web,
    );
    _initialized = true;
  }

  /// 'Google Drive 연결' 버튼. 버튼을 누른 순간에 불러야 웹에서 팝업이 막히지 않는다.
  Future<void> connect() async {
    message = '';
    connecting = true;
    notifyListeners();
    try {
      await _init();
      final client = GoogleSignIn.instance.authorizationClient;
      final auth = await client.authorizationForScopes(_scopes) ?? await client.authorizeScopes(_scopes);
      _setToken(auth.accessToken);
      connecting = false;
      unawaited(refresh());
    } on GoogleSignInException catch (e) {
      connecting = false;
      message = e.code == GoogleSignInExceptionCode.canceled
          ? '연결 창이 닫혔습니다. 다시 눌러 주세요.'
          : 'Google Drive에 연결하지 못했습니다. ${e.description ?? '다시 시도해 주세요.'}';
      notifyListeners();
    } catch (_) {
      connecting = false;
      message = 'Google Drive에 연결하지 못했습니다. 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  void _setToken(String token) {
    _token = token;
    expired = false;
    _tokenTimer?.cancel();
    // 접근 토큰은 보통 1시간 유효하다. 조금 일찍 끊고 다시 연결하게 한다.
    _tokenTimer = Timer(const Duration(minutes: 59), () => _dropToken(expired: true));
  }

  void _dropToken({required bool expired}) {
    final old = _token;
    _token = null;
    _tokenTimer?.cancel();
    this.expired = expired;
    if (old != null && expired) {
      unawaited(GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: old).catchError((_) {}));
    }
    if (status == DriveStatus.loading) {
      status = root == null ? DriveStatus.idle : DriveStatus.ready;
      _run++;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    final old = _token;
    _dropToken(expired: false);
    if (old != null) {
      try {
        await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: old);
        await GoogleSignIn.instance.disconnect();
      } catch (_) {
        // 연결 해제가 실패해도 앱 안 토큰은 이미 지웠다.
      }
    }
  }

  /// 네트워크 오류, 요청 제한, 서버 오류는 잠시 기다렸다가 최대 5번까지 다시 부른다.
  Future<http.Response> _get(String url, [int tries = 0]) async {
    if (_token == null) throw DriveExpired();
    Future<http.Response> retry(Object why) async {
      if (tries >= 4) throw why;
      await Future<void>.delayed(Duration(milliseconds: min(8000, 600 * pow(2, tries).toInt()) + Random().nextInt(400)));
      return _get(url, tries + 1);
    }

    http.Response res;
    try {
      res = await http.get(Uri.parse(url), headers: authHeaders);
    } catch (_) {
      return retry(Exception('네트워크 오류'));
    }
    if (res.statusCode == 401) {
      _dropToken(expired: true);
      throw DriveExpired();
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    var msg = 'Drive 요청 실패 (${res.statusCode})';
    var reason = '';
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final err = j['error'] as Map<String, dynamic>?;
      msg = '${err?['message'] ?? msg}';
      final errs = err?['errors'] as List?;
      reason = errs != null && errs.isNotEmpty ? '${(errs.first as Map)['reason'] ?? ''}' : '';
    } catch (_) {}
    if (res.statusCode == 429 || res.statusCode >= 500 || reason.toLowerCase().contains('ratelimit')) return retry(Exception(msg));
    throw Exception(msg);
  }

  String _q(Map<String, Object> p) => p.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}').join('&');

  Future<List<DriveFile>> _listChildren(String id) async {
    final out = <DriveFile>[];
    String? page;
    do {
      final p = <String, Object>{
        'q': "'$id' in parents and trashed = false",
        'fields': 'nextPageToken,files($_fields)',
        'pageSize': 1000,
        'orderBy': 'folder,name_natural',
        'supportsAllDrives': true,
        'includeItemsFromAllDrives': true,
        'pageToken': ?page,
      };
      final j = jsonDecode((await _get('$_api?${_q(p)}')).body) as Map<String, dynamic>;
      out.addAll(((j['files'] as List?) ?? const []).map((f) => DriveFile((f as Map).cast<String, dynamic>(), parent: id)));
      page = j['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }

  /// 루트부터 하위 폴더를 모두 내려가며 불러온다(동시에 4개 폴더).
  Future<void> refresh() async {
    if (_token == null) return connect();
    final run = ++_run;
    status = DriveStatus.loading;
    message = '';
    items.clear();
    children.clear();
    folders = 0;
    files = 0;
    failed.clear();
    notifyListeners();
    try {
      final rootJson = jsonDecode((await _get('$_api/$rootFolderId?${_q({'fields': _fields, 'supportsAllDrives': true})}')).body);
      if (run != _run) return;
      root = DriveFile((rootJson as Map).cast<String, dynamic>());
      items[root!.id] = root!;
      final queue = <String>[root!.id];
      var active = 0;
      final done = Completer<void>();
      void next() {
        if (run != _run) {
          if (!done.isCompleted) done.complete();
          return;
        }
        if (queue.isEmpty && active == 0) {
          if (!done.isCompleted) done.complete();
          return;
        }
        while (active < 4 && queue.isNotEmpty) {
          final id = queue.removeAt(0);
          active++;
          _listChildren(id).then((list) {
            if (run != _run) return;
            children[id] = [for (final f in list) f.id];
            for (final f in list) {
              items[f.id] = f;
              if (f.isFolder) {
                folders++;
                queue.add(f.id);
              } else {
                files++;
              }
            }
            active--;
            notifyListeners();
            next();
          }, onError: (Object e) {
            active--;
            if (e is DriveExpired) {
              if (!done.isCompleted) done.completeError(e);
              return;
            }
            failed.add(id); // 이 폴더만 건너뛰고 나머지는 계속 불러온다
            next();
          });
        }
      }

      next();
      await done.future;
      if (run != _run) return;
      status = DriveStatus.ready;
      loadedAt = DateTime.now();
      if (failed.isNotEmpty) {
        final names = failed.take(3).map((id) => items[id]?.name ?? id).join(', ');
        message = '폴더 ${failed.length}개는 여러 번 시도했지만 불러오지 못했습니다($names${failed.length > 3 ? ' 외' : ''}). 새로고침을 눌러 다시 시도해 주세요.';
      }
      notifyListeners();
    } catch (e) {
      if (run != _run || e is DriveExpired) return;
      status = root == null ? DriveStatus.idle : DriveStatus.ready;
      message = 'Drive 내용을 불러오지 못했습니다. ${e is Exception ? e.toString().replaceFirst('Exception: ', '') : ''} 폴더 공유 권한을 확인해 주세요.';
      notifyListeners();
    }
  }

  // ───────── 보조
  List<DriveFile> kids(String id) => [for (final k in children[id] ?? const <String>[]) ?items[k]];

  List<DriveFile> pathTo(String id) {
    final out = <DriveFile>[];
    var cur = items[id];
    var guard = 0;
    while (cur != null && guard++ < 50) {
      out.insert(0, cur);
      if (cur.id == rootFolderId || cur.parent == null) break;
      cur = items[cur.parent];
    }
    return out;
  }

  ({int folders, int files}) countDeep(String id) {
    var fo = 0, fi = 0;
    for (final f in kids(id)) {
      if (f.isFolder) {
        fo++;
        final d = countDeep(f.id);
        fo += d.folders;
        fi += d.files;
      } else {
        fi++;
      }
    }
    return (folders: fo, files: fi);
  }

  /// 이미지 원본을 받는다(미리보기용).
  Future<Uint8List> download(DriveFile f) async => (await _get(f.mediaUrl)).bodyBytes;

  @override
  void dispose() {
    _tokenTimer?.cancel();
    super.dispose();
  }
}
