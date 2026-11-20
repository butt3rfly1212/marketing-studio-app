# Marketing Studio 앱

Butt3rfly의 마케팅 대시보드를 Flutter로 만든 앱입니다. 웹 대시보드(https://ai-marketing-66997.web.app)와 같은 계정·데이터를 씁니다.

| 탭 | 내용 |
|---|---|
| Strategy | 브랜드·상품 조사, 경쟁, 고객, 브리프(앱에 묶인 자료) |
| Contents | Google Drive 제작물 폴더(구글 로그인 필요) |
| Operation | 채널 성과(Supabase `channel_metrics` 공개 읽기) |
| 작업 공간 | 버추얼 오피스(웹 오피스를 WebView로 표시), AI 회의 |

프로필 메뉴의 **스킬 실행하기**는 대표 계정만 쓸 수 있습니다. 실행은 Happier에 연결된 PC의 중계기가 처리합니다.

## 실행

```bash
flutter pub get
flutter run            # 연결된 기기 또는 에뮬레이터
flutter run -d chrome --web-port 8000   # 웹(구글 로그인이 8000번 포트로 등록되어 있음)
```

로그인은 Firebase 이메일 계정으로 합니다.

## 빌드

```bash
flutter build apk --release   # Android APK (디버그 키로 서명)
flutter build ios             # iOS (Xcode에서 팀 선택 후 개발자 모드 기기에 설치)
```

- iOS 번들 ID: `com.butt3rfly.dashboard`, Android 패키지: `com.butt3rfly.dashboard`
- iOS 구글 로그인 설정(`GIDClientID`, URL 스킴)은 `ios/Runner/Info.plist`에 들어 있습니다.
- Android 구글 로그인은 서명 키의 SHA-1이 OAuth 클라이언트에 등록돼 있어야 합니다. 다른 키로 서명하면 그 키의 SHA-1을 추가로 등록해야 합니다.

## 보안 메모

앱에 들어 있는 Firebase 설정, OAuth 클라이언트 ID, Supabase 공개 키는 클라이언트용으로 공개돼도 되는 값입니다. 데이터 보호는 서버 쪽(Firebase 인증, Supabase RLS, Edge Function의 대표 계정 확인)에서 합니다.
