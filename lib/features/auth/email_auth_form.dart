import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/auth_errors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

enum EmailMode { signIn, create, reset }

/// Email + password sign-in, account creation and password reset.
class EmailAuthForm extends ConsumerStatefulWidget {
  const EmailAuthForm({super.key});
  @override
  ConsumerState<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends ConsumerState<EmailAuthForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  EmailMode _mode = EmailMode.signIn;
  bool _show = false;
  bool _busy = false;
  String? _error;
  String? _info;

  bool get _emailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
  bool get _canSubmit => _emailValid && (_mode == EmailMode.reset || _password.text.length >= 6) && !_busy;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switch(EmailMode m) => setState(() {
        _mode = m;
        _error = null;
        _info = null;
      });

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final repo = ref.read(repositoryProvider);
    try {
      switch (_mode) {
        case EmailMode.signIn:
          await repo.signInWithEmail(_email.text, _password.text);
        case EmailMode.create:
          await repo.createAccountWithEmail(_email.text, _password.text);
        case EmailMode.reset:
          await repo.sendPasswordReset(_email.text);
          if (mounted) setState(() => _info = 'If an account exists for ${_email.text.trim()}, a reset link is on its way. Check your inbox and spam.');
      }
      // On sign-in or sign-up the router redirect takes over once the auth state changes.
    } catch (e) {
      final msg = authErrorMessage(e, fallback: "That didn't work. Check your details and try again.");
      if (mounted && msg.isNotEmpty) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    OutlineInputBorder border(Color col, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: col, width: w));
    InputDecoration dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
          labelText: label, prefixIcon: Icon(icon, size: 20, color: c.textMuted), suffixIcon: suffix,
          filled: true, fillColor: c.surface1, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          enabledBorder: border(c.borderStrong), focusedBorder: border(c.fillBrand, 1.5),
        );

    final (title, sub, cta) = switch (_mode) {
      EmailMode.signIn => ('Welcome back', 'Sign in with your email and password.', 'Sign in'),
      EmailMode.create => ('Create your account', 'Use any email. You can add your donor details next.', 'Create account'),
      EmailMode.reset => ('Reset your password', "Enter your email and we'll send a link to choose a new one.", 'Send reset link'),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ScreenHeading(title, subtitle: sub),
      const SizedBox(height: 24),
      TextField(
        controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
        textInputAction: _mode == EmailMode.reset ? TextInputAction.done : TextInputAction.next, onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _mode == EmailMode.reset ? _submit() : null,
        decoration: dec('Email', TablerIcons.mail),
      ),
      if (_mode != EmailMode.reset) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _password, obscureText: !_show, autofillHints: [_mode == EmailMode.create ? AutofillHints.newPassword : AutofillHints.password],
          textInputAction: TextInputAction.done, onChanged: (_) => setState(() {}), onSubmitted: (_) => _submit(),
          decoration: dec('Password', TablerIcons.lock, suffix: IconButton(tooltip: _show ? 'Hide password' : 'Show password', icon: Icon(_show ? TablerIcons.eye_off : TablerIcons.eye, size: 20), onPressed: () => setState(() => _show = !_show))),
        ),
        if (_mode == EmailMode.create) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text('At least 6 characters.', style: TextStyle(fontSize: 12, color: c.textMuted))),
      ],
      if (_error != null) ...[const SizedBox(height: 16), InfoBanner(_error!, icon: TablerIcons.alert_circle_filled, bg: c.bgDanger, fg: c.textDanger)],
      if (_info != null) ...[const SizedBox(height: 16), InfoBanner(_info!, icon: TablerIcons.mail_check, bg: c.bgSuccess, fg: c.textSuccess)],
      const SizedBox(height: 20),
      PillButton(_busy ? 'Please wait…' : cta, onPressed: _canSubmit ? _submit : null),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (_mode == EmailMode.signIn) ...[
          TextButton(onPressed: () => _switch(EmailMode.reset), child: const Text('Forgot password?')),
          TextButton(onPressed: () => _switch(EmailMode.create), child: const Text('Create account')),
        ] else
          TextButton(onPressed: () => _switch(EmailMode.signIn), child: const Text('Back to sign in')),
      ]),
    ]);
  }
}
