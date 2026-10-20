import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_errors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import 'email_auth_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  String? _verificationId;
  bool _busy = false;
  bool _email = false; // false = phone, true = email + password
  bool _googleBusy = false;
  String? _error;
  int _resend = 0;
  Timer? _timer;

  bool get _otpStep => _verificationId != null;

  /// +880 followed by the 10 national digits (a leading 0 is dropped).
  String get _e164 {
    var d = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = d.substring(1);
    return '+880$d';
  }

  bool get _phoneValid => RegExp(r'^\+8801\d{9}$').hasMatch(_e164);

  void _startTimer() {
    _resend = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resend <= 1) t.cancel();
      if (mounted) setState(() => _resend--);
    });
  }

  Future<void> _send() async {
    if (!_phoneValid) {
      setState(() => _error = 'Enter a valid Bangladeshi mobile number, like 1712 345678.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(repositoryProvider).sendCode(_e164);
      if (!mounted) return;
      setState(() => _verificationId = id);
      _startTimer();
      _otpFocus.requestFocus();
    } catch (e) {
      debugPrint('sendCode failed: $e');
      if (mounted) setState(() => _error = _authMessage(e, sending: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.text.length != 6) {
      setState(() => _error = 'Enter all 6 digits, or try again in 30 seconds.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).verifyCode(_verificationId!, _otp.text);
      // Router redirect takes over once auth state changes.
    } catch (e) {
      debugPrint('verifyCode failed: $e');
      if (mounted) setState(() => _error = _authMessage(e, sending: false));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authMessage(Object e, {required bool sending}) {
    if (e is FirebaseAuthException) {
      final detail = kDebugMode ? ' [${e.code}]' : '';
      switch (e.code) {
        case 'invalid-phone-number':
          return 'That number looks invalid. Use a Bangladeshi mobile number like 1712 345678.$detail';
        case 'too-many-requests':
        case 'quota-exceeded':
          return 'Too many attempts. Wait a few minutes and try again.$detail';
        case 'network-request-failed':
          return 'No connection. Check your internet and try again.$detail';
        case 'invalid-verification-code':
          return "That code didn't match. Check it and try again.$detail";
        case 'session-expired':
          return 'The code expired. Request a new one.$detail';
        case 'operation-not-allowed':
          return 'Phone sign-in is not enabled for this project yet.$detail';
        case 'app-not-authorized':
        case 'invalid-app-credential':
        case 'missing-client-identifier':
        case 'captcha-check-failed':
          return 'This build is not authorized for phone sign-in. Check the app fingerprints in Firebase.$detail';
      }
      return "${sending ? "Couldn't send the code" : "Couldn't verify the code"}.$detail";
    }
    return sending ? "Couldn't send the code. Check your connection and try again." : "That code didn't match. Try again.";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 32),
              child: IntrinsicHeight(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleIconButton(
                    icon: TablerIcons.arrow_left, label: 'Back',
                    onPressed: () => _otpStep ? setState(() { _verificationId = null; _otp.clear(); _error = null; }) : context.go('/onboarding'),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _otpStep ? _otpBody(c) : _entryBody(c),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).signInWithGoogle();
    } catch (e) {
      debugPrint('google sign-in failed: $e');
      final msg = authErrorMessage(e, fallback: "Google sign-in didn't work. Try again or use another method.");
      if (mounted && msg.isNotEmpty) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  /// Phone or email entry, plus Google.
  Widget _entryBody(RColors c) {
    Widget tab(bool email, String label, IconData icon) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _email = email;
              _error = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 42,
              decoration: BoxDecoration(
                color: _email == email ? c.surface1 : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                border: _email == email ? Border.all(color: c.border) : null,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 17, color: _email == email ? c.textPrimary : c.textSecondary),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _email == email ? c.textPrimary : c.textSecondary)),
              ]),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(99)),
        child: Row(children: [tab(false, 'Phone', TablerIcons.device_mobile), tab(true, 'Email', TablerIcons.mail)]),
      ),
      const SizedBox(height: 24),
      if (_email) const EmailAuthForm() else _phoneBody(c),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: Divider(color: c.border)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or continue with', style: TextStyle(fontSize: 13, color: c.textMuted))),
        Expanded(child: Divider(color: c.border)),
      ]),
      const SizedBox(height: 16),
      SizedBox(
        height: 54,
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _googleBusy ? null : _google,
          icon: _googleBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(TablerIcons.brand_google_filled, size: 19),
          label: Text(_googleBusy ? 'Opening Google…' : 'Google', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          style: OutlinedButton.styleFrom(shape: const StadiumBorder(), foregroundColor: c.textPrimary, side: BorderSide(color: c.borderStrong), backgroundColor: c.surface1),
        ),
      ),
      if (_error != null && _email) ...[const SizedBox(height: 12), InfoBanner(_error!, icon: TablerIcons.alert_circle_filled, bg: c.bgDanger, fg: c.textDanger)],
    ]);
  }

  Widget _phoneBody(RColors c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ScreenHeading("What's your number?", subtitle: "We'll text a 6-digit code. Your number is never shown to other users."),
        const SizedBox(height: 28),
        Container(
          height: 64,
          decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.borderStrong)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 0, 14, 0),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: c.border))),
              child: Row(children: [
                Text('BD', style: AppTheme.mono(context, size: 11)),
                const SizedBox(width: 6),
                const Text('+880', style: TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(13)],
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500, letterSpacing: .4),
                decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16), hintText: '1712 345678', hintStyle: TextStyle(color: c.textDisabled)),
                onSubmitted: (_) => _send(),
              ),
            ),
          ]),
        ),
        if (_error != null) ...[const SizedBox(height: 16), InfoBanner(_error!, icon: TablerIcons.alert_circle_filled, bg: c.bgDanger, fg: c.textDanger)],
        const SizedBox(height: 28),
        PillButton(_busy ? 'Sending…' : 'Send code', onPressed: _busy ? null : _send),
      ]);

  Widget _otpBody(RColors c) {
    final shown = _phone.text.trim().isEmpty ? '—' : _phone.text.trim();
    final len = _otp.text.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ScreenHeading('Enter the code'),
      const SizedBox(height: 10),
      Text.rich(TextSpan(style: TextStyle(fontSize: 15, color: c.textSecondary), children: [
        const TextSpan(text: 'Sent to '),
        TextSpan(text: '+880 $shown', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
      ])),
      const SizedBox(height: 28),
      Stack(children: [
        Row(children: [
          for (var i = 0; i < 6; i++)
            Expanded(
              child: Container(
                height: 64,
                margin: EdgeInsets.only(right: i == 5 ? 0 : 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface1, borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    width: i == len ? 2 : 1.5,
                    color: _error != null ? c.borderDanger : i == len ? c.fillBrand : i < len ? c.borderStronger : c.border,
                  ),
                ),
                child: Text(i < len ? _otp.text[i] : '', style: AppTheme.mono(context, size: 26, w: FontWeight.w600, color: c.textPrimary)),
              ),
            ),
        ]),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _otp, focusNode: _otpFocus, keyboardType: TextInputType.number, maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
        ),
      ]),
      if (_error != null) ...[const SizedBox(height: 16), InfoBanner(_error!, icon: TablerIcons.alert_circle_filled, bg: c.bgDanger, fg: c.textDanger)],
      const SizedBox(height: 28),
      PillButton(_busy ? 'Verifying…' : 'Verify', onPressed: _busy ? null : _verify),
      const SizedBox(height: 20),
      Center(
        child: _resend > 0
            ? Container(
                height: 34, padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(TablerIcons.clock, size: 15, color: c.textSecondary),
                  const SizedBox(width: 6),
                  Text('Resend in 0:${_resend.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w500)),
                ]),
              )
            : TextButton(onPressed: _busy ? null : _send, child: const Text('Resend code')),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)), child: const Icon(TablerIcons.wifi_off, size: 17)),
          const SizedBox(width: 12),
          Expanded(child: Text('On a weak connection? The code still works if it arrives after you lose signal.', style: TextStyle(fontSize: 13, color: c.textSecondary))),
        ]),
      ),
    ]);
  }
}
