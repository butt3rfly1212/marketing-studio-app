import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// 웹 대시보드 로그인 페이지(dashboard/src/login.html)의 앱 버전.
/// 로그인되면 main.dart의 인증 상태 감시가 대시보드로 넘긴다.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _signingUp = false;
  bool _busy = false;
  bool _isError = false;
  String _message = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _show(String text, {bool error = false}) => setState(() {
        _message = text;
        _isError = error;
      });

  void _toggleMode() => setState(() {
        _signingUp = !_signingUp;
        _password.clear();
        _confirm.clear();
        _message = _signingUp ? '비밀번호는 6자 이상으로 입력해 주세요.' : '';
        _isError = false;
      });

  void _clearError() {
    if (_isError) _show('');
  }

  String _errorText(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return _signingUp ? '이메일 형식을 확인해 주세요.' : '이메일 또는 비밀번호를 확인해 주세요.';
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다. 로그인해 주세요.';
      case 'weak-password':
        return '비밀번호는 6자 이상으로 입력해 주세요.';
      case 'operation-not-allowed':
        return '지금은 회원가입을 받을 수 없습니다. 관리자에게 문의해 주세요.';
      case 'too-many-requests':
        return '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      case 'network-request-failed':
        return '네트워크에 연결할 수 없습니다. 연결을 확인하고 다시 시도해 주세요.';
      case 'user-disabled':
        return '사용이 중지된 계정입니다. 관리자에게 문의해 주세요.';
      default:
        return '${_signingUp ? '회원가입하지' : '로그인하지'} 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _show('이메일과 비밀번호를 입력해 주세요.', error: true);
      return;
    }
    if (_signingUp && password.length < 6) {
      _show('비밀번호는 6자 이상으로 입력해 주세요.', error: true);
      return;
    }
    if (_signingUp && password != _confirm.text) {
      _show('비밀번호가 서로 다릅니다. 다시 확인해 주세요.', error: true);
      return;
    }
    setState(() => _busy = true);
    _show(_signingUp ? '계정을 만들고 있습니다.' : '로그인하고 있습니다.');
    try {
      final auth = FirebaseAuth.instance;
      if (_signingUp) {
        await auth.createUserWithEmailAndPassword(email: email, password: password);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      // 화면 이동은 main.dart의 인증 상태 감시가 맡는다.
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _show(_errorText(error), error: true);
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      _show('${_signingUp ? '회원가입하지' : '로그인하지'} 못했습니다. 잠시 후 다시 시도해 주세요.', error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final wide = MediaQuery.sizeOf(context).width > 760;
    final titleSize = wide ? 60.0 : 44.0;
    return Scaffold(
      backgroundColor: colors.authBackground,
      body: Stack(
        children: [
          // 웹의 블랙홀 배경 대신, 같은 자리에 은은한 빛만 둔다.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: wide ? const Alignment(0.44, -0.08) : const Alignment(0, 0.72),
                  radius: wide ? 0.9 : 0.8,
                  colors: [colors.accentSoft, colors.ground],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: wide ? Alignment.centerLeft : Alignment.topLeft,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: wide ? 72 : 24, vertical: wide ? 56 : 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 376),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Marketing\nStudio',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              height: 1.02,
                              letterSpacing: -0.03 * titleSize,
                              color: colors.authInk,
                              fontFamilyFallback: fontFallback,
                            )),
                        SizedBox(height: wide ? 56 : 36),
                        _AuthField(
                          label: '이메일',
                          controller: _email,
                          error: _isError,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          onChanged: (_) => _clearError(),
                          onSubmitted: (_) => _submit(),
                        ),
                        _AuthField(
                          label: '비밀번호',
                          controller: _password,
                          error: _isError,
                          obscure: true,
                          autofillHints: [_signingUp ? AutofillHints.newPassword : AutofillHints.password],
                          onChanged: (_) => _clearError(),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_signingUp)
                          _AuthField(
                            label: '비밀번호 확인',
                            controller: _confirm,
                            error: _isError,
                            obscure: true,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) => _clearError(),
                            onSubmitted: (_) => _submit(),
                          ),
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              height: 22,
                              child: Text(_message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 22 / 14,
                                    color: _isError ? colors.authError : colors.authSub,
                                  )),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.authInk,
                              foregroundColor: colors.authButtonText,
                              disabledBackgroundColor: colors.authInk.withValues(alpha: 0.55),
                              disabledForegroundColor: colors.authButtonText,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: Text(_signingUp ? '회원가입' : '로그인'),
                          ),
                        ),
                        SizedBox(height: wide ? 20 : 12),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(_signingUp ? '이미 계정이 있으신가요?' : '계정이 없으신가요?',
                                style: TextStyle(fontSize: 14, color: colors.authSub)),
                            TextButton(
                              onPressed: _busy ? null : _toggleMode,
                              style: TextButton.styleFrom(
                                foregroundColor: colors.authInk,
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                textStyle: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                              ),
                              child: Text(_signingUp ? '로그인' : '회원가입'),
                            ),
                          ],
                        ),
                        SizedBox(height: wide ? 20 : 12),
                        Text('주식회사 Butt3rfly', style: TextStyle(fontSize: 14, color: colors.authSub)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 웹 로그인 화면의 입력칸: 위에 이름, 아래에 밑줄. 누르면 밑줄이 진해지고, 오류면 붉게 바뀐다.
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.controller,
    required this.error,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool error;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = StudioColors.of(context);
    final active = error ? colors.authError : colors.authInk;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: colors.authInk,
        style: TextStyle(fontSize: 18, height: 1.4, color: colors.authInk),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.authSub),
          floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: states.contains(WidgetState.focused) ? colors.authInk : colors.authSub,
              )),
          contentPadding: const EdgeInsets.only(top: 12, bottom: 12),
          enabledBorder: UnderlineInputBorder(
            borderSide: error ? BorderSide(color: active, width: 2) : BorderSide(color: colors.authRule),
          ),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: active, width: 2)),
        ),
      ),
    );
  }
}
